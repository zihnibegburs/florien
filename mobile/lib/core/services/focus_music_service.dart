import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusMusicTrack {
  const FocusMusicTrack({
    required this.id,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String assetPath;
}

abstract final class FocusMusicMenuValue {
  static const none = 'music:none';
  static const autoPlayOn = 'autoplay:on';
  static const autoPlayOff = 'autoplay:off';

  static String track(String id) => 'music:$id';
}

const focusMusicTracks = <FocusMusicTrack>[
  FocusMusicTrack(
    id: 'gece-akisi',
    title: 'Gece Akışı',
    assetPath: 'assets/focus_music/01-gece-akisi.m4a',
  ),
  FocusMusicTrack(
    id: 'gun-isigi',
    title: 'Gün Işığı',
    assetPath: 'assets/focus_music/02-gun-isigi.m4a',
  ),
  FocusMusicTrack(
    id: 'sessiz-odak',
    title: 'Sessiz Odak',
    assetPath: 'assets/focus_music/03-sessiz-odak.m4a',
  ),
  FocusMusicTrack(
    id: 'hizli-baslangic',
    title: 'Hızlı Başlangıç',
    assetPath: 'assets/focus_music/04-hizli-baslangic.m4a',
  ),
  FocusMusicTrack(
    id: 'derin-akis',
    title: 'Derin Akış',
    assetPath: 'assets/focus_music/05-derin-akis.m4a',
  ),
  FocusMusicTrack(
    id: 'kafa-toparlama',
    title: 'Kafa Toparlama',
    assetPath: 'assets/focus_music/06-kafa-toparlama.m4a',
  ),
];

/// Owns the focus audio player so music survives Focus UI dispose / reopen
/// (back navigation, Dynamic Island, home widget).
class FocusMusicService {
  FocusMusicService() {
    unawaited(_player.setLoopMode(LoopMode.one));
    unawaited(_player.setVolume(.58));
  }

  static const _selectedMusicPreferenceKey = 'focus_timer_selected_music';
  static const _musicAutoPlayPreferenceKey = 'focus_timer_music_auto_play';

  final AudioPlayer _player = AudioPlayer();
  FocusMusicTrack? selectedTrack;
  bool autoPlay = false;
  bool activeForSession = false;
  String? _loadedMusicId;
  bool _settingsLoaded = false;
  Future<void>? _settingsFuture;

  bool get isPlaying => _player.playing;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> ensureSettingsLoaded() {
    final inFlight = _settingsFuture;
    if (_settingsLoaded) return Future.value();
    if (inFlight != null) return inFlight;
    final future = _restoreSettings();
    _settingsFuture = future;
    return future;
  }

  Future<void> _restoreSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final selectedId = preferences.getString(_selectedMusicPreferenceKey);
    selectedTrack = focusMusicTracks
        .where((track) => track.id == selectedId)
        .firstOrNull;
    autoPlay = preferences.getBool(_musicAutoPlayPreferenceKey) ?? false;
    _settingsLoaded = true;
  }

  Future<void> persistSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final selectedId = selectedTrack?.id;
    if (selectedId == null) {
      await preferences.remove(_selectedMusicPreferenceKey);
    } else {
      await preferences.setString(_selectedMusicPreferenceKey, selectedId);
    }
    await preferences.setBool(_musicAutoPlayPreferenceKey, autoPlay);
  }

  Future<void> clearSelection() async {
    selectedTrack = null;
    _loadedMusicId = null;
    activeForSession = false;
    await stop();
    await persistSettings();
  }

  Future<void> setAutoPlay(bool enabled, {required bool timerRunning}) async {
    autoPlay = enabled;
    if (enabled && timerRunning && selectedTrack != null) {
      activeForSession = true;
      await play(showError: true);
    } else if (!enabled && activeForSession) {
      activeForSession = false;
      await pause();
    }
    await persistSettings();
  }

  Future<void> selectTrack(
    FocusMusicTrack track, {
    required bool sessionActive,
    required bool timerRunning,
  }) async {
    selectedTrack = track;
    _loadedMusicId = null;
    if (sessionActive) activeForSession = true;
    await persistSettings();
    if (timerRunning) await play(showError: true);
  }

  /// Called when a focus session starts or resumes.
  Future<void> onSessionRunning({required bool startingNewSession}) async {
    await ensureSettingsLoaded();
    if (isPlaying || activeForSession) {
      // Keep music that was already active across Focus UI dispose/reopen.
      activeForSession = true;
    } else if (startingNewSession) {
      activeForSession = autoPlay && selectedTrack != null;
    }
    if (activeForSession) await play();
  }

  Future<void> onTimerPaused() async {
    if (activeForSession) await pause();
  }

  Future<void> onTimerResumed() async {
    if (activeForSession) await play();
  }

  Future<void> endSession() async {
    activeForSession = false;
    await stop();
  }

  Future<void> togglePlayback({required bool sessionActive}) async {
    await ensureSettingsLoaded();
    if (selectedTrack == null) {
      final first = focusMusicTracks.firstOrNull;
      if (first == null) return;
      await selectTrack(
        first,
        sessionActive: sessionActive,
        timerRunning: true,
      );
      return;
    }
    if (isPlaying) {
      activeForSession = false;
      await pause();
      return;
    }
    activeForSession = true;
    await play(showError: true);
  }

  Future<void> _prepareSelectedMusic() async {
    final selected = selectedTrack;
    if (selected == null || _loadedMusicId == selected.id) return;
    await _player.setAsset(selected.assetPath);
    await _player.setLoopMode(LoopMode.one);
    _loadedMusicId = selected.id;
  }

  Future<void> play({bool showError = false}) async {
    if (selectedTrack == null) return;
    try {
      final audioSession = await AudioSession.instance;
      await audioSession.configure(AudioSessionConfiguration.music());
      await _prepareSelectedMusic();
      unawaited(_player.play());
    } catch (error) {
      debugPrint('Focus music could not be played: $error');
      if (showError) rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (error) {
      debugPrint('Focus music could not be paused: $error');
    }
  }

  Future<void> stop() async {
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (error) {
      debugPrint('Focus music could not be stopped: $error');
    }
  }

  Future<void> dispose() async {
    activeForSession = false;
    await _player.dispose();
  }
}
