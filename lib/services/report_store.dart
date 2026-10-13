import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/sample_reports.dart';
import '../models/hazard.dart';
import '../models/report.dart';
import 'triage_engine.dart';

/// Local-first report storage. Everything persists on-device so drafts made
/// with no signal on a rural road are never lost.
class ReportStore extends ChangeNotifier {
  static const _key = 'clear_roads.reports.v1';
  static const _uuid = Uuid();

  final List<Report> _reports = [];
  SharedPreferences? _prefs;
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Newest first.
  List<Report> get all => List.unmodifiable(_reports);
  List<Report> get drafts => _reports.where((r) => r.isDraft).toList();
  List<Report> get submitted => _reports.where((r) => !r.isDraft).toList();
  List<Report> get mine => _reports.where((r) => !r.isSample).toList();

  int get openCount => _reports.where((r) => r.status.isOpen).length;
  int get resolvedCount =>
      _reports.where((r) => r.status == ReportStatus.resolved).length;

  Report? byId(String id) {
    for (final r in _reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    _reports.clear();
    if (raw == null) {
      _reports.addAll(buildSampleReports(DateTime.now()));
    } else {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _reports.addAll(
          list.map((e) => Report.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {
        _reports.addAll(buildSampleReports(DateTime.now()));
      }
    }
    _sort();
    _loaded = true;
    notifyListeners();
    await _save();
  }

  void _sort() => _reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      jsonEncode(_reports.map((r) => r.toJson()).toList()),
    );
  }

  Future<Report> createDraft({
    required HazardType hazard,
    Blockage blockage = Blockage.unknown,
    String description = '',
    double? latitude,
    double? longitude,
    String? road,
    String? locality,
    ReportSource source = ReportSource.voice,
    bool whileDriving = false,
  }) async {
    final now = DateTime.now();
    final r = Report(
      id: _uuid.v4(),
      hazard: hazard,
      blockage: blockage,
      description: description,
      latitude: latitude,
      longitude: longitude,
      road: road,
      locality: locality,
      createdAt: now,
      source: source,
      reportedWhileDriving: whileDriving,
      timeline: [
        TimelineEvent(
          title: 'Draft saved',
          detail:
              '${source.label} report${whileDriving ? ' while driving' : ''}',
          at: now,
        ),
      ],
    );
    _reports.insert(0, r);
    notifyListeners();
    await _save();
    return r;
  }

  Future<void> update(Report r) async {
    notifyListeners();
    await _save();
  }

  /// Submit a draft. Callers must check [DrivingMonitor.canSubmit] first;
  /// this is enforced again here as a last line of defence.
  Future<void> submit(Report r, {required bool canSubmit}) async {
    if (!canSubmit) {
      throw StateError(
        'Reports can only be submitted when you are not driving.',
      );
    }
    if (!r.isDraft) return;
    final now = DateTime.now();
    final triage = TriageEngine.evaluate(r);
    final dup = TriageEngine.findDuplicate(r, _reports);
    r.status = ReportStatus.submitted;
    r.submittedAt = now;
    r.timeline.addAll([
      TimelineEvent(title: 'Submitted', at: now),
      TimelineEvent(
        title:
            'Auto-triaged · Priority ${triage.score}/100 (${triage.level.label})',
        detail: triage.headline,
        at: now,
        actor: 'Clear Roads',
      ),
      TimelineEvent(
        title: 'Routed to ${triage.jurisdiction}',
        detail: '${triage.roadClass.label} · Recommended: ${triage.crew}',
        at: now,
        actor: 'Clear Roads',
      ),
      if (dup != null)
        TimelineEvent(
          title: 'Linked to a nearby report',
          detail:
              'Same hazard reported near ${dup.placeLabel} — merged as a confirmation.',
          at: now,
          actor: 'Clear Roads',
        ),
    ]);
    notifyListeners();
    await _save();
  }

  /// Demo only: simulate the agency moving the report forward.
  Future<void> advanceStatus(Report r) async {
    final next = r.status.next;
    if (next == null || r.isDraft) return;
    final triage = TriageEngine.evaluate(r);
    r.status = next;
    r.timeline.add(
      TimelineEvent(
        title: next.label,
        detail: switch (next) {
          ReportStatus.underReview => 'Dispatcher reviewing the report',
          ReportStatus.acknowledged =>
            '${triage.jurisdiction} accepted the work order',
          ReportStatus.inProgress => '${triage.crew} dispatched',
          ReportStatus.resolved =>
            'Crew cleared the hazard. Thanks for reporting!',
          _ => null,
        },
        at: DateTime.now(),
        actor: triage.jurisdiction,
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> delete(Report r) async {
    _reports.removeWhere((x) => x.id == r.id);
    notifyListeners();
    await _save();
  }

  Future<void> resetDemo() async {
    _reports
      ..clear()
      ..addAll(buildSampleReports(DateTime.now()));
    _sort();
    notifyListeners();
    await _save();
  }
}
