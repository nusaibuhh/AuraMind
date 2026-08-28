import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';

import 'providers/questionnaire_provider.dart';

import 'providers/theme_provider.dart';

import 'providers/sleep_provider.dart';
import 'providers/breathing_provider.dart';
import 'providers/mood_analytics_provider.dart';
import 'providers/mood_momentum_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/behavioral_activation_provider.dart';
import 'providers/savoring_provider.dart';
import 'providers/consultation_provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/checkin/intro_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';

class AuraMindApp extends StatelessWidget {
  AuraMindApp({super.key});

  // IMPORTANT: this single ApiService instance is shared by every provider
  // that needs to make authenticated requests. AuthProvider.login()/signUp()
  // calls setToken() on this exact instance, so any other provider using it
  // (e.g. SleepProvider, BreathingProvider) automatically gets the Authorization header too.
  final ApiService _sharedApiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(api: _sharedApiService)),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => QuestionnaireProvider()),
        ChangeNotifierProvider(create: (_) => SleepProvider(_sharedApiService)),
        ChangeNotifierProvider(
            create: (_) => BreathingProvider(_sharedApiService)),
        ChangeNotifierProvider(
          create: (_) => MoodAnalyticsProvider(_sharedApiService),
        ),
        ChangeNotifierProvider(create: (_) => MoodMomentumProvider()),
        ChangeNotifierProvider(
            create: (_) => JournalProvider(_sharedApiService)),
        ChangeNotifierProvider(
          create: (_) => BehavioralActivationProvider(_sharedApiService),
        ),
        ChangeNotifierProvider(
          create: (_) => SavoringProvider(_sharedApiService),
        ),
        ChangeNotifierProvider(
          create: (_) => ConsultationProvider(_sharedApiService),
        ),
      ],
      child: Consumer<AppThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AuraMind',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const _AppRouter(),
          );
        },
      ),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  String? _loadedUserId;
  String? _behavioralActivationUserId;
  String? _savoringUserId;
  String? _consultationUserId;

  void _syncThemeForUser(AuthProvider auth, AppThemeProvider themeProvider) {
    if (!auth.isLoggedIn) {
      _loadedUserId = null;

      return;
    }

    final userId = auth.user!.id;

    if (_loadedUserId == userId) return;

    _loadedUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      themeProvider.loadSavedTheme(auth.api);
    });
  }

  void _syncBehavioralActivationForUser(
    AuthProvider auth,
    BehavioralActivationProvider behavioralActivation,
  ) {
    final userId = auth.user?.id;
    if (_behavioralActivationUserId == userId) return;

    _behavioralActivationUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      behavioralActivation.reset();
    });
  }

  void _syncSavoringForUser(
    AuthProvider auth,
    SavoringProvider savoring,
  ) {
    final userId = auth.user?.id;
    if (_savoringUserId == userId) return;

    _savoringUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      savoring.reset();
    });
  }

  void _syncConsultationsForUser(
    AuthProvider auth,
    ConsultationProvider consultations,
  ) {
    final userId = auth.user?.id;
    if (_consultationUserId == userId) return;

    _consultationUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      consultations.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final themeProvider = context.watch<AppThemeProvider>();
    final behavioralActivation = context.read<BehavioralActivationProvider>();
    final savoring = context.read<SavoringProvider>();
    final consultations = context.read<ConsultationProvider>();

    _syncThemeForUser(auth, themeProvider);
    _syncBehavioralActivationForUser(auth, behavioralActivation);
    _syncSavoringForUser(auth, savoring);
    _syncConsultationsForUser(auth, consultations);

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (themeProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!themeProvider.hasCompletedCheckIn) {
      return const IntroScreen();
    }

    return const HomeScreen();
  }
}
