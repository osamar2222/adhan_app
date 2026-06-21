import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAdhanPlaying = false;
  String? _customAdhanPath;
  String _currentAdhanName = "";

  // Callback when user taps notification
  static void Function()? onAdhanStop;
  static void Function(String prayerName)? onAdhanStart;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const windowsSettings = WindowsInitializationSettings(
      // Windows uses toast notifications by default
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        // User tapped notification - stop adhan if playing
        if (_isAdhanPlaying) {
          await stopAdhan();
        }
      },
    );

    // Create notification channel with max importance (Android only)
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'prayer_channel',
        'مواقيت الصلاة',
        description: 'إشعارات أوقات الصلاة والأذان',
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        enableLights: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Create foreground service channel
      const fgChannel = AndroidNotificationChannel(
        'adhan_foreground',
        'تشغيل الأذان',
        description: 'خدمة تشغيل الأذان في الخلفية',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(fgChannel);
    }
  }

  set customAdhanPath(String? path) {
    _customAdhanPath = path;
  }

  String? get customAdhanPath => _customAdhanPath;

  bool get isAdhanPlaying => _isAdhanPlaying;

  Future<void> showPrayerNotification({
    required int id,
    required String prayerName,
    String? customAdhanPath,
  }) async {
    _customAdhanPath = customAdhanPath;
    _currentAdhanName = prayerName;

    // Android-specific notification details
    const androidDetails = AndroidNotificationDetails(
      'prayer_channel',
      'مواقيت الصلاة',
      channelDescription: 'إشعارات أوقات الصلاة والأذان',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      showWhen: true,
      usesChronometer: true,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const windowsDetails = WindowsNotificationDetails(
      // Windows toast notification settings
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      windows: windowsDetails,
    );

    await _notifications.show(
      id,
      '🕌 حان الآن موعد صلاة $prayerName',
      'اضغط لإيقاف الأذان',
      details,
    );

    // Play adhan
    await _playAdhan(prayerName);
  }

  Future<void> _playAdhan(String prayerName) async {
    _isAdhanPlaying = true;
    onAdhanStart?.call(prayerName);

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
      await stopAdhan();
    });
  }

  Future<void> stopAdhan() async {
    await _audioPlayer.stop();
    _isAdhanPlaying = false;
    onAdhanStop?.call();
  }

  /// Cancel a specific prayer notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
