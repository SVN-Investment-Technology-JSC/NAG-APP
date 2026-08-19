# 📝 Tài liệu khai báo & giải trình App Store Connect (Apple)

Tài liệu này soạn sẵn các nội dung cần thiết để bạn khai báo thông tin trên **App Store Connect** cho ứng dụng **Nguyên Anh** (đặc biệt là quyền vị trí chạy nền - Background Location).

---

## 📌 PHẦN 1: Khai báo Quyền riêng tư (App Privacy)
Khi Apple hỏi về các loại dữ liệu mà ứng dụng thu thập, bạn chọn khai báo các mục sau:

### 1. Vị trí (Location)
*   **Loại dữ liệu:** Vị trí chính xác (Precise Location).
*   **Có liên kết với danh tính người dùng không?** Có (Yes - dữ liệu vị trí được gắn với tài khoản của tài xế).
*   **Sử dụng cho mục đích nào?** 
    *   Chức năng của ứng dụng (App Functionality) - để theo dõi vị trí xe và trạng thái giao hàng.
    *   Quản lý lập hồ sơ (Analytics/Operations) - để thống kê chuyến đi.
*   **Có dùng để theo dõi (Tracking) không?** Không (No - dữ liệu chỉ phục vụ mục đích vận hành nội bộ, không chia sẻ với bên thứ ba cho mục đích quảng cáo).

### 2. Ảnh và Video (Photos and Videos)
*   **Loại dữ liệu:** Ảnh hoặc video (Photos or Videos).
*   **Có liên kết với danh tính người dùng không?** Có (Yes).
*   **Sử dụng cho mục đích nào?** Chức năng của ứng dụng (App Functionality) - tài xế chụp ảnh/tải ảnh lên để xác nhận hoàn thành chuyến xe, phiếu bảo trì hoặc xác nhận suất ăn.

### 3. Mã định danh (Identifiers)
*   **Loại dữ liệu:** ID người dùng (User ID) và ID thiết bị (Device ID).
*   **Có liên kết với danh tính người dùng không?** Có (Yes).
*   **Sử dụng cho mục đích nào?** Chức năng của ứng dụng (App Functionality) - để định danh tài khoản đăng nhập.

---

## 📌 PHẦN 2: Giải trình Quyền truy cập vị trí chạy nền (Background Location Justification)
*Khi submit bản build có đăng ký `UIBackgroundModes -> location`, Apple sẽ yêu cầu giải trình chi tiết ở phần điền thông tin đánh giá ứng dụng (App Store Review Information).*

### 🇺🇸 Bản Tiếng Anh (Khuyên dùng khi gửi Apple)
> **Notes for Reviewer (App Store Review Information):**
> 
> Our app is an internal fleet and driver management tool for Nguyen Anh transportation company. The app utilizes background location access ("Always Allow") to track the real-time routes and GPS signals of transit concrete mixer trucks and tankers. 
> 
> This background location data is vital for:
> 1. **Automatic Geofencing:** Detecting when a driver/vehicle checks in and out of concrete batching stations to update the queue status automatically without requiring manual action while driving.
> 2. **Continuous Fleet Monitoring:** Ensuring dispatchers can monitor vehicle locations even when the driver locks the iPhone screen or puts the app in the background during long hours of transport.
> 
> *Location tracking only operates when the driver is on their active shift.*
> 
> **Demo Account Credentials for Testing:**
> - Username: `tuyentap_driver` (or insert your driver test account)
> - Password: `[Your Password]`
> 
> **Video Link demonstrating background location feature:** 
> *(Note: Apple requires a public URL link to a video showing the background location feature in action, such as Google Drive or YouTube Unlisted)*
> - Video Demo Link: `[Insert Google Drive link to video]`

### 🇻🇳 Bản Tiếng Việt (Để tham khảo)
> **Ghi chú gửi người kiểm duyệt (Reviewer Notes):**
> 
> Ứng dụng của chúng tôi là công cụ quản lý đội xe và điều phối tài xế nội bộ cho công ty vận tải Nguyễn Anh. Ứng dụng sử dụng quyền truy cập vị trí nền ("Luôn cho phép") để ghi nhận thời gian thực lộ trình và tọa độ GPS của xe bồn trộn bê tông.
> 
> Dữ liệu vị trí nền này vô cùng quan trọng cho:
> 1. **Vùng địa lý tự động (Geofencing):** Tự động phát hiện khi xe đi vào hoặc đi ra khỏi các trạm trộn bê tông để cập nhật số thứ tự (lốt xe) mà không yêu cầu tài xế phải thao tác thủ công khi đang lái xe nguy hiểm.
> 2. **Giám sát đội xe liên tục:** Đảm bảo điều phối viên luôn thấy được vị trí xe bồn ngay cả khi tài xế khóa màn hình iPhone hoặc ứng dụng bị ẩn xuống nền trong suốt hành trình vận chuyển dài.
> 
> *Việc theo dõi vị trí chỉ hoạt động khi tài xế đang trong ca làm việc.*

