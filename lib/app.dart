import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



import 'providers/auth_provider.dart';

import 'providers/questionnaire_provider.dart';

import 'providers/theme_provider.dart';

import 'providers/sleep_provider.dart';
import 'providers/breathing_provider.dart';
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
        ChangeNotifierProvider(create: (_) => AuthProvider(api: _sharedApiService)),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => QuestionnaireProvider()),
        ChangeNotifierProvider(create: (_) => SleepProvider(_sharedApiService)),
        ChangeNotifierProvider(create: (_) => BreathingProvider(_sharedApiService)),
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



  @override

  Widget build(BuildContext context) {

    final auth = context.watch<AuthProvider>();

    final themeProvider = context.watch<AppThemeProvider>();



    _syncThemeForUser(auth, themeProvider);



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


