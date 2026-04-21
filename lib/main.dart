import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'providers/crm_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/offline_sync_service.dart';
import 'services/push_notification_service.dart';
import 'services/reminder_service.dart';
import 'services/birthday_reminder_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();
  await CacheService.instance.init();
  await OfflineSyncService.instance.init();

  // Initialize Firebase — must complete before runApp for FCM to work
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('[INIT] Firebase init failed: $e');
  }

  // Launch the app first, then init push/reminders in the background
  // This prevents white screen if FCM token fetch hangs (iOS simulator)
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CRMProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyCrmApp(),
    ),
  );

  // Post-launch initialization (non-blocking)
  if (firebaseReady) {
    try {
      await PushNotificationService.instance.init();
      FirebaseInAppMessaging.instance.setAutomaticDataCollectionEnabled(true);
    } catch (e) {
      debugPrint('[INIT] Push notification init failed: $e');
    }
  }

  try {
    await ReminderService.instance.initialize();
    await BirthdayReminderService.instance.init();
  } catch (e) {
    debugPrint('[INIT] Reminder services init failed: $e');
  }
}

class MyCrmApp extends StatelessWidget {
  const MyCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'SV Soft Solutions',
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
