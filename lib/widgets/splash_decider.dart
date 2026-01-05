import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/repository_providers.dart';

class SplashDecider extends ConsumerStatefulWidget {
  const SplashDecider({super.key});

  @override
  ConsumerState<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends ConsumerState<SplashDecider> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    ref.listen<AsyncValue<bool>>(
      _hasOnboardedProvider,
      (prev, next) {
        next.whenOrNull(
          data: (hasOnboarded) {
            if (_navigated) return;
            _navigated = true;
            if (hasOnboarded) {
              context.go('/home');
            } else {
              context.go('/onboarding');
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

final _hasOnboardedProvider = StreamProvider<bool>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchHasOnboarded();
});

