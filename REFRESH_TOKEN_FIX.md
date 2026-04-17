# Hướng dẫn sửa lỗi Refresh Token (Login + Reload)

Báo cáo này liệt kê từng lỗi được xác định trong luồng auth hiện tại, nguyên nhân, và bản vá cụ thể. Áp dụng theo thứ tự sẽ giúp cả luồng login lẫn luồng reload hoạt động đúng.

---

## Tổng quan kiến trúc hiện tại

- `ApiClient` tạo 2 Dio instance chung `cookieJar` (dùng cho HttpOnly refresh cookie).
- `AuthInterceptor` bắt 401, gọi `/auth/refresh`, replay request.
- `AuthService.login` lưu `access_token` vào `SharedPreferences` qua `SelectionPage._onConfirm`.
- `RootHandler._handleStartUp` (trong `app.dart`) chỉ check `prefs.getString('access_token') != null` rồi vào `MainShell`.

---

## Lỗi #1 — Login không set `is_logged_in = true`

**File:** `lib/features/setup/presentation/selection_page.dart` (dòng 81-85)

**Hiện trạng:** Sau khi login thành công chỉ lưu access_token, user_id, full_name, role. Nhưng `AuthStorageService.isLoggedIn()` yêu cầu cờ `is_logged_in = true`. Nếu nơi khác gọi `isLoggedIn()` sẽ trả `false` → user bị đá ra login mặc dù vừa đăng nhập thành công.

**Sửa (thay block prefs trong `_onConfirm`):**

```dart
// Thay toàn bộ block lưu prefs bằng cách dùng AuthStorageService để đồng nhất
await _authStorage.saveSession(
  accessToken: result.accessToken,
  userId: result.userId,
  fullName: result.fullName,
  role: result.role,
);
await _savePreferences();
```

---

## Lỗi #2 — Reload không chủ động refresh, dùng access_token cũ có thể hết hạn

**File:** `lib/app.dart` (`_RootHandlerState._handleStartUp`)

**Hiện trạng:** Chỉ kiểm tra token trong SharedPreferences. Nếu access_token đã hết hạn thì toàn bộ request đầu tiên (kể cả socket connect dùng token raw không qua Dio interceptor) sẽ fail trước khi refresh kịp xảy ra.

**Sửa (thay `_handleStartUp`):**

```dart
Future<void> _handleStartUp() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');

  // Không có gì — vào login
  if (token == null || token.isEmpty) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SelectionPage()),
      );
    }
    return;
  }

  // Có token cũ — chủ động refresh trước khi vào app
  try {
    final authService = AuthService(ApiClient.refreshDio);
    final result = await authService.refresh();

    await prefs.setString('access_token', result.accessToken);
    await prefs.setInt('user_id', result.userId);
    await prefs.setString('user_full_name', result.fullName);
    await prefs.setString('user_role', result.role);
    await prefs.setBool('is_logged_in', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  } catch (_) {
    // Refresh cookie hết hạn hoặc không có — xoá session và đá ra login
    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('user_full_name');
    await prefs.remove('user_role');
    await prefs.setBool('is_logged_in', false);
    ApiClient.cookieJar.deleteAll();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SelectionPage()),
    );
  }
}
```

Import thêm:
```dart
import 'package:vehicle_management/features/auth/data/services/auth_service.dart';
```

**Lý do dùng `refreshDio`:** `refreshDio` không có `AuthInterceptor` → nếu refresh fail, không bị loop 401.

---

## Lỗi #3 — Race condition ở `_handleTokenRefresh`

**File:** `lib/core/network/auth_interceptor.dart` (dòng 81-100)

**Hiện trạng:** Block `finally` set `_refreshCompleter = null` ngay cả khi request thứ 2/3 đang chờ `_refreshCompleter?.future`. Nếu timing không may, request chờ có thể nhận `null` sai.

**Sửa (thay `_handleTokenRefresh`):**

