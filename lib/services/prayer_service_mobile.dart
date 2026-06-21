// Mobile implementation for platforms WITH flutter_foreground_task
// (Android, iOS)
// Uses FlutterForegroundTask for background service playback

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Prayer service for mobile platforms (Android, iOS)
/// Uses foreground task to keep app alive in background during adhan playback
class PrayerService {
  static final PrayerService _instance = PrayerService._internal();
  factory PrayerService() => _instance;
  PrayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _customAdhanPath;
  String _prayerName = '';

  // Callbacks
  VoidCallback? onAdhanStopped;

  Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'adhan_foreground',
        channelName: 'تشغيل الأذان',
        channelDescription: 'يعمل في الخلفية لتشغيل الأذان في وقته',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        interval: 5000,
        autoRunOnBoot: true,
        allowWifiLock: true,
        allowWakeLock: true,
      ),
    );
  }

  Future<bool> startService(String prayerName, {String? customAdhanPath}) async {
    if (_isPlaying) return false;

    _prayerName = prayerName;
    _customAdhanPath = customAdhanPath;

    final hasPermission = await FlutterForegroundTask.checkPermission();
    if (!hasPermission) {
      await FlutterForegroundTask.requestPermission();
    }

    final result = await FlutterForegroundTask.startService(
      notificationTitle: '🕌 أذان صلاة $_prayerName',
      notificationText: 'اضغط لإيقاف الأذان',
      callback: _startCallback,
    );

    if (result is ServiceRequestSuccess) {
      _isPlaying = true;
      return true;
    }
    return false;
  }

  Future<void> stopService() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      await FlutterForegroundTask.stopService();
      _isPlaying = false;
      onAdhanStopped?.call();
    }
  }

  bool get isPlaying => _isPlaying;

  // This runs in a separate isolate for foreground task
  @pragma('vm:entry-point')
  static void _startCallback() {
    FlutterForegroundTask.setTaskHandler(PrayerTaskHandler());
  }
}

class PrayerTaskHandler extends TaskHandler {
  final AudioPlayer _audio = AudioPlayer();

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    final prefs = await FlutterForegroundTask.getData(key: 'customAdhanPath');
    final customPath = prefs?.toString();

    try {
      if (customPath != null && customPath.isNotEmpty && File(customPath).existsSync()) {
        await _audio.play(DeviceFileSource(customPath));
      } else {
        await _audio.play(AssetSource('adhan.mp3'));
      }
    } catch (_) {
      try {
        await _audio.play(AssetSource('adhan.mp3'));
      } catch (_) {}
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Called every interval - check if audio still playing
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    await _audio.stop();
    await _audio.dispose();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.stopService();
  }
}
