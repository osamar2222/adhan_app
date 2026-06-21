import 'package:flutter/material.dart';
import '../services/athkar_data.dart';

class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, int> _countersMorning = {};
  final Map<int, int> _countersEvening = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _resetCounters();
  }

  void _resetCounters() {
    for (int i = 0; i < AthkarData.morningAthkar.length; i++) {
      _countersMorning[i] = AthkarData.morningAthkar[i].count;
    }
    for (int i = 0; i < AthkarData.eveningAthkar.length; i++) {
      _countersEvening[i] = AthkarData.eveningAthkar[i].count;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      appBar: AppBar(
        title: const Text('الأذكار', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFE2EBE5),
        foregroundColor: const Color(0xFF1D2D20),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1D3D28),
          labelColor: const Color(0xFF1D3D28),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.wb_sunny), text: 'أذكار الصباح'),
            Tab(icon: Icon(Icons.nights_stay), text: 'أذكار المساء'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAthkarList(AthkarData.morningAthkar, _countersMorning, isMorning: true),
          _buildAthkarList(AthkarData.eveningAthkar, _countersEvening, isMorning: false),
        ],
      ),
    );
  }

  Widget _buildAthkarList(List<Zikr> athkar, Map<int, int> counters, {required bool isMorning}) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: athkar.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              isMorning
                  ? '🍃 أذكار الصباح - قال الله تعالى: {يَا أَيُّهَا الَّذِينَ آمَنُوا اذْكُرُوا اللَّهَ ذِكْراً كَثِيراً} (الأحزاب ٤١)'
                  : '🌙 أذكار المساء - قال رسول الله ﷺ: "مَنْ قَالَ حِينَ يُمْسِي وَحِينَ يُصْبِحُ: رَضِيتُ بِاللَّهِ رَبًّا..."',
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
              textAlign: TextAlign.center,
            ),
          );
        }

        final zikrIndex = index - 1;
        final zikr = athkar[zikrIndex];
        final remaining = counters[zikrIndex] ?? zikr.count;
        final isCompleted = remaining <= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: isCompleted ? 0 : 2,
          color: isCompleted ? const Color(0xFFE8F5E9) : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              setState(() {
                if (remaining > 0) {
                  counters[zikrIndex] = remaining - 1;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text content
                  Container(
                    alignment: Alignment.centerRight,
                    child: Text(
                      zikr.text,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.8,
                        color: isCompleted ? Colors.green : Colors.black87,
                        fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Counter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : const Color(0xFFE2EBE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCompleted ? '✅ تم' : '🔄 $remaining / ${zikr.count}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? Colors.white : const Color(0xFF1D3D28),
                          ),
                        ),
                      ),
                      // Source
                      if (zikr.source.isNotEmpty)
                        Text(
                          zikr.source,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
