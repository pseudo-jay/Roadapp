import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/report.dart';
import '../services/driving_detector.dart';
import '../services/driving_monitor.dart';
import '../services/report_store.dart';
import '../services/triage_engine.dart';
import '../theme.dart';

/// The Submit button, locked while the user is driving.
class SubmitGate extends StatelessWidget {
  const SubmitGate({super.key, required this.report, this.compact = false});

  final Report report;
  final bool compact;

  static Future<void> submit(BuildContext context, Report report) async {
    final store = context.read<ReportStore>();
    final driving = context.read<DrivingMonitor>();
    final messenger = ScaffoldMessenger.of(context);
    if (!driving.canSubmit) return;
    final triage = TriageEngine.evaluate(report);
    try {
      await store.submit(report, canSubmit: driving.canSubmit);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Submitted · routed to ${triage.jurisdiction}'),
          backgroundColor: AppColors.success,
        ),
      );
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static Future<void> submitAll(
    BuildContext context,
    List<Report> drafts,
  ) async {
    final store = context.read<ReportStore>();
    final driving = context.read<DrivingMonitor>();
    final messenger = ScaffoldMessenger.of(context);
    var sent = 0;
    for (final d in List.of(drafts)) {
      if (!driving.canSubmit) break;
      await store.submit(d, canSubmit: driving.canSubmit);
      sent++;
    }
    HapticFeedback.mediumImpact();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Submitted $sent report${sent == 1 ? '' : 's'}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driving = context.watch<DrivingMonitor>();
    if (driving.canSubmit) {
      return FilledButton.icon(
        style: compact
            ? FilledButton.styleFrom(minimumSize: const Size(0, 44))
            : null,
        onPressed: () => submit(context, report),
        icon: const Icon(Icons.send_rounded),
        label: const Text('Submit report'),
      );
    }

    final secs = driving.secondsUntilStopped;
    final String reason = switch (driving.state) {
      DrivingState.driving when secs != null =>
        'Unlocks after you stay stopped · ${secs}s',
      DrivingState.driving => 'You appear to be driving',
      _ => 'Checking whether you are driving…',
    };

    return Semantics(
      label: 'Submit locked. $reason',
      child: Container(
        height: compact ? 44 : 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: AppColors.amberText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submit when stopped',
                    style: TextStyle(
                      color: AppColors.amberText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (!compact)
                    Text(
                      reason,
                      style: const TextStyle(
                        color: AppColors.amberText,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
