/// App entry point: Riverpod scope, theming (medical palette + dark mode),
/// route table, FCM init and the auth-gated navigation shell.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'providers/providers.dart';
import 'screens/alert_detail_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/baby_details_screen.dart';
import 'screens/bracelet_info_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/graphs_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_monitoring_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_service.dart';
import 'utils/l10n.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BraceletApp()));
}

class BraceletApp extends ConsumerStatefulWidget {
  const BraceletApp({super.key});
  @override
  ConsumerState<BraceletApp> createState() => _BraceletAppState();
}

class _BraceletAppState extends ConsumerState<BraceletApp> {
  @override
  void initState() {
    super.initState();
    // FCM init is fire-and-forget; app remains usable if Firebase files are
    // absent during development (push simply stays disabled).
    Future(() async {
      try {
        await PushService(ref.read(apiClientProvider), navigatorKey).init();
      } catch (_) {/* no google-services.json yet */}
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(darkModeProvider);
    final locale = ref.watch(localeCodeProvider);
    return MaterialApp(
      title: 'Bracelet Monitor',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/home': (_) => const HomeScreen(),
        '/baby-details': (_) => const BabyDetailsScreen(),
        '/live': (_) => const LiveMonitoringScreen(),
        '/graphs': (_) => const GraphsScreen(),
        '/history': (_) => const HistoryScreen(),
        '/alerts': (_) => const AlertsScreen(),
        '/alert-detail': (_) => const AlertDetailScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/pairing': (_) => const PairingScreen(),
        '/bracelet-info': (_) => const BraceletInfoScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/notifications': (_) => const NotificationsScreen(),
      },
    );
  }
}
