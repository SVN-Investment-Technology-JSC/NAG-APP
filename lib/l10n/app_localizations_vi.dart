// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Nguyên Anh';

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
  String get noData => 'Không có dữ liệu';

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
  String get sessionExpired =>
      'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';

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
  String get completedStatus => 'hoàn thành';

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
  String get shiftCloseConfirmContent =>
      'Bạn có chắc chắn muốn chốt ca hôm nay? Tất cả đơn hàng pending sẽ chuyển thành canceled.';

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

  @override
  String get appSettings => 'Cài đặt ứng dụng';

  @override
  String get themeMode => 'Giao diện (Sáng/Tối)';

  @override
  String get role => 'VAI TRÒ';

  @override
  String get region => 'KHU VỰC';

  @override
  String get dashboardDesc => 'Bảng điều khiển trung tâm';

  @override
  String get dailyTrips => 'Chuyến trong ngày';

  @override
  String get tripsDesc => 'Cập nhật lịch trình';

  @override
  String get attendanceDesc => 'Lịch sử làm việc';

  @override
  String get mealDesc => 'Đăng ký suất ăn';

  @override
  String get settings => 'Cài đặt';

  @override
  String get settingsDesc => 'Tài khoản & Ứng dụng';

  @override
  String get supportLegal => 'HỖ TRỢ & PHÁP LÝ';

  @override
  String get helpCenter => 'Trung tâm trợ giúp';

  @override
  String get privacyPolicy => 'Chính sách bảo mật';

  @override
  String get defaultUser => 'Người dùng';

  @override
  String get defaultRoleDesc => 'Quản lý Đội xe #42';

  @override
  String get defaultRegion => 'Hà Nội';

  @override
  String get tripManagement => 'Quản lý chuyến';

  @override
  String get vehicleQueue => 'Thứ tự lốt xe';

  @override
  String get homeTab => 'Trang chủ';

  @override
  String get tripsTab => 'Chuyến đi';

  @override
  String get profileTab => 'Cá nhân';

  @override
  String get reportsTab => 'Báo cáo';

  @override
  String get vietnamese => 'Tiếng Việt (VN)';

  @override
  String get english => 'English (EN)';

  @override
  String get mealShareError => 'Lỗi chia sẻ ảnh!';

  @override
  String get retry => 'Thử lại';

  @override
  String get mealTableTitle => 'BẢNG CHẤM TIỀN ĂN QUA BỮA';

  @override
  String get mealFromDate => 'Từ ngày';

  @override
  String get mealToDate => 'đến';

  @override
  String get mealSTT => 'STT';

  @override
  String get mealFullName => 'Họ và tên';

  @override
  String get mealTotal => 'Tổng';

  @override
  String get mealGrandTotal => 'Tổng cộng';

  @override
  String get mealUnit => 'bữa';

  @override
  String get mealChecking => 'Đang kiểm tra...';

  @override
  String get mealCheckBtn => 'Kiểm tra';

  @override
  String get mealCheckHint => 'Chọn ngày, buổi rồi bấm Kiểm tra';

  @override
  String get mealShareTooltip => 'Chia sẻ ảnh';

  @override
  String get attendanceStats => 'Thống kê nhân sự';

  @override
  String get updating => 'ĐANG CẬP NHẬT';

  @override
  String get totalPersonnel => 'TỔNG SỐ';

  @override
  String get allSystems => 'NHÂN VIÊN TOÀN HỆ THỐNG';

  @override
  String get allPersonnel => 'Tất cả nhân sự';

  @override
  String get workingStatus => 'ĐI LÀM';

  @override
  String get personnelWorking => 'Nhân sự đi làm';

  @override
  String get offStatus => 'NGHỈ';

  @override
  String get absent => 'VẮNG MẶT';

  @override
  String get personnelOff => 'Nhân sự nghỉ';

  @override
  String get halfDayStatus => 'NỬA NGÀY';

  @override
  String get approved => 'ĐÃ PHÊ DUYỆT';

  @override
  String get personnelHalfDay => 'Nhân sự nghỉ nửa ngày';

  @override
  String get groupList => 'Danh sách tổ nhóm';

  @override
  String get viewAll => 'XEM TẤT CẢ';

  @override
  String get performance => 'HIỆU SUẤT';

  @override
  String get all => 'Tất cả';

  @override
  String get exportExcel => 'Xuất Excel';

  @override
  String get openGoogleSheet => 'Mở Google Sheet';

  @override
  String get personnelList => 'Danh sách nhân sự';

  @override
  String get monthLabel => 'Tháng';

  @override
  String get stt => 'STT';

  @override
  String get fullName => 'Họ tên';

  @override
  String get department => 'Bộ phận';

  @override
  String get status => 'Trạng thái';

  @override
  String get activeStations => 'Các trạm đang hoạt động';

  @override
  String get live => 'Trực tiếp';

  @override
  String get deleteAccount => 'Xóa tài khoản';

  @override
  String get deleteAccountWarning =>
      'Hành động này không thể hoàn tác. Tất cả dữ liệu cá nhân của bạn sẽ bị xóa vĩnh viễn.';

  @override
  String get confirmDeleteAccount => 'Xác nhận xóa tài khoản';

  @override
  String get accountDeleted => 'Tài khoản của bạn đã được xóa';

  @override
  String get donotHaveAccount => 'Chưa có tài khoản?';

  @override
  String get contactAdmin =>
      'Liên hệ quản trị viên để được cấp quyền truy cập.';

  @override
  String get partnershipContact => 'Liên hệ hợp tác';

  @override
  String get checkLog => 'NHẬT KÝ';

  @override
  String get queueHistory => 'LỊCH SỬ LỐT XE';

  @override
  String get syncSlots => 'ĐỒNG BỘ LỐT XE';

  @override
  String get cameraConnected => 'Camera kết nối';

  @override
  String get cameraDisconnected => 'Camera ngắt kết nối';

  @override
  String get parkedVehicles => 'XE TRONG BÃI';

  @override
  String get transportReport => 'Báo cáo Vận tải';

  @override
  String get production => 'Sản lượng';

  @override
  String get vehicleRanking => 'Xếp hạng xe';

  @override
  String get byDay => 'Theo ngày';

  @override
  String get byWeek => 'Theo tuần';

  @override
  String get byMonth => 'Theo tháng';

  @override
  String get exportReportBtn => 'XUẤT BÁO CÁO';

  @override
  String get avgProduction => 'SẢN LƯỢNG TB';

  @override
  String get totalTrips => 'TỔNG CHUYẾN';

  @override
  String get completedUpper => 'HOÀN THÀNH';

  @override
  String get totalKm => 'TỔNG KM';

  @override
  String get productionChart => 'Biểu đồ sản lượng';

  @override
  String productionChartDesc(Object groupBy) {
    return 'Sản lượng vận chuyển theo $groupBy';
  }

  @override
  String get hours => 'giờ';

  @override
  String get minutes => 'phút';

  @override
  String get transportingStatus => 'Đang di chuyển';

  @override
  String get mixLabel => 'Trộn';

  @override
  String get totalProduction => 'Tổng sản lượng';

  @override
  String get averageLevel => 'Mức trung bình';

  @override
  String get detailsUpper => 'CHI TIẾT';

  @override
  String get stationPerformance => 'Hiệu suất Trạm';

  @override
  String get seeAll => 'Xem tất cả';

  @override
  String get trips => 'chuyến';

  @override
  String get tons => 'Tấn';

  @override
  String get productionRecent => 'Sản lượng theo kỳ gần nhất';

  @override
  String get clickToOpenDetails => 'Nhấn vào từng kỳ để mở chi tiết chuyến';

  @override
  String get dayUpper => 'NGÀY';

  @override
  String get periodUpper => 'KỲ';

  @override
  String get vehicleRankingTitle => 'Xếp hạng xe năng suất';

  @override
  String get vehicleRankingDesc => 'Dựa trên tổng số chuyến và quãng đường';

  @override
  String get vehicleCode => 'MÃ XE';

  @override
  String get licensePlate => 'BIỂN SỐ';

  @override
  String get tripsUpper => 'CHUYẾN';

  @override
  String get operationalLog => 'Nhật ký vận hành';

  @override
  String totalVehicles(Object count) {
    return 'Tổng: $count xe';
  }

  @override
  String get delivering => 'Đang giao hàng';

  @override
  String get startedAt => 'bắt đầu lúc';

  @override
  String get statusInDay => 'Trạng thái trong ngày';

  @override
  String get searchVehicleHint => 'Tìm xe, biển số...';

  @override
  String get noStationData => 'Chưa có dữ liệu trạm';

  @override
  String get noTripsFound => 'Không tìm thấy chuyến xe nào';

  @override
  String get tripDetail => 'Chi tiết chuyến';

  @override
  String tripsInPeriod(Object count) {
    return '$count chuyến trong kỳ này';
  }

  @override
  String get otherStatus => 'Khác';

  @override
  String get noResultsFound => 'Không tìm thấy kết quả';

  @override
  String get noTripsYet => 'Chưa có chuyến nào';

  @override
  String get featureUnderDevelopment => 'Tính năng đang phát triển';
}
