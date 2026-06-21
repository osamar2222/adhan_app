import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/settings_screen.dart';
import 'screens/athkar_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  runApp(const AdhanApp());
}

class AdhanApp extends StatelessWidget {
  const AdhanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Cairo'),
      home: const AdhanHomePage(),
    );
  }
}

class AdhanHomePage extends StatefulWidget {
  const AdhanHomePage({super.key});

  @override
  State<AdhanHomePage> createState() => _AdhanHomePageState();
}

class _AdhanHomePageState extends State<AdhanHomePage> with WidgetsBindingObserver {
  String _currentCity = "جدة";
  PrayerTimes? _prayerTimes;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAdhanPlaying = false;
  String _currentAdhanName = "";
  String _timeLeft = "00:00:00";
  Timer? _timer;
  String _hijriDate = "";

  // إحداثيات افتراضية لمدينة جدة
  double _latitude = 21.5433;
  double _longitude = 39.1728;

  // مسار ملف الأذان المخصص (إذا اختاره المستخدم)
  String? _customAdhanPath;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettingsAndInit();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateUI());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes back
      _calculatePrayers();
    }
  }

  Future<void> _loadSettingsAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final useLocation = prefs.getBool('use_location') ?? true;
    final selectedCity = prefs.getString('selected_city') ?? 'جدة';
    _customAdhanPath = prefs.getString('custom_adhan_path');

    if (!useLocation && selectedCity.isNotEmpty) {
      // Use saved city coordinates
      final cityCoords = _getCityCoordinates(selectedCity);
      _latitude = cityCoords['lat']!;
      _longitude = cityCoords['lng']!;
      _currentCity = selectedCity;
    } else {
      await _getLocation();
    }

    await _notificationService.init();
    _notificationService.customAdhanPath = _customAdhanPath;

    // Set notification callbacks
    NotificationService.onAdhanStart = (prayerName) {
      if (mounted) {
        setState(() {
          _isAdhanPlaying = true;
          _currentAdhanName = prayerName;
        });
      }
    };

    NotificationService.onAdhanStop = () {
      if (mounted) {
        setState(() {
          _isAdhanPlaying = false;
        });
      }
    };

    _calculatePrayers();
  }

  Map<String, double> _getCityCoordinates(String city) {
    switch (city) {
      case 'مكة المكرمة': return {'lat': 21.4225, 'lng': 39.8262};
      case 'المدينة المنورة': return {'lat': 24.4672, 'lng': 39.6112};
      case 'الرياض': return {'lat': 24.7136, 'lng': 46.6753};
      case 'جدة': return {'lat': 21.5433, 'lng': 39.1728};
      case 'الدمام': return {'lat': 26.4207, 'lng': 50.0888};
      case 'تبوك': return {'lat': 28.3835, 'lng': 36.5662};
      case 'أبها': return {'lat': 18.2164, 'lng': 42.5053};
      case 'القصيم': return {'lat': 26.3261, 'lng': 43.9700};
      default: return {'lat': 21.5433, 'lng': 39.1728};
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _currentCity = "موقعك الحالي";
          });
        }
      }
    } catch (e) {
      // اعتماد الإحداثيات الافتراضية عند الخطأ
    }
  }

  void _calculatePrayers() {
    final coordinates = Coordinates(_latitude, _longitude);
    final params = CalculationMethod.umm_al_qura.getParameters();
    params.madhab = Madhab.shafi;

    final now = DateTime.now();
    final prayerTimes = PrayerTimes.today(coordinates, params);

    if (mounted) {
      setState(() {
        _prayerTimes = prayerTimes;
        _hijriDate = _getHijriDateString(now);
      });
    }
  }

  String _getHijriDateString(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return hijri.toFormat('dd MMMM yyyy');
  }

  DateTime _lastPrayerCalc = DateTime(2000);

  void _updateUI() {
    final now = DateTime.now();

    // Only recalculate prayers once per minute to avoid unnecessary work
    if (now.difference(_lastPrayerCalc).inMinutes >= 1) {
      _lastPrayerCalc = now;
      _calculatePrayers();
    }

    if (_prayerTimes == null) return;

    final nextPrayer = _prayerTimes!.nextPrayer();
    DateTime? nextPrayerTime = _prayerTimes!.timeForPrayer(nextPrayer);

    // If after Isha, nextPrayer() returns Prayer.none — compute time until tomorrow's Fajr
    if (nextPrayer == Prayer.none || nextPrayerTime == null) {
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final tomorrowParams = CalculationMethod.umm_al_qura.getParameters();
      tomorrowParams.madhab = Madhab.shafi;
      final tomorrowPrayerTimes = PrayerTimes(
        Coordinates(_latitude, _longitude),
        DateComponents.from(tomorrow),
        tomorrowParams,
      );
      nextPrayerTime = tomorrowPrayerTimes.fajr;
    }

    final difference = nextPrayerTime.difference(now);
    if (difference.isNegative) {
      if (mounted) {
        setState(() {
          _timeLeft = "00:00:00";
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = "${difference.inHours.toString().padLeft(2, '0')}:${(difference.inMinutes % 60).toString().padLeft(2, '0')}:${(difference.inSeconds % 60).toString().padLeft(2, '0')}";
        });
      }
    }

    final format = DateFormat('HH:mm');
    String nowStr = format.format(now);

    List<Prayer> prayersList = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
    for (var prayer in prayersList) {
      final prayerTime = _prayerTimes!.timeForPrayer(prayer);
      if (prayerTime != null && format.format(prayerTime) == nowStr && !_isAdhanPlaying) {
        _playAdhan(prayer);
      }
    }
  }

  Future<void> _playAdhan(Prayer prayer) async {
    if (_isAdhanPlaying) return;

    final prayerName = _getPrayerNameArabic(prayer);

    if (mounted) {
      setState(() {
        _isAdhanPlaying = true;
        _currentAdhanName = prayerName;
      });
    }

    // Show notification that will keep app alive in background
    await _notificationService.showPrayerNotification(
      id: prayer.index + 1,
      prayerName: prayerName,
      customAdhanPath: _customAdhanPath,
    );

    try {
      if (_customAdhanPath != null && _customAdhanPath!.isNotEmpty && File(_customAdhanPath!).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(_customAdhanPath!));
      } else {
        await _audioPlayer.play(AssetSource('adhan.mp3'));
      }
    } catch (e) {
      // Fallback to asset
      try {
        await _audioPlayer.play(AssetSource('adhan.mp3'));
      } catch (_) {}
    }
  }

  void _stopAdhan() {
    if (_isAdhanPlaying) {
      _audioPlayer.stop();
      _notificationService.stopAdhan();
      if (mounted) {
        setState(() {
          _isAdhanPlaying = false;
        });
      }
    }
  }

  void _openSettings() async {
    // Reload settings when returning from settings screen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    _loadSettingsAndInit();
  }

  void _openAthkar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AthkarScreen()),
    );
  }

  String _getPrayerNameArabic(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr: return "الفجر";
      case Prayer.dhuhr: return "الظهر";
      case Prayer.asr: return "العصر";
      case Prayer.maghrib: return "المغرب";
      case Prayer.isha: return "العشاء";
      default: return "الفجر";
    }
  }

  String _getNextPrayerName() {
    if (_prayerTimes == null) return "الفجر";
    final next = _prayerTimes!.nextPrayer();
    // After Isha, nextPrayer() returns Prayer.none — tomorrow's Fajr
    if (next == Prayer.none) return "الفجر";
    return _getPrayerNameArabic(next);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormatter = DateFormat('d MMMM yyyy', 'ar');
    String gregorianDate = dateFormatter.format(now);

    String dateStr = "الأحد\n$_hijriDate هـ\n$gregorianDate م";

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      body: GestureDetector(
        onTap: _stopAdhan,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Athkar button on the left
                          IconButton(
                            icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF1D2D20), size: 28),
                            onPressed: _openAthkar,
                            tooltip: "أذكار الصباح والمساء",
                          ),
                          const Column(
                            children: [
                              Text("مواقيت الصلاة", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1D2D20))),
                              Text("والأذان", style: TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                          // Settings gear on the right
                          IconButton(
                            icon: const Icon(Icons.settings, color: Color(0xFF1D2D20), size: 28),
                            onPressed: _openSettings,
                            tooltip: "الإعدادات",
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.amber, size: 18),
                          const SizedBox(width: 5),
                          Text(_currentCity, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(dateStr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 25),
                      const Text("الوقت المتبقي لصلاة", style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text(_getNextPrayerName(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EBE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_timeLeft, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF1D3D28), letterSpacing: 2)),
                      ),
                      const SizedBox(height: 25),
                      if (_prayerTimes != null) ...[
                        _buildPrayerRow("الفجر", _prayerTimes!.fajr),
                        _buildPrayerRow("الشروق", _prayerTimes!.sunrise),
                        _buildPrayerRow("الظهر", _prayerTimes!.dhuhr),
                        _buildPrayerRow("العصر", _prayerTimes!.asr),
                        _buildPrayerRow("المغرب", _prayerTimes!.maghrib),
                        _buildPrayerRow("العشاء", _prayerTimes!.isha),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            if (_isAdhanPlaying)
              Container(
                color: Colors.black.withOpacity(0.85),
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.volume_up, size: 100, color: Colors.amber),
                    const SizedBox(height: 30),
                    Text("أذان صلاة $_currentAdhanName", style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    const Text("حان الآن موعد الأذان حسب توقيتك المحلي", style: TextStyle(fontSize: 18, color: Colors.white70)),
                    const SizedBox(height: 80),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(30)),
                      child: const Text("المس الشاشة في أي مكان لإيقاف صوت الأذان", style: TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(String name, DateTime time) {
    String formattedTime = DateFormat('h:mm a').format(time);
    bool isNext = _getNextPrayerName() == name;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isNext ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isNext ? Border.all(color: Colors.amber, width: 1) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(fontSize: 18, fontWeight: isNext ? FontWeight.bold : FontWeight.normal)),
          Text(formattedTime, style: TextStyle(fontSize: 18, fontWeight: isNext ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}