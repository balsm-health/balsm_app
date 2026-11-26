import 'package:app/balsm_app/dev/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bump must not open Dev Config; a deliberate shake must.
void main() {
  final t0 = DateTime(2026);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  late ShakeDetector detector;
  setUp(() => detector = ShakeDetector());

  test('a single hard spike is a bump, not a shake', () {
    expect(detector.onSample(40, at(0)), isFalse);
  });

  test('one bump spread over consecutive samples is still one jolt', () {
    expect(detector.onSample(30, at(0)), isFalse);
    expect(detector.onSample(28, at(66)), isFalse);
    expect(detector.onSample(25, at(80)), isFalse);
  });

  test('readings below the threshold never count', () {
    for (var ms = 0; ms < 2000; ms += 66) {
      expect(detector.onSample(10, at(ms)), isFalse);
    }
  });

  test('three spikes inside the window are a shake', () {
    expect(detector.onSample(20, at(0)), isFalse);
    expect(detector.onSample(20, at(200)), isFalse);
    expect(detector.onSample(20, at(400)), isTrue);
  });

  test('spikes spread wider than the window do not add up', () {
    expect(detector.onSample(20, at(0)), isFalse);
    expect(detector.onSample(20, at(600)), isFalse);
    expect(detector.onSample(20, at(1200)), isFalse);
  });

  test('one shake fires once, then rests', () {
    for (final ms in [0, 200, 400]) {
      detector.onSample(20, at(ms));
    }
    expect(detector.onSample(20, at(600)), isFalse);
    expect(detector.onSample(20, at(800)), isFalse);
    expect(detector.onSample(20, at(1000)), isFalse);
  });

  test('a second shake after the cooldown fires again', () {
    for (final ms in [0, 200, 400]) {
      detector.onSample(20, at(ms));
    }
    expect(detector.onSample(20, at(3000)), isFalse);
    expect(detector.onSample(20, at(3200)), isFalse);
    expect(detector.onSample(20, at(3400)), isTrue);
  });
}