```dart
Future<String?> _handleTokenRefresh() async {
  // Có refresh đang chạy → await completer cũ
  final inflight = _refreshCompleter;
  if (_isRefreshing && inflight != null) {
    return inflight.future;
  }

  _isRefreshing = true;
  final completer = Completer<String?>();
  _refreshCompleter = completer;

  try {
    final newToken = await _refreshToken();
    completer.complete(newToken);
    return newToken;
  } catch (e) {
    if (!completer.isCompleted) completer.complete(null);
    return null;
  } finally {
    _isRefreshing = false;
    _refreshCompleter = null;
  }
}
```

---

## Lỗi #4 — Retry request sau refresh không replay được FormData

**File:** `lib/core/network/auth_interceptor.dart` (dòng 71)

**Hiện trạng:** `dio.fetch(options)` với request chứa `FormData` sẽ ném `StateError: Stream has already been listened to` vì stream đã bị consume ở lần đầu.

**Sửa (thay block try-catch trong `onError`):**

```dart
try {
  final newToken = await _handleTokenRefresh();

  if (newToken != null) {
    final original = err.requestOptions;

    // Clone data nếu là FormData để tránh stream đã consume
    dynamic newData = original.data;
    if (original.data is FormData) {
      final old = original.data as FormData;
      final cloned = FormData();
      cloned.fields.addAll(old.fields);
      for (final f in old.files) {
        cloned.files.add(MapEntry(f.key, f.value.clone()));
      }
      newData = cloned;
    }

    final response = await dio.request(
      original.path,
      data: newData,
      queryParameters: original.queryParameters,
      options: Options(
        method: original.method,
        headers: {
          ...original.headers,
          'Authorization': 'Bearer $newToken',
        },
        contentType: original.contentType,
        responseType: original.responseType,
        extra: {...original.extra, _retryKey: true},
      ),
    );
    handler.resolve(response);
    return;
  }
} catch (_) {}

_forceLogout();
handler.next(err);
```

---

## Lỗi #5 — Không đồng nhất key parse khi refresh

**File:** `lib/core/network/auth_interceptor.dart` (dòng 107-122)

**Hiện trạng:** Đọc `data['accessToken']` (camelCase) nhưng một số backend lại trả về `data['access_token']`. Nếu backend đổi convention, toàn bộ refresh im lặng fail.

**Sửa (thay block đọc token trong `_refreshToken`):**

```dart
final data = response.data;
final newToken = (data['accessToken'] ?? data['access_token']) as String?;

if (newToken != null && newToken.isNotEmpty) {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('access_token', newToken);

  final userId = data['user_id'] ?? data['userId'];
  if (userId is int) await prefs.setInt('user_id', userId);

  final fullName = data['user_full_name'] ?? data['userFullName'];
  if (fullName is String) await prefs.setString('user_full_name', fullName);

  final role = data['role'];
  if (role is String) await prefs.setString('user_role', role);

  await prefs.setBool('is_logged_in', true);

  onTokenRefreshed?.call();
  return newToken;
}
```

---

## Lỗi #6 — `/auth/refresh` có thể phải là `POST`

**File:** `lib/core/network/auth_interceptor.dart` (dòng 104) và `lib/features/auth/data/services/auth_service.dart` (dòng 31)

**Hiện trạng:** Cả hai nơi đều dùng `dio.get('/auth/refresh')`. Nhiều backend (NestJS JwtRefreshGuard) expose endpoint này là `POST`. Nếu backend của bạn trả `405 Method Not Allowed`, refresh im lặng fail.

**Kiểm tra:** Mở Swagger/Postman, xác nhận method. Nếu là POST, sửa:

```dart
// auth_interceptor.dart
final response = await refreshDio.post('/auth/refresh');

// auth_service.dart
final response = await dio.post('/auth/refresh');
```

---

## Lỗi #7 — Timeout mặc định làm treo refresh

**File:** `lib/core/network/api_client.dart`

**Hiện trạng:** `refreshDio` dùng chung timeout 10s với `dio`. Một refresh lỗi có thể block toàn bộ request đang xếp hàng.

**Sửa (cấu hình riêng cho refreshDio):**

```dart
refreshDio = Dio(BaseOptions(
  baseUrl: AppEndpoints.apiBaseUrl,
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 5),
  sendTimeout: const Duration(seconds: 5),
  headers: {'Content-Type': 'application/json'},
));
refreshDio.interceptors.add(CookieManager(cookieJar));
```

