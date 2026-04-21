import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Set preferred orientations and system UI overlay style for native feel
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
  ));

  // Init core services in parallel for faster startup
  await Future.wait([
    ApiService.instance.init(),
    CacheService.instance.init(),
    OfflineSyncService.instance.init(),
  ]);

  // Initialize Firebase — must complete before runApp for FCM to work
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('[INIT] Firebase init failed: $e');
  }

  // Launch the app first, then init push/reminders in the background
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

/// Custom page route with smooth native-feel slide transition
class SmoothPageRoute<T> extends MaterialPageRoute<T> {
  SmoothPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);
}

class MyCrmApp extends StatelessWidget {
  const MyCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'SV Soft Solutions',
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
