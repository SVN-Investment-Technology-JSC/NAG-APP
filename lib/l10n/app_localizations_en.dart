// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vehicle Management';

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
  String get prioritize => 'Move to top';

  @override
  String get vehiclesAtStation => 'vehicles at station';

  @override
  String get moveToTop => 'Move to top';

  @override
  String get stationOverview => 'Station Overview';

  @override
  String vehicleCount(Object count) {
    return '$count vehicles';
  }

  @override
  String get todayOrders => 'Today\'s Orders';

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
  String get vehicleManagement => 'Trips';

  @override
  String get selectDate => 'Select date';

  @override
  String get noVehicles => 'No mixer trucks';

  @override
  String get tripsOnDate => 'Trips on date';

  @override
  String get stopCountLabel => 'stops';

  @override
  String get attendance => 'Attendance';

  @override
  String get attendanceWorking => 'Working';

  @override
  String get attendanceOff => 'Off';

  @override
  String get attendanceHalf => 'Half day';

  @override
  String get attendanceTotal => 'Total';

  @override
  String get noAttendanceData => 'No attendance data';

  @override
  String get shiftClose => 'Close Shift';

  @override
  String get shiftCloseConfirmTitle => 'Confirm Close Shift';

  @override
  String get shiftCloseConfirmContent =>
      'Are you sure you want to close today\'s shift? All pending orders will be canceled.';

  @override
  String get shiftCloseSuccess => 'Shift closed successfully';

  @override
  String get shiftCloseFailed => 'Failed to close shift';

  @override
  String shiftPendingWarning(Object count) {
    return '$count pending orders remaining';
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
}
