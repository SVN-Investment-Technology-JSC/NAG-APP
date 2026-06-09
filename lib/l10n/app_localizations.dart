import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Nguyên Anh'**
  String get appTitle;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @mixerFilter.
  ///
  /// In en, this message translates to:
  /// **'Mixers'**
  String get mixerFilter;

  /// No description provided for @otherFilter.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get otherFilter;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language / Ngôn ngữ'**
  String get selectLanguage;

  /// No description provided for @fleetSelection.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get fleetSelection;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember login information'**
  String get rememberMe;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get confirm;

  /// No description provided for @pleaseEnterDetails.
  ///
  /// In en, this message translates to:
  /// **'Please enter all details'**
  String get pleaseEnterDetails;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logOut;

  /// No description provided for @selectHint.
  ///
  /// In en, this message translates to:
  /// **'Select {label}'**
  String selectHint(Object label);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get confirmLogoutTitle;

  /// No description provided for @confirmLogoutContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirmLogoutContent;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password'**
  String get loginInvalidCredentials;

  /// No description provided for @loginServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server'**
  String get loginServerUnavailable;

  /// No description provided for @loginGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get loginGenericError;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @pendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get pendingOrders;

  /// No description provided for @noPendingOrders.
  ///
  /// In en, this message translates to:
  /// **'No pending orders'**
  String get noPendingOrders;

  /// No description provided for @changeStation.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeStation;

  /// No description provided for @selectStation.
  ///
  /// In en, this message translates to:
  /// **'Select Station'**
  String get selectStation;

  /// No description provided for @orderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Order updated successfully'**
  String get orderUpdated;

  /// No description provided for @orderUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update order'**
  String get orderUpdateFailed;

  /// No description provided for @reorderSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order positions updated'**
  String get reorderSuccess;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get refreshing;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get sessionExpired;

  /// No description provided for @vehicleLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicleLabel;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverLabel;

  /// No description provided for @stationLabel.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get stationLabel;

  /// No description provided for @orderPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get orderPositionLabel;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @collecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting'**
  String get collecting;

  /// No description provided for @prioritize.
  ///
  /// In en, this message translates to:
  /// **'Prioritize'**
  String get prioritize;

  /// No description provided for @vehiclesAtStation.
  ///
  /// In en, this message translates to:
  /// **'vehicles at station'**
  String get vehiclesAtStation;

  /// No description provided for @moveToTop.
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get moveToTop;

  /// No description provided for @stationOverview.
  ///
  /// In en, this message translates to:
  /// **'Station overview'**
  String get stationOverview;

  /// No description provided for @vehicleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} vehicles'**
  String vehicleCount(Object count);

  /// No description provided for @todayOrders.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Queue'**
  String get todayOrders;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @initStatus.
  ///
  /// In en, this message translates to:
  /// **'Init'**
  String get initStatus;

  /// No description provided for @vehicleRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get vehicleRunning;

  /// No description provided for @vehicleParked.
  ///
  /// In en, this message translates to:
  /// **'Parked'**
  String get vehicleParked;

  /// No description provided for @vehicleOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get vehicleOffline;

  /// No description provided for @speedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speedLabel;

  /// No description provided for @distanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @completedTrips.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedTrips;

  /// No description provided for @activeTrips.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get activeTrips;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get completedStatus;

  /// No description provided for @noTripsForVehicle.
  ///
  /// In en, this message translates to:
  /// **'No trips for this vehicle today'**
  String get noTripsForVehicle;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @vehicleManagement.
  ///
  /// In en, this message translates to:
  /// **'Daily Trips'**
  String get vehicleManagement;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @noVehicles.
  ///
  /// In en, this message translates to:
  /// **'No tankers'**
  String get noVehicles;

  /// No description provided for @tripsOnDate.
  ///
  /// In en, this message translates to:
  /// **'Daily Trips'**
  String get tripsOnDate;

  /// No description provided for @stopCountLabel.
  ///
  /// In en, this message translates to:
  /// **'stops'**
  String get stopCountLabel;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @attendanceWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get attendanceWorking;

  /// No description provided for @attendanceOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get attendanceOff;

  /// No description provided for @attendanceHalf.
  ///
  /// In en, this message translates to:
  /// **'Half-day'**
  String get attendanceHalf;

  /// No description provided for @attendanceTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get attendanceTotal;

  /// No description provided for @noAttendanceData.
  ///
  /// In en, this message translates to:
  /// **'No attendance data'**
  String get noAttendanceData;

  /// No description provided for @shiftClose.
  ///
  /// In en, this message translates to:
  /// **'Shift Close'**
  String get shiftClose;

  /// No description provided for @shiftCloseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Shift Close'**
  String get shiftCloseConfirmTitle;

  /// No description provided for @shiftCloseConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to close shift? All pending orders will be canceled.'**
  String get shiftCloseConfirmContent;

  /// No description provided for @shiftCloseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shift closed successfully'**
  String get shiftCloseSuccess;

  /// No description provided for @shiftCloseFailed.
  ///
  /// In en, this message translates to:
  /// **'Shift close failed'**
  String get shiftCloseFailed;

  /// No description provided for @shiftPendingWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} pending orders'**
  String shiftPendingWarning(Object count);

  /// No description provided for @mealCheck.
  ///
  /// In en, this message translates to:
  /// **'Meal Check'**
  String get mealCheck;

  /// No description provided for @mealCheckRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get mealCheckRefresh;

  /// No description provided for @mealCheckLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking meals...'**
  String get mealCheckLoading;

  /// No description provided for @mealCheckNoData.
  ///
  /// In en, this message translates to:
  /// **'No meal data'**
  String get mealCheckNoData;

  /// No description provided for @mealCheckTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get mealCheckTotal;

  /// No description provided for @mealCheckMorning.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealCheckMorning;

  /// No description provided for @mealCheckLunch.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get mealCheckLunch;

  /// No description provided for @mealCheckDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealCheckDinner;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmpty;

  /// No description provided for @notificationRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notificationRead;

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get notificationUnread;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme (Light/Dark)'**
  String get themeMode;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'ROLE'**
  String get role;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'REGION'**
  String get region;

  /// No description provided for @dashboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Central Dashboard'**
  String get dashboardDesc;

  /// No description provided for @dailyTrips.
  ///
  /// In en, this message translates to:
  /// **'Daily Trips'**
  String get dailyTrips;

  /// No description provided for @tripsDesc.
  ///
  /// In en, this message translates to:
  /// **'Update schedules'**
  String get tripsDesc;

  /// No description provided for @attendanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Working history'**
  String get attendanceDesc;

  /// No description provided for @mealDesc.
  ///
  /// In en, this message translates to:
  /// **'Register meals'**
  String get mealDesc;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Account & App'**
  String get settingsDesc;

  /// No description provided for @supportLegal.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & LEGAL'**
  String get supportLegal;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @defaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUser;

  /// No description provided for @defaultRoleDesc.
  ///
  /// In en, this message translates to:
  /// **'Fleet Manager #42'**
  String get defaultRoleDesc;

  /// No description provided for @defaultRegion.
  ///
  /// In en, this message translates to:
  /// **'Hanoi'**
  String get defaultRegion;

  /// No description provided for @tripManagement.
  ///
  /// In en, this message translates to:
  /// **'Trip Management'**
  String get tripManagement;

  /// No description provided for @vehicleQueue.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Queue'**
  String get vehicleQueue;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @tripsTab.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripsTab;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// No description provided for @reportsTab.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTab;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt (VN)'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English (EN)'**
  String get english;

  /// No description provided for @mealShareError.
  ///
  /// In en, this message translates to:
  /// **'Error sharing image!'**
  String get mealShareError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @mealTableTitle.
  ///
  /// In en, this message translates to:
  /// **'MEAL ALLOWANCE RECORD'**
  String get mealTableTitle;

  /// No description provided for @mealFromDate.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get mealFromDate;

  /// No description provided for @mealToDate.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get mealToDate;

  /// No description provided for @mealSTT.
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get mealSTT;

  /// No description provided for @mealFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get mealFullName;

  /// No description provided for @mealTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get mealTotal;

  /// No description provided for @mealGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get mealGrandTotal;

  /// No description provided for @mealUnit.
  ///
  /// In en, this message translates to:
  /// **'meals'**
  String get mealUnit;

  /// No description provided for @mealChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get mealChecking;

  /// No description provided for @mealCheckBtn.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get mealCheckBtn;

  /// No description provided for @mealCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Select date, slot then press Check'**
  String get mealCheckHint;

  /// No description provided for @mealShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get mealShareTooltip;

  /// No description provided for @attendanceStats.
  ///
  /// In en, this message translates to:
  /// **'Personnel Statistics'**
  String get attendanceStats;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'UPDATING'**
  String get updating;

  /// No description provided for @totalPersonnel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get totalPersonnel;

  /// No description provided for @allSystems.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEES SYSTEM-WIDE'**
  String get allSystems;

  /// No description provided for @allPersonnel.
  ///
  /// In en, this message translates to:
  /// **'All Personnel'**
  String get allPersonnel;

  /// No description provided for @workingStatus.
  ///
  /// In en, this message translates to:
  /// **'WORKING'**
  String get workingStatus;

  /// No description provided for @personnelWorking.
  ///
  /// In en, this message translates to:
  /// **'Working Personnel'**
  String get personnelWorking;

  /// No description provided for @offStatus.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get offStatus;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'ABSENT'**
  String get absent;

  /// No description provided for @personnelOff.
  ///
  /// In en, this message translates to:
  /// **'Off Personnel'**
  String get personnelOff;

  /// No description provided for @halfDayStatus.
  ///
  /// In en, this message translates to:
  /// **'HALF DAY'**
  String get halfDayStatus;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'APPROVED'**
  String get approved;

  /// No description provided for @personnelHalfDay.
  ///
  /// In en, this message translates to:
  /// **'Half-day Personnel'**
  String get personnelHalfDay;

  /// No description provided for @groupList.
  ///
  /// In en, this message translates to:
  /// **'Group List'**
  String get groupList;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'VIEW ALL'**
  String get viewAll;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'PERFORMANCE'**
  String get performance;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export Excel'**
  String get exportExcel;

  /// No description provided for @openGoogleSheet.
  ///
  /// In en, this message translates to:
  /// **'Open Google Sheet'**
  String get openGoogleSheet;

  /// No description provided for @personnelList.
  ///
  /// In en, this message translates to:
  /// **'Personnel List'**
  String get personnelList;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthLabel;

  /// No description provided for @stt.
  ///
  /// In en, this message translates to:
  /// **'No.'**
  String get stt;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Dept.'**
  String get department;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @activeStations.
  ///
  /// In en, this message translates to:
  /// **'Active Stations'**
  String get activeStations;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All your personal data will be permanently deleted.'**
  String get deleteAccountWarning;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete Account'**
  String get confirmDeleteAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted'**
  String get accountDeleted;

  /// No description provided for @donotHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get donotHaveAccount;

  /// No description provided for @contactAdmin.
  ///
  /// In en, this message translates to:
  /// **'Contact admin for access.'**
  String get contactAdmin;

  /// No description provided for @partnershipContact.
  ///
  /// In en, this message translates to:
  /// **'Partnership Contact'**
  String get partnershipContact;

  /// No description provided for @checkLog.
  ///
  /// In en, this message translates to:
  /// **'CHECK LOG'**
  String get checkLog;

  /// No description provided for @queueHistory.
  ///
  /// In en, this message translates to:
  /// **'QUEUE HISTORY'**
  String get queueHistory;

  /// No description provided for @syncSlots.
  ///
  /// In en, this message translates to:
  /// **'SYNC SLOTS'**
  String get syncSlots;

  /// No description provided for @cameraConnected.
  ///
  /// In en, this message translates to:
  /// **'Camera connected'**
  String get cameraConnected;

  /// No description provided for @cameraDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Camera disconnected'**
  String get cameraDisconnected;

  /// No description provided for @parkedVehicles.
  ///
  /// In en, this message translates to:
  /// **'PARKED VEHICLES'**
  String get parkedVehicles;

  /// No description provided for @transportReport.
  ///
  /// In en, this message translates to:
  /// **'Transport Report'**
  String get transportReport;

  /// No description provided for @production.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get production;

  /// No description provided for @vehicleRanking.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Ranking'**
  String get vehicleRanking;

  /// No description provided for @byDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get byDay;

  /// No description provided for @byWeek.
  ///
  /// In en, this message translates to:
  /// **'By week'**
  String get byWeek;

  /// No description provided for @byMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get byMonth;

  /// No description provided for @exportReportBtn.
  ///
  /// In en, this message translates to:
  /// **'EXPORT REPORT'**
  String get exportReportBtn;

  /// No description provided for @avgProduction.
  ///
  /// In en, this message translates to:
  /// **'AVG PRODUCTION'**
  String get avgProduction;

  /// No description provided for @totalTrips.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TRIPS'**
  String get totalTrips;

  /// No description provided for @completedUpper.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedUpper;

  /// No description provided for @totalKm.
  ///
  /// In en, this message translates to:
  /// **'TOTAL KM'**
  String get totalKm;

  /// No description provided for @productionChart.
  ///
  /// In en, this message translates to:
  /// **'Production Chart'**
  String get productionChart;

  /// No description provided for @productionChartDesc.
  ///
  /// In en, this message translates to:
  /// **'Transport production by {groupBy}'**
  String productionChartDesc(Object groupBy);

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minutes;

  /// No description provided for @transportingStatus.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get transportingStatus;

  /// No description provided for @mixLabel.
  ///
  /// In en, this message translates to:
  /// **'Mix'**
  String get mixLabel;

  /// No description provided for @totalProduction.
  ///
  /// In en, this message translates to:
  /// **'Total production'**
  String get totalProduction;

  /// No description provided for @averageLevel.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get averageLevel;

  /// No description provided for @detailsUpper.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get detailsUpper;

  /// No description provided for @stationPerformance.
  ///
  /// In en, this message translates to:
  /// **'Station Performance'**
  String get stationPerformance;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @trips.
  ///
  /// In en, this message translates to:
  /// **'trips'**
  String get trips;

  /// No description provided for @tons.
  ///
  /// In en, this message translates to:
  /// **'Tons'**
  String get tons;

  /// No description provided for @productionRecent.
  ///
  /// In en, this message translates to:
  /// **'Production by recent period'**
  String get productionRecent;

  /// No description provided for @clickToOpenDetails.
  ///
  /// In en, this message translates to:
  /// **'Click on each period to open trip details'**
  String get clickToOpenDetails;

  /// No description provided for @dayUpper.
  ///
  /// In en, this message translates to:
  /// **'DAY'**
  String get dayUpper;

  /// No description provided for @periodUpper.
  ///
  /// In en, this message translates to:
  /// **'PERIOD'**
  String get periodUpper;

  /// No description provided for @vehicleRankingTitle.
  ///
  /// In en, this message translates to:
  /// **'Productive Vehicle Ranking'**
  String get vehicleRankingTitle;

  /// No description provided for @vehicleRankingDesc.
  ///
  /// In en, this message translates to:
  /// **'Based on total trips and distance'**
  String get vehicleRankingDesc;

  /// No description provided for @vehicleCode.
  ///
  /// In en, this message translates to:
  /// **'VEHICLE CODE'**
  String get vehicleCode;

  /// No description provided for @licensePlate.
  ///
  /// In en, this message translates to:
  /// **'LICENSE PLATE'**
  String get licensePlate;

  /// No description provided for @tripsUpper.
  ///
  /// In en, this message translates to:
  /// **'TRIPS'**
  String get tripsUpper;

  /// No description provided for @operationalLog.
  ///
  /// In en, this message translates to:
  /// **'Operational Log'**
  String get operationalLog;

  /// No description provided for @totalVehicles.
  ///
  /// In en, this message translates to:
  /// **'Total: {count} vehicles'**
  String totalVehicles(Object count);

  /// No description provided for @delivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get delivering;

  /// No description provided for @startedAt.
  ///
  /// In en, this message translates to:
  /// **'started at'**
  String get startedAt;

  /// No description provided for @statusInDay.
  ///
  /// In en, this message translates to:
  /// **'Status in day'**
  String get statusInDay;

  /// No description provided for @searchVehicleHint.
  ///
  /// In en, this message translates to:
  /// **'Find vehicle, license plate...'**
  String get searchVehicleHint;

  /// No description provided for @noStationData.
  ///
  /// In en, this message translates to:
  /// **'No station data yet'**
  String get noStationData;

  /// No description provided for @noTripsFound.
  ///
  /// In en, this message translates to:
  /// **'No trips found'**
  String get noTripsFound;

  /// No description provided for @tripDetail.
  ///
  /// In en, this message translates to:
  /// **'Trip detail'**
  String get tripDetail;

  /// No description provided for @tripsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'{count} trips in this period'**
  String tripsInPeriod(Object count);

  /// No description provided for @otherStatus.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherStatus;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @noTripsYet.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get noTripsYet;

  /// No description provided for @featureUnderDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Feature under development'**
  String get featureUnderDevelopment;

  /// No description provided for @workArrangementAssign.
  ///
  /// In en, this message translates to:
  /// **'Work Assignment'**
  String get workArrangementAssign;

  /// No description provided for @workArrangementTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get workArrangementTasks;

  /// No description provided for @workArrangementStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get workArrangementStats;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
