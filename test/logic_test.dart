import 'package:clear_roads/models/hazard.dart';
import 'package:clear_roads/models/report.dart';
import 'package:clear_roads/services/driving_detector.dart';
import 'package:clear_roads/services/triage_engine.dart';
import 'package:clear_roads/services/voice_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Report _r(HazardType h, Blockage b, {String desc = '', String? road}) => Report(
  id: 'x',
  hazard: h,
  blockage: b,
  description: desc,
  road: road,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('VoiceParser', () {
    test('recognises the three core hazards', () {
      expect(
        VoiceParser.hazard('there is a dead deer on the road'),
        HazardType.deadAnimal,
      );
      expect(VoiceParser.hazard('Roadkill ahead'), HazardType.deadAnimal);
      expect(VoiceParser.hazard('a big tree fell down'), HazardType.fallenTree);
      expect(
        VoiceParser.hazard('dead tree across the road'),
        HazardType.fallenTree,
      );
      expect(VoiceParser.hazard('road is not plowed'), HazardType.snowIce);
      expect(VoiceParser.hazard('black ice on the bridge'), HazardType.snowIce);
      expect(VoiceParser.hazard('pothole'), HazardType.pothole);
      expect(VoiceParser.hazard('hello there'), isNull);
    });

    test('parses lane blockage', () {
      expect(VoiceParser.blockage("it's on the shoulder"), Blockage.shoulder);
      expect(VoiceParser.blockage('blocking both lanes'), Blockage.allLanes);
      expect(VoiceParser.blockage('in the right lane'), Blockage.fullLane);
      expect(
        VoiceParser.blockage('partially in the lane'),
        Blockage.partialLane,
      );
      expect(VoiceParser.blockage("no it isn't blocking"), Blockage.shoulder);
      expect(VoiceParser.blockage('banana'), isNull);
    });

    test('skip and cancel', () {
      expect(VoiceParser.isSkip("No, that's it"), isTrue);
      expect(VoiceParser.isSkip('done'), isTrue);
      expect(VoiceParser.isSkip('near the school bus stop on Main'), isFalse);
      expect(VoiceParser.isCancel('never mind'), isTrue);
    });
  });

  group('TriageEngine', () {
    test('deer in lane on a 55 mph state road is high priority', () {
      final t = TriageEngine.evaluate(
        _r(
          HazardType.deadAnimal,
          Blockage.partialLane,
          desc: 'dead deer',
          road: 'NY-50',
        ),
      );
      expect(t.level, PriorityLevel.high);
      expect(t.jurisdiction, 'State DOT');
      expect(t.headline, 'Deer carcass, partly blocking a lane');
      expect(t.equipment, contains('Traffic cones + arrow board'));
    });

    test('deer on the shoulder of a local street is low/medium', () {
      final t = TriageEngine.evaluate(
        _r(
          HazardType.deadAnimal,
          Blockage.shoulder,
          desc: 'deer',
          road: 'Elm Street',
        ),
      );
      expect(t.level, anyOf(PriorityLevel.low, PriorityLevel.medium));
      expect(t.jurisdiction, 'Town Public Works');
    });

    test('tree blocking all lanes is critical', () {
      final t = TriageEngine.evaluate(
        _r(HazardType.fallenTree, Blockage.allLanes, road: 'Route 9'),
      );
      expect(t.level, PriorityLevel.critical);
      expect(t.crew, contains('loader'));
    });

    test('snow on a school route adds advisory', () {
      final t = TriageEngine.evaluate(
        _r(
          HazardType.snowIce,
          Blockage.allLanes,
          desc: 'unplowed school bus route',
          road: 'County Route 9P',
        ),
      );
      expect(t.jurisdiction, 'County Highway Department');
      expect(t.advisories, isNotEmpty);
    });

    test('duplicate detection within 200 m', () {
      final a = _r(HazardType.fallenTree, Blockage.allLanes)
        ..latitude = 43.0
        ..longitude = -73.0;
      final b = Report(
        id: 'y',
        hazard: HazardType.fallenTree,
        createdAt: DateTime(2026, 1, 1, 1),
        latitude: 43.0005,
        longitude: -73.0,
        status: ReportStatus.submitted,
      );
      expect(TriageEngine.findDuplicate(a, [b])?.id, 'y');
      b.longitude = -73.01;
      expect(TriageEngine.findDuplicate(a, [b]), isNull);
    });
  });

  group('DrivingDetector', () {
    final t0 = DateTime(2026, 1, 1, 8);

    test('fast GPS speed means driving', () {
      final d = DrivingDetector();
      expect(d.onSpeed(20, t0), DrivingState.driving);
    });

    test('red light does not unlock submit; long stop does', () {
      final d = DrivingDetector();
      d.onSpeed(20, t0);
      expect(
        d.onSpeed(0, t0.add(const Duration(seconds: 1))),
        DrivingState.driving,
      );
      expect(d.tick(t0.add(const Duration(seconds: 30))), DrivingState.driving);
      expect(d.tick(t0.add(const Duration(seconds: 47))), DrivingState.stopped);
    });

    test('walking ends driving immediately', () {
      final d = DrivingDetector();
      d.onSpeed(20, t0);
      d.onSpeed(1.2, t0.add(const Duration(seconds: 2)));
      expect(
        d.onMotion(
          const MotionSample(walking: true, confidence: 2),
          t0.add(const Duration(seconds: 3)),
        ),
        DrivingState.stopped,
      );
    });

    test('automotive motion counts as driving even without GPS', () {
      final d = DrivingDetector();
      expect(
        d.onMotion(const MotionSample(automotive: true, confidence: 2), t0),
        DrivingState.driving,
      );
    });

    test('moving again resets the stop timer', () {
      final d = DrivingDetector();
      d.onSpeed(20, t0);
      d.onSpeed(0, t0.add(const Duration(seconds: 1)));
      d.onSpeed(15, t0.add(const Duration(seconds: 30)));
      d.onSpeed(0, t0.add(const Duration(seconds: 31)));
      expect(d.tick(t0.add(const Duration(seconds: 60))), DrivingState.driving);
      expect(d.tick(t0.add(const Duration(seconds: 77))), DrivingState.stopped);
    });
  });

  test('Report JSON round-trip', () {
    final r =
        _r(HazardType.snowIce, Blockage.fullLane, desc: 'icy', road: 'Main St')
          ..latitude = 1
          ..longitude = 2;
    final back = Report.fromJson(r.toJson());
    expect(back.hazard, HazardType.snowIce);
    expect(back.blockage, Blockage.fullLane);
    expect(back.road, 'Main St');
    expect(back.latitude, 1);
  });
}