---

## Lỗi #8 — Web: thiếu `withCredentials`

**File:** `lib/core/network/api_client.dart` (chỉ áp dụng nếu chạy Flutter Web)

**Hiện trạng:** Trên web, `CookieManager` không hoạt động. Browser tự quản cookie qua `document.cookie`, cần bật `withCredentials`.

**Sửa (sau khi tạo dio):**

```dart
import 'package:dio/browser.dart' as dio_browser;
// ...
if (identical(0, 0.0)) { // kFlutterWeb check rút gọn, hoặc import foundation
  final adapter = dio_browser.BrowserHttpClientAdapter()..withCredentials = true;
  dio.httpClientAdapter = adapter;

  final refreshAdapter = dio_browser.BrowserHttpClientAdapter()..withCredentials = true;
  refreshDio.httpClientAdapter = refreshAdapter;
}
```

Cách đúng hơn: dùng `kIsWeb` từ `package:flutter/foundation.dart`.

---

## Lỗi #9 — Socket/WebSocket không trigger refresh

**File:** `lib/core/network/device_socket_service.dart`, `notification_socket_service.dart`, `socket_service.dart`

**Hiện trạng:** Socket connect bằng access_token raw từ SharedPreferences. Nếu token hết hạn lúc connect, socket không tự refresh.

**Sửa (pattern gợi ý):**

- Trước khi `socket.connect()`, gọi `ApiClient.dio.get('/auth/me')` (hoặc endpoint bất kỳ có bật interceptor) để trigger refresh nếu cần.
- Trong `AuthInterceptor`, expose callback `onTokenRefreshed` (đã có) để socket lắng nghe và reconnect với token mới.

Ví dụ trong init socket:
```dart
final storage = AuthStorageService();
String? token = await storage.getAccessToken();
// trigger refresh nếu cần
try { await ApiClient.dio.get('/auth/me'); } catch (_) {}
token = await storage.getAccessToken();
// rồi mới connect socket với `token`
```

---

## Lỗi #10 — `isLoggedIn()` không dùng tới

**File:** `lib/features/auth/data/services/auth_storage_service.dart`

**Hiện trạng:** Hàm kiểm tra `is_logged_in && token != null`, nhưng login không set `is_logged_in` (xem Lỗi #1) và `RootHandler` không gọi `isLoggedIn()`.

**Sửa:** Sau khi áp Lỗi #1 và #2, mọi nơi kiểm tra session nên gọi:
```dart
final isLogged = await _authStorage.isLoggedIn();
```

---

## Checklist sau khi áp bản vá

1. [ ] Đăng nhập mới → kiểm tra `SharedPreferences` có đủ 5 key: `access_token`, `user_id`, `user_full_name`, `user_role`, `is_logged_in=true`.
2. [ ] Kiểm tra cookie jar: có `refresh_token` HttpOnly ở domain của backend.
3. [ ] Kill app → mở lại → thấy splash loader rồi vào thẳng `MainShell` (không cần gõ lại password).
4. [ ] Chờ access_token hết hạn (hoặc sửa backend trả TTL 60s để test) → thực hiện hành động bất kỳ → network log phải thấy 1 request 401, 1 request `/auth/refresh` 200, rồi request gốc được replay 200.
5. [ ] Upload ảnh điểm danh (FormData) → phải retry thành công sau refresh.
6. [ ] Sau khi xoá refresh cookie thủ công → reload app → bị đá về `SelectionPage`.

---

## Tham khảo thứ tự áp dụng

1. Sửa `selection_page.dart` (Lỗi #1)
2. Sửa `auth_interceptor.dart` (Lỗi #3, #4, #5, #6)
3. Sửa `api_client.dart` (Lỗi #7, #8)
4. Sửa `app.dart` (Lỗi #2)
5. Sửa `auth_service.dart` method refresh (Lỗi #6)
6. Review socket services (Lỗi #9)

Nếu sau khi áp xong vẫn còn lỗi, capture network log (Chrome DevTools hoặc Charles/Proxyman) cho các request `/auth/login`, `/auth/refresh`, và request đầu tiên sau reload, mình sẽ debug tiếp dựa trên response thực tế.
