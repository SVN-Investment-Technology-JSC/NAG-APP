# 🚚 Vehicle Management App (Ứng dụng Quản Lý Xe)

Ứng dụng **Vehicle Management** được phát triển bằng Flutter, hỗ trợ quá trình theo dõi, quản lý đội xe và trạng thái ca làm việc của tài xế một cách tự động và trực quan.

Ứng dụng được thiết kế nhằm mang lại trải nghiệm tiện lợi nhất cho tài xế với khả năng tự động cập nhật trạng thái hoạt động dựa vào vị trí địa lý thực tế (Geofencing), cùng với giao diện hiện đại và tính năng đa ngôn ngữ.

---

## ✨ Tính năng nổi bật (Key Features)

### Menu Navigation 2 Tab
- **Tab 1: Trang chu** — Tong quan tram: user info, station cards (collecting), ban do GPS VTracking.
- **Tab 2: Quan ly chuyen xe** — Danh sach xe bon (filter vehicle_name bat dau bang "X"), date picker chon ngay, click hien popup chi tiet xe + trips.
- Su dung M3 `NavigationBar`, `IndexedStack` giu state giua cac tab.

### Dashboard Hien dai
- **Home Summary:** The thong tin tai xe va phuong tien.
- **GPS Status:** Hien thi toa do thoi gian thuc.
- **Station Cards:** Hien thi xe dang lay hang tai moi tram.

### Design System (Flutter Design Skill)
- **AppSpacing:** He thong spacing 8-point grid (xs/sm/md/lg/xl/xxl).
- **AppColorsExtension:** Semantic color tokens (warning/success) qua ThemeExtension, khong hardcode hex trong widget.
- **Widget Architecture:** Tach widget thanh class rieng biet (<50 dong build method), khong dung widget methods.
- **Home Page Widgets:** `HomeUserHeader`, `HomeStationCard`, `HomeOrderItem`, `HomeMapSection`, `VehicleDetailSheet`.

### 🌍 Công nghệ Định vị Tự động (Next-gen Geofencing)
- **Real-time Geofencing Tracker:** Tự động nhận diện khi phương tiện đi vào hoặc rời khỏi bãi đỗ (Yard) dựa trên bán kính thiết lập từ Backend.
- **Automatic Status Management:** Loại bỏ việc thao tác thủ công, hệ thống tự động chuyển đổi trạng thái (Vào bãi, Xuất hàng, Đang hành trình) dựa trên vị trí địa lý thực tế.
- **Background Tracking:** Duy trì kết nối và gửi tín hiệu GPS ngầm kể cả khi ứng dụng không ở chế độ màn hình chính.

### Lọc Xe Bồn - Tổng Quan Trạm
- Trang tổng quan trạm (Home) chỉ hiển thị **xe bồn** (vehicle_name bắt đầu bằng "X", ví dụ: X1, X2, X3...).
- Áp dụng lọc cho toàn bộ: danh sách đơn hàng, Vehicle Chips Bar, bản đồ GPS VTracking, và thẻ trạm collecting.

### 💼 Quản lý Vận hành (Operations)
- **Shift Lifecycle:** Quy trình `Bắt đầu ca` và `Kết thúc ca` chặt chẽ, tích hợp kiểm tra điều kiện vận hành từ máy chủ.
- **Incident Reporting:** Tính năng báo cáo sự cố ngay lập tức tại hiện trường (Report Problem/Fleet).
- **Multi-language Support:** Hỗ trợ chuyển đổi linh hoạt **Tiếng Việt 🇻🇳** và **English 🇺🇸**.
- **Theming Engines:** Tích hợp Light / Dark Mode, bảo vệ thị lực và tối ưu hóa pin cho tài xế.

---

## 🛠 Lộ trình Công nghệ & Thư viện (Full Tech Stack)

Dự án được xây dựng dựa trên các công nghệ và bộ thư viện (packages) tối ưu nhất của hệ sinh thái Flutter:

