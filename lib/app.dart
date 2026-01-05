import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/create_challenge/create_challenge_screen.dart';
import 'features/checklist/checklist_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/share/share_screen.dart';
import 'widgets/splash_decider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashDecider(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreateChallengeScreen(),
    ),
    GoRoute(
      path: '/checklist/:challengeId',
      builder: (context, state) => ChecklistScreen(
        challengeId: int.parse(state.pathParameters['challengeId']!),
        dateIso: state.uri.queryParameters['date'],
      ),
    ),
    GoRoute(
      path: '/calendar/:challengeId',
      builder: (context, state) => CalendarScreen(
        challengeId: int.parse(state.pathParameters['challengeId']!),
      ),
    ),
    GoRoute(
      path: '/share/:challengeId',
      builder: (context, state) => ShareScreen(
        challengeId: int.parse(state.pathParameters['challengeId']!),
      ),
    ),
  ],
);

