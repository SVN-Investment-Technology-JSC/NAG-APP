// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Nguyên Anh';

  @override
  String get selectLanguage => 'Language / Ngôn ngữ';

  @override
  String get fleetSelection => 'Login';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get rememberMe => 'Remember login information';

  @override
  String get confirm => 'CONFIRM';

  @override
  String get pleaseEnterDetails => 'Please enter all details';

  @override
  String get logOut => 'Logout';

  @override
  String selectHint(Object label) {
    return 'Select $label';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmLogoutTitle => 'Logout';

  @override
  String get confirmLogoutContent => 'Are you sure you want to logout?';

  @override
  String get noData => 'No data available';

  @override
  String get loginInvalidCredentials => 'Incorrect username or password';

  @override
  String get loginServerUnavailable => 'Cannot connect to server';

  @override
  String get loginGenericError => 'Something went wrong. Please try again.';

  @override
  String get home => 'Home';

  @override
  String get pendingOrders => 'Pending Orders';

  @override
  String get noPendingOrders => 'No pending orders';

  @override
  String get changeStation => 'Change';

  @override
  String get selectStation => 'Select Station';

  @override
  String get orderUpdated => 'Order updated successfully';

  @override
  String get orderUpdateFailed => 'Failed to update order';

  @override
  String get reorderSuccess => 'Order positions updated';

  @override
  String get refreshing => 'Refreshing...';

  @override
  String get sessionExpired => 'Session expired. Please login again.';

  @override
  String get vehicleLabel => 'Vehicle';

  @override
  String get driverLabel => 'Driver';

  @override
  String get stationLabel => 'Station';

  @override
  String get orderPositionLabel => 'Position';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get collecting => 'Collecting';

  @override
  String get prioritize => 'Prioritize';

  @override
  String get vehiclesAtStation => 'vehicles at station';

  @override
  String get moveToTop => 'Move to top';

  @override
  String get stationOverview => 'Station overview';

  @override
  String vehicleCount(Object count) {
    return '$count vehicles';
  }

  @override
  String get todayOrders => 'Vehicle Queue';

  @override
  String get today => 'Today';

  @override
  String get initStatus => 'Init';

  @override
  String get vehicleRunning => 'Running';

  @override
  String get vehicleParked => 'Parked';

  @override
  String get vehicleOffline => 'Offline';

  @override
  String get speedLabel => 'Speed';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get locationLabel => 'Location';

  @override
  String get completedTrips => 'Completed';

  @override
  String get activeTrips => 'Running';

  @override
  String get completedStatus => 'Completed';

  @override
  String get noTripsForVehicle => 'No trips for this vehicle today';

  @override
  String get running => 'Running';

  @override
  String get vehicleManagement => 'Daily Trips';

  @override
  String get selectDate => 'Select Date';

  @override
  String get noVehicles => 'No tankers';

  @override
  String get tripsOnDate => 'Daily Trips';

  @override
  String get stopCountLabel => 'stops';

  @override
  String get attendance => 'Attendance';

  @override
  String get attendanceWorking => 'Working';

  @override
  String get attendanceOff => 'Off';

  @override
  String get attendanceHalf => 'Half-day';

  @override
  String get attendanceTotal => 'Total';

  @override
  String get noAttendanceData => 'No attendance data';

  @override
  String get shiftClose => 'Shift Close';

  @override
  String get shiftCloseConfirmTitle => 'Confirm Shift Close';

  @override
  String get shiftCloseConfirmContent =>
      'Are you sure you want to close shift? All pending orders will be canceled.';

  @override
  String get shiftCloseSuccess => 'Shift closed successfully';

  @override
  String get shiftCloseFailed => 'Shift close failed';

  @override
  String shiftPendingWarning(Object count) {
    return '$count pending orders';
  }

  @override
  String get mealCheck => 'Meal Check';

  @override
  String get mealCheckRefresh => 'Refresh';

  @override
  String get mealCheckLoading => 'Checking meals...';

  @override
  String get mealCheckNoData => 'No meal data';

  @override
  String get mealCheckTotal => 'Total';

  @override
  String get mealCheckMorning => 'Morning';

  @override
  String get mealCheckLunch => 'Lunch';

  @override
  String get mealCheckDinner => 'Dinner';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationRead => 'Read';

  @override
  String get notificationUnread => 'New';

  @override
  String get appSettings => 'App Settings';

  @override
  String get themeMode => 'Theme (Light/Dark)';

  @override
  String get role => 'ROLE';

  @override
  String get region => 'REGION';

  @override
  String get dashboardDesc => 'Central Dashboard';

  @override
  String get dailyTrips => 'Daily Trips';

  @override
  String get tripsDesc => 'Update schedules';

  @override
  String get attendanceDesc => 'Working history';

  @override
  String get mealDesc => 'Register meals';

  @override
  String get settings => 'Settings';

  @override
  String get settingsDesc => 'Account & App';

  @override
  String get supportLegal => 'SUPPORT & LEGAL';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get defaultUser => 'User';

  @override
  String get defaultRoleDesc => 'Fleet Manager #42';

  @override
  String get defaultRegion => 'Hanoi';

  @override
  String get tripManagement => 'Trip Management';

  @override
  String get vehicleQueue => 'Vehicle Queue';

  @override
  String get homeTab => 'HOME';

  @override
  String get tripsTab => 'TRIPS';

  @override
  String get profileTab => 'PROFILE';

  @override
  String get vietnamese => 'Tiếng Việt (VN)';

  @override
  String get english => 'English (EN)';

  @override
  String get mealShareError => 'Error sharing image!';

  @override
  String get retry => 'Retry';

  @override
  String get mealTableTitle => 'MEAL ALLOWANCE RECORD';

  @override
  String get mealFromDate => 'From';

  @override
  String get mealToDate => 'to';

  @override
  String get mealSTT => 'No.';

  @override
  String get mealFullName => 'Full Name';

  @override
  String get mealTotal => 'Total';

  @override
  String get mealGrandTotal => 'Grand Total';

  @override
  String get mealUnit => 'meals';

  @override
  String get mealChecking => 'Checking...';

  @override
  String get mealCheckBtn => 'Check';

  @override
  String get mealCheckHint => 'Select date, slot then press Check';

  @override
  String get mealShareTooltip => 'Share Image';

  @override
  String get attendanceStats => 'Personnel Statistics';

  @override
  String get updating => 'UPDATING';

  @override
  String get totalPersonnel => 'TOTAL';

  @override
  String get allSystems => 'EMPLOYEES SYSTEM-WIDE';

  @override
  String get allPersonnel => 'All Personnel';

  @override
  String get workingStatus => 'WORKING';

  @override
  String get personnelWorking => 'Working Personnel';

  @override
  String get offStatus => 'OFF';

  @override
  String get absent => 'ABSENT';

  @override
  String get personnelOff => 'Off Personnel';

  @override
  String get halfDayStatus => 'HALF DAY';

  @override
  String get approved => 'APPROVED';

  @override
  String get personnelHalfDay => 'Half-day Personnel';

  @override
  String get groupList => 'Group List';

  @override
  String get viewAll => 'VIEW ALL';

  @override
  String get performance => 'PERFORMANCE';

  @override
  String get all => 'All';

  @override
  String get exportExcel => 'Export Excel';

  @override
  String get openGoogleSheet => 'Open Google Sheet';

  @override
  String get personnelList => 'Personnel List';

  @override
  String get monthLabel => 'Month';

  @override
  String get stt => 'No.';

  @override
  String get fullName => 'Full Name';

  @override
  String get department => 'Dept.';

  @override
  String get status => 'Status';

  @override
  String get activeStations => 'Active Stations';

  @override
  String get live => 'Live';
}
