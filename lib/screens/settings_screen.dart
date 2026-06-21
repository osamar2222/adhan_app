import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _customAdhanPath;
  String _selectedCity = 'جدة';
  bool _useLocation = true;

  final List<Map<String, dynamic>> _cities = [
    {'name': 'مكة المكرمة', 'lat': 21.4225, 'lng': 39.8262},
    {'name': 'المدينة المنورة', 'lat': 24.4672, 'lng': 39.6112},
    {'name': 'الرياض', 'lat': 24.7136, 'lng': 46.6753},
    {'name': 'جدة', 'lat': 21.5433, 'lng': 39.1728},
    {'name': 'الدمام', 'lat': 26.4207, 'lng': 50.0888},
    {'name': 'تبوك', 'lat': 28.3835, 'lng': 36.5662},
    {'name': 'أبها', 'lat': 18.2164, 'lng': 42.5053},
    {'name': 'القصيم', 'lat': 26.3261, 'lng': 43.9700},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customAdhanPath = prefs.getString('custom_adhan_path');
      _useLocation = prefs.getBool('use_location') ?? true;
      _selectedCity = prefs.getString('selected_city') ?? 'جدة';
    });
  }

  Future<void> _saveAdhanPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('custom_adhan_path', path);
    } else {
      await prefs.remove('custom_adhan_path');
    }
  }

  Future<void> _saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_city', city);
    await prefs.setBool('use_location', false);
  }

  Future<void> _pickAdhanFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _customAdhanPath = result.files.single.path;
      });
      await _saveAdhanPath(result.files.single.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تغيير صوت الأذان بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefaultAdhan() async {
    setState(() {
      _customAdhanPath = null;
    });
    await _saveAdhanPath(null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔊 تم استعادة صوت الأذان الافتراضي'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFE2EBE5),
        foregroundColor: const Color(0xFF1D2D20),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // قسم صوت الأذان
          _buildSectionTitle('🔊 صوت الأذان'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.audio_file, color: Color(0xFF1D3D28)),
                  title: const Text('اختيار صوت أذان مخصص'),
                  subtitle: Text(
                    _customAdhanPath != null
                        ? '📁 تم اختيار ملف مخصص'
                        : 'استخدام الملف الافتراضي',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _pickAdhanFile,
                ),
                if (_customAdhanPath != null)
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.orange),
                    title: const Text('استعادة الصوت الافتراضي'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: _resetToDefaultAdhan,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // قسم الموقع
          _buildSectionTitle('📍 الموقع'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('استخدام الموقع الحالي'),
                  subtitle: const Text('تحديد الموقع تلقائياً لحساب أوقات الصلاة بدقة'),
                  value: _useLocation,
                  activeColor: const Color(0xFF1D3D28),
                  onChanged: (value) async {
                    setState(() => _useLocation = value);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('use_location', value);
                  },
                ),
                if (!_useLocation)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCity,
                      decoration: const InputDecoration(
                        labelText: 'اختر المدينة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      items: _cities.map<DropdownMenuItem<String>>((city) {
                        return DropdownMenuItem<String>(
                          value: city['name'] as String,
                          child: Text(city['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() => _selectedCity = value);
                          await _saveCity(value);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // معلومات التطبيق
          _buildSectionTitle('ℹ️ حول التطبيق'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: Color(0xFF1D3D28)),
                  title: Text('الإصدار'),
                  trailing: Text('2.0.0', style: TextStyle(color: Colors.grey)),
                ),
                Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.mosque, color: Color(0xFF1D3D28)),
                  title: Text('طريقة الحساب'),
                  trailing: Text('أم القرى', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1D2D20),
      ),
    );
  }
}
