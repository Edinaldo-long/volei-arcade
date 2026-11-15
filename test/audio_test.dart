import 'package:flutter_test/flutter_test.dart';
import 'package:volei/audio/arcade_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArcadeAudio Comprehensive Tests', () {
    test('Track cycle rotates seamlessly through all 4 arcade tracks', () {
      expect(ArcadeAudio.trackNames.length, 4);

      ArcadeAudio.setTrack(0);
      expect(ArcadeAudio.currentTrack, 0);
      expect(ArcadeAudio.currentTrackName, contains('Arcade Clássico'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, 1);
      expect(ArcadeAudio.currentTrackName, contains('Samba Groove'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, 2);
      expect(ArcadeAudio.currentTrackName, contains('Electro Tensão'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, 3);
      expect(ArcadeAudio.currentTrackName, contains('Brisa de Praia'));

      ArcadeAudio.nextTrack();
      expect(ArcadeAudio.currentTrack, 0);
    });

    test('Music toggle updates state cleanly', () {
      ArcadeAudio.setMusicEnabled(false);
      expect(ArcadeAudio.isMusicEnabled, isFalse);

      ArcadeAudio.setMusicEnabled(true);
      expect(ArcadeAudio.isMusicEnabled, isTrue);
    });

    test('SFX methods execute safely in test environment without throwing', () {
      ArcadeAudio.init();
      expect(() => ArcadeAudio.playTouch(), returnsNormally);
      expect(() => ArcadeAudio.playSpike(perfect: false), returnsNormally);
      expect(() => ArcadeAudio.playSpike(perfect: true), returnsNormally);
      expect(() => ArcadeAudio.playBlock(), returnsNormally);
      expect(() => ArcadeAudio.playBounce(), returnsNormally);
      expect(() => ArcadeAudio.playWhistle(), returnsNormally);
      expect(() => ArcadeAudio.playCrowdCheer(big: false), returnsNormally);
      expect(() => ArcadeAudio.playCrowdCheer(big: true), returnsNormally);
      expect(() => ArcadeAudio.playApplause(), returnsNormally);
      expect(() => ArcadeAudio.playStadiumHorn(), returnsNormally);
      expect(() => ArcadeAudio.playPointCheer(perfect: true), returnsNormally);
    });

    test('BGM lifecycle methods execute safely without throwing', () {
      expect(() => ArcadeAudio.startBgm(), returnsNormally);
      expect(() => ArcadeAudio.pauseBgm(), returnsNormally);
      expect(() => ArcadeAudio.resumeBgm(), returnsNormally);
      expect(() => ArcadeAudio.stopBgm(), returnsNormally);
    });
  });
}
