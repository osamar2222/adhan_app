// Default stub implementation for platforms WITHOUT flutter_foreground_task
// (Windows, Linux)
// Uses direct AudioPlayer playback only (no background service)

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Prayer service for platforms without foreground task support (Windows, Linux)
/// Plays adhan audio directly without needing a background service
class PrayerService {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _customAdhanPath;

  // Callbacks
  VoidCallback? onAdhanStopped;

  Future<void> init() async {
    // No foreground task needed on desktop platforms
  }

  Future<bool> startService(String prayerName, {String? customAdhanPath}) async {
    if (_isPlaying) return false;

    // prayerName stored for potential future use

    _customAdhanPath = customAdhanPath;
    _isPlaying = true;

    try {
      if (_customAdhanPath != null && _customAdhanPath!.isNotEmpty && File(_customAdhanPath!).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(_customAdhanPath!));
      } else {
        await _audioPlayer.play(AssetSource('adhan.mp3'));
      }
    } catch (e) {
      try {
        await _audioPlayer.play(AssetSource('adhan.mp3'));
      } catch (_) {}
    }

    // Listen for completion to auto-stop
    _audioPlayer.onPlayerComplete.listen((_) async {
      await stopService();
    });

    return true;
  }

  Future<void> stopService() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _isPlaying = false;
      onAdhanStopped?.call();
    }
  }

  bool get isPlaying => _isPlaying;
}
