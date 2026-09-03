import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers.dart';
import 'core/services/offline_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'l10n/gen/app_localizations.dart';

// Replace with your project's values (or wire via --dart-define at build
// time — never commit real keys to source control).
const String _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR-PROJECT.supabase.co',
);
const String _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR-ANON-KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  final syncService = OfflineSyncService();
  await syncService.init();

  runApp(
    ProviderScope(
      overrides: [
        offlineSyncServiceProvider.overrideWithValue(syncService),
      ],
      child: const SafetyCoreApp(),
    ),
  );
}

class SafetyCoreApp extends StatelessWidget {
  const SafetyCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safety Core AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,

      // Arabic (ar_SA) is a first-class locale — Flutter derives RTL
      // Directionality automatically from the resolved Locale, no manual
      // TextDirection wiring required anywhere else in the app.
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('en'),
        Locale('ar', 'SA'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: const _AuthGate(),
    );
  }
}

/// Routes to the dashboard if a Supabase session already exists, otherwise
/// to the login screen. Also listens for future sign-in/sign-out events.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AuthState>(
      stream: authService.onAuthStateChange,
      builder: (context, snapshot) {
        final isSignedIn = authService.isSignedIn;
        return isSignedIn ? const DashboardScreen() : const LoginScreen();
      },
    );
  }
}
