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
          error: (e, _) {
            // If DB init fails (e.g. missing sqlite3.wasm on web), avoid an
            // infinite spinner and show an error message.
            if (_navigated) return;
            setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_hasOnboardedProvider);

    return Scaffold(
      body: Center(
        child: state.when(
          data: (_) => const CircularProgressIndicator(),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 12),
                Text(
                  'App failed to start',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'If you are running the Docker/web build, make sure `sqlite3.wasm` is served at `/sqlite3.wasm`.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _hasOnboardedProvider = StreamProvider<bool>((ref) {
  return ref.watch(appSettingsRepositoryProvider).watchHasOnboarded();
});

