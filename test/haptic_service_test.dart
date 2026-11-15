import 'package:flutter_test/flutter_test.dart';
import 'package:volei/services/haptic_service.dart';

void main() {
  setUp(() {
    HapticService.setVibrationEnabled(true);
  });

  group('HapticService Tests', () {
    test('Initial vibration state defaults to true', () {
      expect(HapticService.isVibrationEnabled, isTrue);
    });

    test('toggleVibration flips state cleanly', () {
      final newState1 = HapticService.toggleVibration();
      expect(newState1, isFalse);
      expect(HapticService.isVibrationEnabled, isFalse);

      final newState2 = HapticService.toggleVibration();
      expect(newState2, isTrue);
      expect(HapticService.isVibrationEnabled, isTrue);
    });

    test('setVibrationEnabled updates state directly', () {
      HapticService.setVibrationEnabled(false);
      expect(HapticService.isVibrationEnabled, isFalse);

      HapticService.setVibrationEnabled(true);
      expect(HapticService.isVibrationEnabled, isTrue);
    });

    test('spikeImpact executes safely without throwing in test environment', () async {
      await expectLater(HapticService.spikeImpact(perfect: false), completes);
      await expectLater(HapticService.spikeImpact(perfect: true), completes);

      // Even when disabled, completes safely
      HapticService.setVibrationEnabled(false);
      await expectLater(HapticService.spikeImpact(perfect: false), completes);
      await expectLater(HapticService.spikeImpact(perfect: true), completes);
    });

    test('monsterBlockImpact executes safely without throwing in test environment', () async {
      await expectLater(HapticService.monsterBlockImpact(), completes);

      // Even when disabled, completes safely
      HapticService.setVibrationEnabled(false);
      await expectLater(HapticService.monsterBlockImpact(), completes);
    });

    test('selectionFeedback executes safely without throwing in test environment', () async {
      await expectLater(HapticService.selectionFeedback(), completes);

      HapticService.setVibrationEnabled(false);
      await expectLater(HapticService.selectionFeedback(), completes);
    });
  });
}
