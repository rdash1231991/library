import 'package:flutter/material.dart';

import 'src/screens/home_screen.dart';
import 'src/services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  runApp(App(settings: settings));
}

class App extends StatelessWidget {
  const App({super.key, required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Presets',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomeScreen(settings: settings),
    );
  }
}

