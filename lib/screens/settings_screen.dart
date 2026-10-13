import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/driving_detector.dart';
import '../services/driving_monitor.dart';
import '../services/report_store.dart';
import '../services/settings_store.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final driving = context.watch<DrivingMonitor>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionHeader('Siri & Shortcuts'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No setup needed — these phrases work as soon as the app is installed. '
                  'Siri asks what you saw, opens Clear Roads and saves a draft at your location.',
                ),
                const SizedBox(height: 12),
                for (final phrase in const [
                  'Hey Siri, report a hazard in Clear Roads',
                  'Hey Siri, report a fallen tree in Clear Roads',
                  'Hey Siri, report a dead animal with Clear Roads',
                  'Hey Siri, report snow or ice in Clear Roads',
                  'Hey Siri, show my Clear Roads drafts',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mic_rounded,
                            size: 18,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '“$phrase”',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  'Tip: add “Report Hazard” to your Action button or CarPlay Siri suggestions '
                  'from the Shortcuts app.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionHeader('Driving detection'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const DrivingStatusPill(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        driving.sourceLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Clear Roads combines GPS speed with the iPhone motion sensor. '
                  'Submitting unlocks after the car has been still for 45 seconds, '
                  'or as soon as you start walking — so a red light never unlocks it.',
                ),
                if (driving.locationDenied) ...[
                  const SizedBox(height: 12),
                  SafetyBanner(
                    icon: Icons.location_off_rounded,
                    text: 'Location is off. Turn it on in Settings so reports are tagged and driving can be detected.',
                    trailing: TextButton(
                      onPressed: driving.retryLocation,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Demo override', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  'For demos without a moving car.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DrivingOverride>(
                    segments: const [
                      ButtonSegment(
                        value: DrivingOverride.auto,
                        icon: Icon(Icons.sensors_rounded),
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: DrivingOverride.forceDriving,
                        icon: Icon(Icons.directions_car_rounded),
                        label: Text('Driving'),
                      ),
                      ButtonSegment(
                        value: DrivingOverride.forceStopped,
                        icon: Icon(Icons.local_parking_rounded),
                        label: Text('Stopped'),
                      ),
                    ],
                    selected: {settings.drivingOverride},
                    onSelectionChanged: (s) =>
                        settings.setDrivingOverride(s.first),
                  ),
                ),
                if (driving.state == DrivingState.unknown &&
                    settings.drivingOverride == DrivingOverride.auto) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Waiting for a GPS fix…',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SectionHeader('Preferences'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_rounded),
                title: const Text('Spoken prompts'),
                subtitle: const Text(
                  'Ask questions out loud and listen for answers',
                ),
                value: settings.voicePrompts,
                onChanged: settings.setVoicePrompts,
              ),
              const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    const Icon(Icons.dark_mode_rounded),
                    const SizedBox(width: 16),
                    const Expanded(child: Text('Appearance')),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Auto'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (s) => settings.setThemeMode(s.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionHeader('Demo data'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Reset demo'),
            subtitle: const Text(
              'Remove your reports and restore the sample data',
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset demo data?'),
                  content: const Text(
                    'Your drafts and reports on this device will be removed.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<ReportStore>().resetDemo();
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Clear Roads prototype. Classification, priority scoring, jurisdiction routing '
          'and crew recommendations are deterministic simulations; reports are stored on '
          'this device and are not sent to any agency.\n\n'
          'Emergency? Call 911. Never handle your phone while driving.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