---

## 📌 PHẦN 3: Nội dung mô tả quyền trong ứng dụng (Info.plist)
*Đây là các nội dung giải thích sẽ hiển thị lên màn hình điện thoại khi người dùng mở ứng dụng lần đầu. Nội dung này đã được chúng tôi cài đặt sẵn trong file `ios/Runner/Info.plist`:*

1.  **Vị trí luôn luôn và khi dùng ứng dụng (`NSLocationAlwaysAndWhenInUseUsageDescription`):**
    > "Ứng dụng cần quyền truy cập vị trí để ghi nhận lộ trình di chuyển của xe và tính toán khoảng cách vận chuyển chính xác."
2.  **Vị trí khi dùng ứng dụng (`NSLocationWhenInUseUsageDescription`):**
    > "Vị trí của bạn được sử dụng để điều phối tài xế gần nhất và cập nhật trạng thái vận chuyển thời gian thực."
3.  **Camera (`NSCameraUsageDescription`):**
    > "Ứng dụng cần sử dụng camera để quét mã QR và chụp ảnh xác nhận trạng thái đơn hàng/suất ăn."
4.  **Thư viện ảnh (`NSPhotoLibraryUsageDescription`):**
    > "Ứng dụng cần truy cập thư viện ảnh để lưu trữ hoặc đính kèm ảnh xác nhận vận hành."

---

## 📌 PHẦN 4: Có gì mới trong phiên bản này (What's New in This Version)
*Bản tóm tắt tính năng mới để điền vào ô "What's New in This Version" trên App Store Connect.*

### 🇺🇸 Bản Tiếng Anh (English) - Version 2.2.2 (Build 25)
What's New in This Version:
- Upgraded the minimum target iOS version to 15.0 to comply with the latest Apple App Store Connect submission requirements.
- Introduced a dedicated "Daily Trips" (Chuyến trong ngày) permission toggle in the Role Permissions screen.
- Improved the Trips tab interface by dynamically showing or hiding sub-tabs and headers based on active permissions (Lot Order and Daily Trips).

### 🇻🇳 Bản Tiếng Việt (Vietnamese) - Phiên bản 2.2.2 (Build 25)
Có gì mới trong phiên bản này:
- Nâng cấp phiên bản hệ điều hành iOS tối thiểu lên 15.0 để tuân thủ các điều kiện phê duyệt mới nhất của Apple App Store Connect.
- Bổ sung quyền cấu hình bật/tắt độc lập cho tính năng "Chuyến trong ngày" trong phân quyền vai trò.
- Tối ưu hóa giao diện Tab Chuyến đi: Tự động ẩn thanh tiêu đề tab con để hiển thị toàn màn hình nếu người dùng chỉ có một quyền hoạt động (Xem thứ tự lốt xe hoặc Chuyến trong ngày).

---

### 🇺🇸 Bản Tiếng Anh (English) - Version 2.2.1 (Build 23/24)
What's New in This Version:
- Added "Short Name" (Tên viết tắt) input field when creating or editing users, enhancing data consistency with the web administration panel.
- Enhanced User Form UX: Added visual snackbar alerts for empty required fields, and friendly descriptive dialog alerts for duplicate username, phone number, or email conflicts.
- Fine-grained Dashboard Permissions: Integrated a new limited permission that truncates the dashboard lot queue to display only the top 3 vehicles.
- Android platform build and Gradle compile configuration optimizations.

### 🇻🇳 Bản Tiếng Việt (Vietnamese) - Phiên bản 2.2.1 (Build 23/24)
Có gì mới trong phiên bản này:
- Thêm ô nhập "Tên viết tắt" khi tạo mới/chỉnh sửa người dùng, giúp đồng bộ thông tin quản lý với trang quản trị web.
- Tối ưu hóa biểu mẫu người dùng: Bổ sung cảnh báo nhanh khi để trống thông tin bắt buộc, hiển thị hộp thoại thông báo lỗi chi tiết, dễ hiểu khi bị trùng tên đăng nhập, số điện thoại hoặc email.
- Phân quyền bảng điều khiển động: Thêm quyền xem giới hạn hàng đợi lốt xe (chỉ hiển thị tối đa 3 xe chạy trên đầu danh sách).
- Tối ưu hóa cấu hình build và biên dịch Gradle cho nền tảng Android.
