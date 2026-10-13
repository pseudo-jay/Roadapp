import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/driving_monitor.dart';
import 'services/report_store.dart';
import 'services/settings_store.dart';
import 'services/siri_bridge.dart';
import 'services/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final driving = DrivingMonitor();
  final settings = SettingsStore(driving);
  final reports = ReportStore();
  await Future.wait([settings.load(), reports.load()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: driving),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: reports),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        Provider(create: (_) => SiriBridge(), dispose: (_, s) => s.dispose()),
      ],
      child: const ClearRoadsApp(),
    ),
  );
}
