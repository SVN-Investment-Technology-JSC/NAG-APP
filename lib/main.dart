import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/app.dart';
import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/push/fleet_push.dart';
import 'package:nguyenanh/core/theme/theme_provider.dart';
import 'package:nguyenanh/core/theme/ui_version_provider.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';
import 'package:nguyenanh/features/application_form/presentation/application_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting();

  await ApiClient.init();

  // Firebase push for fleet-monitoring alerts (off until Firebase is configured)
  await FleetPush.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UiVersionProvider()),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationProvider()),
      ],
      child: const VehicleApp(),
    ),
  );
}
