// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Quản lý xe';

  @override
  String get selectLanguage => 'Ngôn ngữ / Language';

  @override
  String get fleetSelection => 'Đăng Nhập';

  @override
  String get username => 'Tên đăng nhập';

  @override
  String get password => 'Mật khẩu';

  @override
  String get rememberMe => 'Ghi nhớ thông tin đăng nhập';

  @override
  String get confirm => 'XÁC NHẬN';

  @override
  String get pleaseEnterDetails => 'Vui lòng nhập đầy đủ thông tin';

  @override
  String get logOut => 'Đăng xuất';

  @override
  String selectHint(Object label) {
    return 'Chọn $label';
  }

  @override
  String get cancel => 'Hủy';

  @override
  String get confirmLogoutTitle => 'Đăng xuất';

  @override
  String get confirmLogoutContent => 'Bạn có chắc chắn muốn đăng xuất không?';

  @override
  String get noData => 'Chưa có dữ liệu';

  @override
  String get loginInvalidCredentials => 'Sai tài khoản hoặc mật khẩu';

  @override
  String get loginServerUnavailable => 'Không thể kết nối máy chủ';

  @override
  String get loginGenericError => 'Có lỗi xảy ra, vui lòng thử lại';

  @override
  String get home => 'Trang chủ';

  @override
  String get pendingOrders => 'Đơn hàng chờ xử lý';

  @override
  String get noPendingOrders => 'Không có đơn hàng chờ xử lý';

  @override
  String get changeStation => 'Đổi trạm';

  @override
  String get selectStation => 'Chọn trạm';

  @override
  String get orderUpdated => 'Đã cập nhật đơn hàng';

  @override
  String get orderUpdateFailed => 'Cập nhật đơn hàng thất bại';

  @override
  String get reorderSuccess => 'Đã cập nhật vị trí đơn hàng';

  @override
  String get refreshing => 'Đang tải lại...';

  @override
  String get sessionExpired => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get vehicleLabel => 'Phương tiện';

  @override
  String get driverLabel => 'Tài xế';

  @override
  String get stationLabel => 'Trạm';

  @override
  String get orderPositionLabel => 'Vị trí';

  @override
  String get dragToReorder => 'Kéo để sắp xếp';

  @override
  String get collecting => 'Đang lấy hàng';

  @override
  String get prioritize => 'Ưu tiên lên đầu';

  @override
  String get vehiclesAtStation => 'xe tại trạm';

  @override
  String get moveToTop => 'Đưa lên đầu';

  @override
  String get stationOverview => 'Tổng quan trạm';

  @override
  String vehicleCount(Object count) {
    return '$count xe';
  }

  @override
  String get todayOrders => 'Thứ tự lốt xe';

  @override
  String get today => 'Hôm nay';

  @override
  String get initStatus => 'Khởi tạo';

  @override
  String get vehicleRunning => 'Đang chạy';

  @override
  String get vehicleParked => 'Đang dừng';

  @override
  String get vehicleOffline => 'Mất kết nối';

  @override
  String get speedLabel => 'Vận tốc';

  @override
  String get distanceLabel => 'Cách trạm';

  @override
  String get locationLabel => 'Vị trí';

  @override
  String get completedTrips => 'Hoàn thành';

  @override
  String get activeTrips => 'Đang chạy';

  @override
  String get completedStatus => 'Hoàn thành';

  @override
  String get noTripsForVehicle => 'Không có chuyến cho xe này hôm nay';

  @override
  String get running => 'Đang chạy';

  @override
  String get vehicleManagement => 'Chuyến trong ngày';

  @override
  String get selectDate => 'Chọn ngày';

  @override
  String get noVehicles => 'Không có xe bồn';

  @override
  String get tripsOnDate => 'Chuyến trong ngày';

  @override
  String get stopCountLabel => 'lần dừng';

  @override
  String get attendance => 'Chấm công';

  @override
  String get attendanceWorking => 'Đi làm';

  @override
  String get attendanceOff => 'Nghỉ';

  @override
  String get attendanceHalf => 'Nửa ngày';

  @override
  String get attendanceTotal => 'Tổng';

  @override
  String get noAttendanceData => 'Không có dữ liệu chấm công';

  @override
  String get shiftClose => 'Chốt ca';

  @override
  String get shiftCloseConfirmTitle => 'Xác nhận chốt ca';

  @override
  String get shiftCloseConfirmContent => 'Bạn có chắc chắn muốn chốt ca hôm nay? Tất cả đơn hàng pending sẽ chuyển thành canceled.';

  @override
  String get shiftCloseSuccess => 'Đã chốt ca thành công';

  @override
  String get shiftCloseFailed => 'Chốt ca thất bại';

  @override
  String shiftPendingWarning(Object count) {
    return 'Còn $count đơn chờ xử lý';
  }

  @override
  String get mealCheck => 'Cơm ca';

  @override
  String get mealCheckRefresh => 'Kiểm tra lại';

  @override
  String get mealCheckLoading => 'Đang kiểm tra cơm ca...';

  @override
  String get mealCheckNoData => 'Không có dữ liệu cơm ca';

  @override
  String get mealCheckTotal => 'Tổng';

  @override
  String get mealCheckMorning => 'Sáng';

  @override
  String get mealCheckLunch => 'Trưa';

  @override
  String get mealCheckDinner => 'Tối';

  @override
  String get notifications => 'Thông báo';

  @override
  String get notificationsEmpty => 'Không có thông báo';

  @override
  String get notificationRead => 'Đã xem';

  @override
  String get notificationUnread => 'Mới';
}