- **Framework:** [Flutter SDK ^3.10.3](https://flutter.dev/) - Ngôn ngữ lập trình chính: **Dart**.
- **State Management:** 
  - `flutter_bloc` (^9.0.0): Quản lý trạng thái logic phức tạp một cách bền vững.
  - `provider` (^6.1.5+1): Xử lý các trạng thái UI và Dependency Injection nhẹ hơn.
- **Architecture & DI:**
  - `get_it` (^8.0.3): Service Locator dùng để quản lý tiêm phụ thuộc (DI).
  - `equatable` (^2.0.7): Tối ưu hiệu suất so sánh các đối tượng trạng thái.
- **Networking & Real-time:**
  - `dio` (^5.8.0+1): Engine xử lý giao thức HTTP truyền nhận API.
  - `socket_io_client` (^3.1.4): Truyền tải dữ liệu thời gian thực (WebSockets).
- **Location Services:**
  - `geolocator` (^14.0.2): Lấy dữ liệu GPS (Lat/Lng) độ chính xác cao nhất.
  - `flutter_background_service` (^5.1.0): Đảm bảo các tác vụ theo dõi vị trí không bị gián đoạn.
- **UI UX Framework:**
  - `flutter_screenutil` (^5.9.3): Đảm bảo giao diện hiển thị hoàn hảo trên mọi kích thước màn hình (Responsive Design).
  - `intl`: Xử lý định dạng ngày tháng, tiền tệ và đa ngôn ngữ chuyên sâu.
  - `flutter_launcher_icons`: Công cụ quản lý biểu tượng ứng dụng tự động.
- **Storage & Helpers:**
  - `shared_preferences` (^2.5.2): Lưu trữ cache, token và cấu hình nhỏ cục bộ.
  - `permission_handler` (^12.0.1): Quản lý cấp quyền hệ thống (GPS, Thông báo) thân thiện với người dùng.

---

## 🏗️ Cấu trúc dự án (Architecture Overview)

Dự án áp dụng chia tách Module theo cấu trúc **Feature-based** (kết hợp các nguyên lý của Clean Architecture):
```text
lib/
├── core/                   # Cau hinh chung, theme, mang (ApiClient), hang so
│   └── theme/              # AppTheme, AppColorsExtension, AppSpacing
├── features/               # Cac module tinh nang doc lap
│   ├── auth/               # Xac thuc nguoi dung & Luu tru Session
│   ├── home/               # Dashboard chinh
│   │   └── presentation/
│   │       ├── home_page.dart       # Orchestrator (<300 dong)
│   │       └── widgets/             # Cac widget tach rieng
│   │           ├── home_user_header.dart
│   │           ├── home_station_card.dart
│   │           ├── home_order_item.dart
│   │           ├── home_map_section.dart
│   │           └── vehicle_detail_sheet.dart
│   ├── history/            # Lich su dong thoi gian (Timeline)
│   ├── order/              # Logic quan ly don va lenh dieu dong
│   ├── stations/           # Du lieu tram/bai do va ranh gioi dia ly
│   ├── tracking/           # Core Logic xu ly GPS & Background Service
│   └── vehicle/            # Nghiep vu phuong tien & Check-in/Out
├── l10n/                   # He thong dich thuat da ngon ngu (ARB files)
└── main.dart               # Diem khoi dong ung dung
```

---

## 🚀 Hướng dẫn cài đặt (Installation)

### 1. Yêu cầu hệ thống
- Flutter SDK `^3.10.3` trở lên.
- Android Studio / Xcode để chạy máy ảo hoặc máy thật.
- VS Code hoặc bất kỳ IDE nào hỗ trợ Dart/Flutter.

### 2. Chuẩn bị
- Flutter SDK `^3.10.3`.
- Android SDK / iOS SDK mới nhất.

### 3. Cài đặt
```bash
# 1. Tải dependencies
flutter pub get

# 2. Sinh code localization
flutter gen-l10n

# 3. Chạy ứng dụng
flutter run
```

---

## 📝 Đội ngũ Phát triển (Development Team)

Dự án được phát triển và duy trì bởi **Savina Power DEV**. Mọi góp ý hoặc thắc mắc vui lòng liên hệ bộ phận kỹ thuật.

---
© 2026 Savina Power. All rights reserved.
