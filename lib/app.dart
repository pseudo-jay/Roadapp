import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/report.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/my_reports_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/voice_report_screen.dart';
import 'services/driving_monitor.dart';
import 'services/report_store.dart';
import 'services/settings_store.dart';
import 'services/siri_bridge.dart';
import 'services/voice_service.dart';
import 'theme.dart';
import 'widgets/common.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class ClearRoadsApp extends StatelessWidget {
  const ClearRoadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    return MaterialApp(
      title: 'Clear Roads',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: settings.onboarded
          ? const AppShell()
          : OnboardingScreen(
              onDone: () async {
                settings.setOnboarded();
                // Trigger the permission prompts right after the explainer.
                await context.read<DrivingMonitor>().start();
                if (context.mounted) await context.read<VoiceService>().init();
              },
            ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
  ReportsTab _reportsTab = ReportsTab.drafts;
  StreamSubscription<SiriRequest>? _siriSub;

  static const _titles = [
    'Clear Roads',
    'Community map',
    '',
    'My reports',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<DrivingMonitor>().start();
    final siri = context.read<SiriBridge>();
    _siriSub = siri.requests.listen(_handleSiri);
    // Requests made while the app was closed (cold launch from Siri).
    WidgetsBinding.instance.addPostFrameCallback((_) => siri.drain());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SiriBridge>().drain();
      final driving = context.read<DrivingMonitor>();
      if (driving.locationDenied) driving.retryLocation();
    }
  }

  void _handleSiri(SiriRequest req) {
    final nav = navigatorKey.currentState;
    if (nav == null || !mounted) return;
    nav.popUntil((r) => r.isFirst);
    switch (req.action) {
      case SiriAction.showDrafts:
        setState(() {
          _tab = 3;
          _reportsTab = ReportsTab.drafts;
        });
      case SiriAction.draft:
        VoiceReportScreen.open(
          nav.context,
          hazard: req.hazard,
          details: req.details,
          source: ReportSource.siri,
        );
    }
  }

  void _select(int i) {
    if (i == 2) {
      VoiceReportScreen.open(context);
      return;
    }
    setState(() => _tab = i);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _siriSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drafts = context.select<ReportStore, int>((s) => s.drafts.length);
    final isDriving = context.select<DrivingMonitor, bool>((d) => d.isDriving);
    final drivingHome = _tab == 0 && isDriving;
    final theme = Theme.of(context);

    final body = switch (_tab) {
      1 => const MapScreen(),
      3 => MyReportsScreen(
        tab: _reportsTab,
        onTab: (t) => setState(() => _reportsTab = t),
      ),
      4 => const SettingsScreen(),
      _ => HomeScreen(onOpenTab: _select),
    };

    return Scaffold(
      backgroundColor: drivingHome ? const Color(0xFF0F172A) : null,
      appBar: AppBar(
        backgroundColor: drivingHome ? const Color(0xFF0F172A) : null,
        foregroundColor: drivingHome ? Colors.white : null,
        titleSpacing: 16,
        title: Row(
          children: [
            if (_tab == 0) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_road_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              _titles[_tab],
              style: drivingHome
                  ? theme.appBarTheme.titleTextStyle?.copyWith(
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: DrivingStatusPill(),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: Theme(
        data: drivingHome ? buildTheme(Brightness.dark) : theme,
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Container(
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white),
              ),
              label: 'Report',
              tooltip: 'Report a hazard by voice',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: drafts > 0,
                label: Text('$drafts'),
                child: const Icon(Icons.list_alt_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: drafts > 0,
                label: Text('$drafts'),
                child: const Icon(Icons.list_alt_rounded),
              ),
              label: 'Reports',
            ),
            const NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
