import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Lightweight offline audio player for pet companion sounds (purring, meowing).
/// Fully offline, non-blocking, and gracefully handles muted or headless environments.
class PetAudioService {
  static PetAudioService instance = PetAudioService._internal();
  PetAudioService._internal();

  PetAudioService.withPlayer(this._player);

  AudioPlayer? _player;
  bool isAudioAvailable = true;

  bool get _isHeadlessTest {
    if (kIsWeb) return false;
    return Platform.environment.containsKey('FLUTTER_TEST') && _player == null;
  }

  Future<void> playPurr() async {
    if (!isAudioAvailable || _isHeadlessTest) return;
    try {
      _player ??= AudioPlayer();
      await _player?.stop();
      await _player?.play(
        AssetSource('audio/pet/purr.mp3'),
        volume: 0.7,
      );
    } catch (_) {
      try {
        await _player?.play(
          AssetSource('audio/pet/purr.wav'),
          volume: 0.7,
        );
      } catch (_) {}
    }
  }

  final _random = math.Random();

  Future<void> playMeow({int? variant}) async {
    if (!isAudioAvailable || _isHeadlessTest) return;
    final int index = (variant == 1 || variant == 2) ? variant! : (_random.nextBool() ? 1 : 2);
    final soundFileMp3 = 'audio/pet/meow_$index.mp3';
    final soundFileWav = 'audio/pet/meow_$index.wav';

    try {
      _player ??= AudioPlayer();
      await _player?.stop();
      await _player?.play(
        AssetSource(soundFileMp3),
        volume: 0.6,
      );
    } catch (_) {
      try {
        await _player?.play(
          AssetSource(soundFileWav),
          volume: 0.6,
        );
      } catch (_) {
        try {
          await _player?.play(
            AssetSource('audio/pet/meow.mp3'),
            volume: 0.6,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> stop() async {
    if (_isHeadlessTest) return;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}

