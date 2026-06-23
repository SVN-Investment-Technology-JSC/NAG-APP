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
  String get allFilter => 'All';

  @override
  String get mixerFilter => 'Mixers';

  @override
  String get otherFilter => 'Others';

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
  String get noData => 'No data';

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
  String get completedStatus => 'completed';

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
  String get mealCheckMorning => 'Lunch';

  @override
  String get mealCheckLunch => 'Afternoon';

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
  String get homeTab => 'Home';

  @override
  String get tripsTab => 'Trips';

  @override
  String get profileTab => 'Profile';

  @override
  String get reportsTab => 'Reports';

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

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'This action cannot be undone. All your personal data will be permanently deleted.';

  @override
  String get confirmDeleteAccount => 'Confirm Delete Account';

  @override
  String get accountDeleted => 'Your account has been deleted';

  @override
  String get donotHaveAccount => 'Don\'t have an account?';

  @override
  String get contactAdmin => 'Contact admin for access.';

  @override
  String get partnershipContact => 'Partnership Contact';

  @override
  String get checkLog => 'CHECK LOG';

  @override
  String get queueHistory => 'QUEUE HISTORY';

  @override
  String get syncSlots => 'SYNC SLOTS';

  @override
  String get cameraConnected => 'Camera connected';

  @override
  String get cameraDisconnected => 'Camera disconnected';

  @override
  String get parkedVehicles => 'PARKED VEHICLES';

  @override
  String get transportReport => 'Transport Report';

  @override
  String get production => 'Production';

  @override
  String get vehicleRanking => 'Vehicle Ranking';

  @override
  String get byDay => 'By day';

  @override
  String get byWeek => 'By week';

  @override
  String get byMonth => 'By month';

  @override
  String get exportReportBtn => 'EXPORT REPORT';

  @override
  String get avgProduction => 'AVG PRODUCTION';

  @override
  String get totalTrips => 'TOTAL TRIPS';

  @override
  String get completedUpper => 'COMPLETED';

  @override
  String get totalKm => 'TOTAL KM';

  @override
  String get productionChart => 'Production Chart';

  @override
  String productionChartDesc(Object groupBy) {
    return 'Transport production by $groupBy';
  }

  @override
  String get hours => 'h';

  @override
  String get minutes => 'm';

  @override
  String get transportingStatus => 'Moving';

  @override
  String get mixLabel => 'Mix';

  @override
  String get totalProduction => 'Total production';

  @override
  String get averageLevel => 'Average';

  @override
  String get detailsUpper => 'DETAILS';

  @override
  String get stationPerformance => 'Station Performance';

  @override
  String get seeAll => 'See all';

  @override
  String get trips => 'trips';

  @override
  String get tons => 'Tons';

  @override
  String get productionRecent => 'Production by recent period';

  @override
  String get clickToOpenDetails => 'Click on each period to open trip details';

  @override
  String get dayUpper => 'DAY';

  @override
  String get periodUpper => 'PERIOD';

  @override
  String get vehicleRankingTitle => 'Productive Vehicle Ranking';

  @override
  String get vehicleRankingDesc => 'Based on total trips and distance';

  @override
  String get vehicleCode => 'VEHICLE CODE';

  @override
  String get licensePlate => 'LICENSE PLATE';

  @override
  String get tripsUpper => 'TRIPS';

  @override
  String get operationalLog => 'Operational Log';

  @override
  String totalVehicles(Object count) {
    return 'Total: $count vehicles';
  }

  @override
  String get delivering => 'Delivering';

  @override
  String get startedAt => 'started at';

  @override
  String get statusInDay => 'Status in day';

  @override
  String get searchVehicleHint => 'Find vehicle, license plate...';

  @override
  String get noStationData => 'No station data yet';

  @override
  String get noTripsFound => 'No trips found';

  @override
  String get tripDetail => 'Trip detail';

  @override
  String tripsInPeriod(Object count) {
    return '$count trips in this period';
  }

  @override
  String get otherStatus => 'Other';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get noTripsYet => 'No trips yet';

  @override
  String get featureUnderDevelopment => 'Feature under development';

  @override
  String get workArrangementAssign => 'Work Assignment';

  @override
  String get workArrangementTasks => 'Tasks';

  @override
  String get workArrangementStats => 'Statistics';

  @override
  String get statusAvailable => 'Available';

  @override
  String get statusIncident => 'Incident';

  @override
  String get statusMaintenance => 'Maintenance';

  @override
  String get statusOther => 'Other';

  @override
  String updateStatusSuccess(Object plate) {
    return 'Updated vehicle status for $plate successfully';
  }

  @override
  String get updateStatusFailed => 'Failed to update status';

  @override
  String get confirmChangeStatus => 'Confirm Status Change';

  @override
  String confirmChangePlate(Object plate, Object status) {
    return 'Are you sure you want to change the status of vehicle $plate to $status?';
  }

  @override
  String get updateButton => 'UPDATE';

  @override
  String get vehicleStatusTitle => 'Vehicle Status';
}
