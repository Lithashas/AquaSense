import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';
import 'sensor_card.dart';

class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({super.key});

  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> {
  int _selectedIndex = 0;
  String _selectedMetric = 'Overview';

  void _openReports(String metric) {
    setState(() {
      _selectedIndex = 2;
      _selectedMetric = metric;
    });
  }

  static const List<BottomNavigationBarItem> _items = [
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.wifi_tethering_rounded),
      label: 'Connectivity',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_rounded),
      label: 'Reports',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onMetricSelected: _openReports),
      const DeviceConnectivityScreen(),
      ReportsScreen(selectedMetric: _selectedMetric),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF087F8C),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: _items,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final void Function(String metric) onMetricSelected;

  const DashboardScreen({super.key, required this.onMetricSelected});

  double _calculateWqi(double pH, double tds, double turbidity, double temp) {
    final pHScore = (100 - (pH - 7.0).abs() * 35).clamp(0.0, 100.0);
    final tdsScore = (100 - ((tds - 500).abs() / 500) * 100).clamp(0.0, 100.0);
    final turbidityScore = (100 - (turbidity * 4.5)).clamp(0.0, 100.0);
    final tempScore = (100 - (temp - 25.0).abs() * 6).clamp(0.0, 100.0);
    final average = (pHScore + tdsScore + turbidityScore + tempScore) / 4;
    return average;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WaterReading>(
      stream: FirebaseService.isConfigured
          ? FirebaseService.sensorData().map(
              (event) => WaterReading.fromSnapshot(event.snapshot),
            )
          : null,
      builder: (context, snapshot) {
        if (!FirebaseService.isConfigured) {
          return const _FirebaseMessage(
            message:
                'Firebase is not configured. Run flutterfire configure, then restart the app.',
            icon: Icons.settings_input_antenna_rounded,
          );
        }
        if (snapshot.hasError) {
          return const _FirebaseMessage(
            message: 'Unable to read live sensor data from Firebase.',
            icon: Icons.cloud_off_rounded,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reading = snapshot.data!;
        final wqi = _calculateWqi(
          reading.pH,
          reading.tds,
          reading.turbidity,
          reading.temperature,
        );
        final isGoodToUse = wqi >= 70;
        final statusColor = isGoodToUse ? Colors.green : Colors.orange;
        final statusText = isGoodToUse ? 'Good' : 'Needs attention';

        return Scaffold(
          backgroundColor: const Color(0xFFF1FBFC),
          appBar: AppBar(
            title: const Text('AquaSense Dashboard'),
            backgroundColor: const Color(0xFF073B4C),
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Reservoir Data',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${reading.online ? 'Device Online' : 'Device Offline'} (Battery: ${reading.battery.toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 14, color: Colors.green[700]),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                      GestureDetector(
                        onTap: () => onMetricSelected('pH'),
                        child: SensorCard(
                          title: 'pH Level',
                          value: reading.pH.toStringAsFixed(2),
                          unit: 'pH',
                          icon: Icons.science,
                          color: const Color(0xFF0B7285),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMetricSelected('TDS'),
                        child: SensorCard(
                          title: 'TDS',
                          value: reading.tds.toStringAsFixed(0),
                          unit: 'ppm',
                          icon: Icons.water_drop,
                          color: const Color(0xFF12B8C4),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMetricSelected('Turbidity'),
                        child: SensorCard(
                          title: 'Turbidity',
                          value: reading.turbidity.toStringAsFixed(1),
                          unit: 'NTU',
                          icon: Icons.blur_on,
                          color: const Color(0xFF087F8C),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMetricSelected('Temp'),
                        child: SensorCard(
                          title: 'Temp',
                          value: reading.temperature.toStringAsFixed(1),
                          unit: '°C',
                          icon: Icons.thermostat,
                          color: const Color(0xFF0F9D9A),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => onMetricSelected('WQI'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'WQI',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                wqi.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 10,
                                    width: 110,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  Container(
                                    height: 10,
                                    width: wqi.clamp(0.0, 100.0) / 100 * 110,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    isGoodToUse
                                        ? Icons.check_circle_rounded
                                        : Icons.warning_rounded,
                                    color: statusColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WaterReading {
  final double pH;
  final double tds;
  final double turbidity;
  final double temperature;
  final double battery;
  final bool online;

  const WaterReading({
    required this.pH,
    required this.tds,
    required this.turbidity,
    required this.temperature,
    required this.battery,
    required this.online,
  });

  factory WaterReading.fromSnapshot(DataSnapshot snapshot) {
    final data = snapshot.value;
    if (data is! Map) {
      throw const FormatException(
        'sensor_data must contain a map of sensor readings.',
      );
    }

    double number(String key, String alternateKey) {
      final value = data[key] ?? data[alternateKey];
      if (value == null) {
        throw FormatException('Missing sensor value: $key.');
      }
      if (value is num) return value.toDouble();
      return double.parse(value.toString());
    }

    bool boolean(String key, {bool defaultValue = false}) {
      final value = data[key];
      if (value == null) return defaultValue;
      if (value is bool) return value;
      return value.toString().toLowerCase() == 'true';
    }

    return WaterReading(
      pH: number('PH', 'pH'),
      tds: number('TDS', 'tds'),
      turbidity: number('Turbidity', 'turbidity'),
      temperature: number('Temp', 'temperature'),
      battery: number('Battery', 'battery'),
      online: boolean('online', defaultValue: true),
    );
  }
}

class _FirebaseMessage extends StatelessWidget {
  final String message;
  final IconData icon;

  const _FirebaseMessage({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class DeviceConnectivityScreen extends StatefulWidget {
  const DeviceConnectivityScreen({super.key});

  @override
  State<DeviceConnectivityScreen> createState() =>
      _DeviceConnectivityScreenState();
}

class _DeviceConnectivityScreenState extends State<DeviceConnectivityScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FBFC),
      appBar: AppBar(
        title: const Text(
          'Device Connectivity',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF073B4C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseService.isConfigured
            ? FirebaseService.connectivityData()
            : null,
        builder: (context, snapshot) {
          if (!FirebaseService.isConfigured || snapshot.hasError) {
            return const _FirebaseMessage(
              message: 'Unable to read circuit connectivity from Firebase.',
              icon: Icons.cloud_off_rounded,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final status = CircuitStatus.fromSnapshot(snapshot.data!.snapshot);
          final cards = [
            (
              'Sensor Status',
              status.sensorConnected ? 'Connected' : 'Not detected',
              status.sensorConnected ? 'Live sensor values received' : 'Check sensor wiring',
              Icons.sensors_rounded,
              status.sensorConnected ? Colors.green : Colors.red,
            ),
            (
              'Wi-Fi Connectivity',
              status.wifiConnected ? 'Connected' : 'Offline',
              status.wifiConnected ? 'Circuit is reporting to Firebase' : 'No circuit data received',
              Icons.wifi_rounded,
              status.wifiConnected ? Colors.blue : Colors.red,
            ),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...cards.map(
                (card) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: card.$5.withOpacity(0.16),
                      child: Icon(card.$4, color: card.$5),
                    ),
                    title: Text(card.$1),
                    subtitle: Text('${card.$2}\n${card.$3}'),
                    isThreeLine: true,
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BatteryUsageScreen(
                          batteryPercentage: status.battery,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.orange.withOpacity(0.16),
                          child: const Icon(
                            Icons.battery_charging_full_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Battery Pack',
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Realtime battery level',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.lastSeen == null
                    ? 'Sensor health is based on the latest values received.'
                    : 'Last seen: ${_formatLastSeen(status.lastSeen!)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatLastSeen(DateTime value) {
    final local = value.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$time, ${local.day}/${local.month}/${local.year}';
  }
}

class BatteryUsageScreen extends StatelessWidget {
  final double batteryPercentage;

  const BatteryUsageScreen({super.key, required this.batteryPercentage});

  @override
  Widget build(BuildContext context) {
    final used = batteryPercentage.clamp(0.0, 100.0).toDouble();
    final remaining = 100.0 - used;

    return Scaffold(
      backgroundColor: const Color(0xFFF1FBFC),
      appBar: AppBar(
        title: const Text('Battery Usage'),
        backgroundColor: const Color(0xFF073B4C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Battery Pack',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Realtime battery level',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 260,
                height: 260,
                child: CustomPaint(
                  painter: DeviceUsagePieChartPainter(
                    used: used,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _BatteryPercentageRow(
                color: Colors.orange,
                label: 'Used',
                percentage: used,
              ),
              const SizedBox(height: 16),
              _BatteryPercentageRow(
                color: Colors.grey.shade300,
                label: 'Remaining',
                percentage: remaining,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryPercentageRow extends StatelessWidget {
  final Color color;
  final String label;
  final double percentage;

  const _BatteryPercentageRow({
    required this.color,
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;

  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class DeviceUsagePieChartPainter extends CustomPainter {
  final double used;
  final Color color;

  const DeviceUsagePieChartPainter({required this.used, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final usedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final remaining = 100 - used;
    final usedAngle = (used / 100) * 2 * 3.141592653589793;

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.141592653589793 / 2,
      usedAngle,
      true,
      usedPaint,
    );

    final innerCircle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.55, innerCircle);

    final labelStyle = TextStyle(
      color: color,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(
      text: '${used.toStringAsFixed(0)}%',
      style: labelStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final annotationStyle = TextStyle(
      color: Colors.grey.shade700,
      fontSize: 11,
    );
    final annotationSpan = TextSpan(text: 'Used', style: annotationStyle);
    final annotationPainter = TextPainter(
      text: annotationSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    annotationPainter.paint(
      canvas,
      Offset(center.dx - annotationPainter.width / 2, center.dy + 22),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ReportsScreen extends StatefulWidget {
  final String selectedMetric;

  const ReportsScreen({super.key, this.selectedMetric = 'Overview'});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _viewMode = 'Daily';
  int _selectedMonthIndex = 1;
  late DateTime _selectedDate;
  late DateTime _selectedMonth;
  bool _alertShownForDate = false;

  _ReportsScreenState() {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedMonth = DateTime(now.year, now.month);
  }

  static const List<_MetricReport> _allMetrics = [
    _MetricReport(
      id: 'pH',
      title: 'pH Trend',
      unit: 'pH',
      color: Colors.purple,
      values: [6.8, 7.0, 7.1, 7.2, 7.3, 7.2, 7.1],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
      minValue: 0,
      maxValue: 14,
    ),
    _MetricReport(
      id: 'TDS',
      title: 'TDS Trend',
      unit: 'ppm',
      color: Colors.blue,
      values: [420, 440, 470, 450, 460, 430, 450],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
      minValue: 0,
      maxValue: 100,
    ),
    _MetricReport(
      id: 'Turbidity',
      title: 'Turbidity Trend',
      unit: 'NTU',
      color: Colors.brown,
      values: [15, 14, 12, 11, 13, 12, 12],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
      minValue: 0,
      maxValue: 100,
    ),
    _MetricReport(
      id: 'Temp',
      title: 'Temperature Trend',
      unit: '°C',
      color: Colors.orange,
      values: [26.5, 27.0, 28.1, 28.5, 29.0, 28.4, 28.5],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
      minValue: 0,
      maxValue: 40,
    ),
    _MetricReport(
      id: 'WQI',
      title: 'Water Quality Index Trend',
      unit: 'WQI',
      color: Colors.green,
      values: [70, 74, 76, 79, 81, 77, 77],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
      minValue: 0,
      maxValue: 100,
    ),
  ];

  static const List<String> _weekdays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];
  static const List<int> _dayNumbers = [22, 23, 24, 25, 26, 27, 28];
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  List<DateTime> _daysInSelectedMonth() {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    return List.generate(
      daysInMonth,
      (index) => DateTime(_selectedMonth.year, _selectedMonth.month, index + 1),
    );
  }

  List<HistoryReading> _readingsForDate(
    List<HistoryReading> readings,
    DateTime selectedDate,
  ) {
    return readings.where((reading) {
      final local = reading.timestamp.toLocal();
      return local.year == selectedDate.year &&
          local.month == selectedDate.month &&
          local.day == selectedDate.day;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      lastDate: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
      currentDate: _selectedDate,
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _selectedMonth = DateTime(picked.year, picked.month);
      _selectedMonthIndex = picked.month - 1;
      _alertShownForDate = false;
    });
  }

  Future<void> _showNoDataDialog(DateTime date) async {
    _alertShownForDate = true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No data recorded'),
        content: Text(
          'No data was recorded on ${_formatDate(date)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<double> _dailyValuesForMetric(
    _MetricReport metric,
    int selectedDayIndex,
    int monthIndex,
  ) {
    final base = metric.values;
    final dayAdjust = (selectedDayIndex + 1) * 0.18;
    final monthAdjust = (monthIndex + 1) * 0.35;

    return List.generate(base.length, (index) {
      final slotAdjust = index * 0.1;
      final metricAdjust = switch (metric.id) {
        'pH' => 0.12,
        'TDS' => 10.0,
        'Turbidity' => 1.6,
        'Temp' => 1.2,
        'WQI' => 3.0,
        _ => 0.0,
      };

      final value =
          base[index] + dayAdjust + monthAdjust + slotAdjust + metricAdjust;
      return switch (metric.id) {
        'pH' => value.clamp(6.0, 8.5).toDouble(),
        'TDS' => value.clamp(350.0, 520.0).toDouble(),
        'Turbidity' => value.clamp(5.0, 25.0).toDouble(),
        'Temp' => value.clamp(24.0, 34.0).toDouble(),
        'WQI' => value.clamp(55.0, 95.0).toDouble(),
        _ => value.toDouble(),
      };
    });
  }

  List<double> _monthlyValuesForMetric(_MetricReport metric, int monthIndex) {
    final daysInMonth = DateTime(DateTime.now().year, monthIndex + 2, 0).day;
    final base = metric.values;

    return List.generate(daysInMonth, (dayIndex) {
      final dayNumber = dayIndex + 1;
      final dailyWave = dayNumber * 0.18;
      final metricBias = switch (metric.id) {
        'pH' => 0.18,
        'TDS' => 8.0,
        'Turbidity' => 1.0,
        'Temp' => 0.8,
        'WQI' => 2.5,
        _ => 0.0,
      };
      final value =
          base[dayIndex % base.length] +
          dailyWave +
          (monthIndex * 1.6) +
          metricBias;
      return switch (metric.id) {
        'pH' => value.clamp(0.0, 14.0).toDouble(),
        'TDS' => value.clamp(0.0, 100.0).toDouble(),
        'Turbidity' => value.clamp(0.0, 100.0).toDouble(),
        'Temp' => value.clamp(0.0, 40.0).toDouble(),
        'WQI' => value.clamp(0.0, 100.0).toDouble(),
        _ => value.toDouble(),
      };
    });
  }

  List<_MetricReport> _buildMetricList() {
    final selectedReport = _allMetrics.firstWhere(
      (metric) => metric.id == widget.selectedMetric,
      orElse: () => _allMetrics.first,
    );

    final metrics = widget.selectedMetric == 'Overview'
        ? _allMetrics
        : [
            selectedReport,
            ..._allMetrics.where((metric) => metric.id != selectedReport.id),
          ];

    if (_viewMode == 'Monthly') {
      final daysInMonth = DateTime(
        DateTime.now().year,
        _selectedMonthIndex + 2,
        0,
      ).day;
      final monthlyLabels = List.generate(daysInMonth, (index) => (index + 1).toString());
      return metrics.map((metric) {
        return _MetricReport(
          id: metric.id,
          title: metric.title,
          unit: metric.unit,
          color: metric.color,
          values: _monthlyValuesForMetric(metric, _selectedMonthIndex),
          labels: monthlyLabels,
          minValue: metric.minValue,
          maxValue: metric.maxValue,
        );
      }).toList();
    }

    final selectedDayValue = (_selectedDate.day - 1).clamp(0, _dayNumbers.length - 1);
    final dailyLabels = ['00:00', '06:00', '12:00', '18:00', '00:00'];
    return metrics.map((metric) {
      return _MetricReport(
        id: metric.id,
        title: metric.title,
        unit: metric.unit,
        color: metric.color,
        values: _dailyValuesForMetric(
          metric,
          selectedDayValue,
          _selectedMonthIndex,
        ),
        labels: dailyLabels,
        minValue: metric.minValue,
        maxValue: metric.maxValue,
      );
    }).toList();
  }

  List<_MetricReport> _buildHistoryMetricList(List<HistoryReading> readings) {
    final selectedReport = _allMetrics.firstWhere(
      (metric) => metric.id == widget.selectedMetric,
      orElse: () => _allMetrics.first,
    );
    final metricOrder = widget.selectedMetric == 'Overview'
        ? _allMetrics
        : [
            selectedReport,
            ..._allMetrics.where((metric) => metric.id != selectedReport.id),
          ];

    if (_viewMode == 'Monthly') {
      final monthReadings = readings.where((reading) {
        final local = reading.timestamp.toLocal();
        return local.year == _selectedMonth.year &&
            local.month == _selectedMonth.month;
      }).toList();
      final daysInMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      ).day;

      double wqi(HistoryReading reading) {
        final pHScore = (100 - (reading.pH - 7.0).abs() * 35).clamp(0.0, 100.0);
        final tdsScore =
            (100 - ((reading.tds - 500).abs() / 500) * 100).clamp(0.0, 100.0);
        final turbidityScore =
            (100 - (reading.turbidity * 4.5)).clamp(0.0, 100.0);
        final tempScore =
            (100 - (reading.temperature - 25.0).abs() * 6).clamp(0.0, 100.0);
        return (pHScore + tdsScore + turbidityScore + tempScore) / 4;
      }

      return metricOrder.map((metric) {
        final dailyTotals = <int, double>{};
        final dailyCounts = <int, int>{};

        for (final reading in monthReadings) {
          final day = reading.timestamp.toLocal().day;
          final value = switch (metric.id) {
            'pH' => reading.pH,
            'TDS' => reading.tds,
            'Turbidity' => reading.turbidity,
            'Temp' => reading.temperature,
            'WQI' => wqi(reading),
            _ => 0.0,
          };
          dailyTotals[day] = (dailyTotals[day] ?? 0.0) + value;
          dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;
        }

        final values = List.generate(daysInMonth, (index) {
          final day = index + 1;
          final count = dailyCounts[day] ?? 0;
          if (count == 0) return 0.0;
          return (dailyTotals[day] ?? 0.0) / count;
        });
        final labels = List.generate(daysInMonth, (index) => '${index + 1}');

        return _MetricReport(
          id: metric.id,
          title: metric.title,
          unit: metric.unit,
          color: metric.color,
          values: values,
          labels: labels,
          minValue: metric.minValue,
          maxValue: metric.maxValue,
        );
      }).toList();
    }

    final points = readings.length > 30
        ? readings.sublist(readings.length - 30)
        : readings;

    double wqi(HistoryReading reading) {
      final pHScore = (100 - (reading.pH - 7.0).abs() * 35).clamp(0.0, 100.0);
      final tdsScore =
          (100 - ((reading.tds - 500).abs() / 500) * 100).clamp(0.0, 100.0);
      final turbidityScore =
          (100 - (reading.turbidity * 4.5)).clamp(0.0, 100.0);
      final tempScore =
          (100 - (reading.temperature - 25.0).abs() * 6).clamp(0.0, 100.0);
      return (pHScore + tdsScore + turbidityScore + tempScore) / 4;
    }

    return metricOrder.map((metric) {
      final values = points.map((reading) {
        return switch (metric.id) {
          'pH' => reading.pH,
          'TDS' => reading.tds,
          'Turbidity' => reading.turbidity,
          'Temp' => reading.temperature,
          'WQI' => wqi(reading),
          _ => 0.0,
        };
      }).toList();
      final labels = points.map((reading) {
        final time = reading.timestamp.toLocal();
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }).toList();
      return _MetricReport(
        id: metric.id,
        title: metric.title,
        unit: metric.unit,
        color: metric.color,
        values: values,
        labels: labels,
        minValue: metric.minValue,
        maxValue: metric.maxValue,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FBFC),
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF073B4C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<HistoryReading>>(
        stream: FirebaseService.isConfigured
            ? FirebaseService.sensorHistory()
            : null,
        builder: (context, snapshot) {
          if (!FirebaseService.isConfigured) {
            return const _FirebaseMessage(
              message:
                  'Firebase is not configured. Run flutterfire configure, then restart the app.',
              icon: Icons.settings_input_antenna_rounded,
            );
          }
          if (snapshot.hasError) {
            return const _FirebaseMessage(
              message:
                  'Unable to read sensorHistory from Firebase. Check database rules.',
              icon: Icons.cloud_off_rounded,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final historyReadings = snapshot.data!;
          final selectedReadings = _readingsForDate(historyReadings, _selectedDate);

          if (_viewMode == 'Daily' &&
              historyReadings.isNotEmpty &&
              selectedReadings.isEmpty &&
              !_alertShownForDate) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNoDataDialog(_selectedDate);
            });
          }

          final hasHistory = historyReadings.isNotEmpty;
            final selectedMonthReadings = historyReadings.where((reading) {
            final local = reading.timestamp.toLocal();
            return local.year == _selectedMonth.year &&
              local.month == _selectedMonth.month;
            }).toList();
          final metrics = hasHistory
              ? (_viewMode == 'Monthly'
                  ? _buildHistoryMetricList(historyReadings)
                  : (selectedReadings.isEmpty
                      ? _buildHistoryMetricList(const [])
                      : _buildHistoryMetricList(selectedReadings)))
              : _buildMetricList();
          final selectedDateText = hasHistory
              ? 'Firebase history'
              : 'Sample trends - no history yet';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                if (!hasHistory)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Charts show sample values until readings are saved under /sensorHistory.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasHistory ? _formatDate(_selectedDate) : selectedDateText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _pickDate,
                                tooltip: 'Select date',
                                icon: const Icon(Icons.calendar_month_rounded),
                              ),
                              IconButton(
                                onPressed: () {
                                  if (_viewMode == 'Daily') {
                                    final monthDays = _daysInSelectedMonth();
                                    final currentIndex = monthDays.indexWhere(
                                      (date) =>
                                          date.year == _selectedDate.year &&
                                          date.month == _selectedDate.month &&
                                          date.day == _selectedDate.day,
                                    );
                                    final nextIndex = (currentIndex - 1).clamp(
                                      0,
                                      monthDays.length - 1,
                                    );
                                    setState(() {
                                      _selectedDate = monthDays[nextIndex];
                                      _alertShownForDate = false;
                                    });
                                  } else {
                                    setState(() {
                                      _selectedMonthIndex =
                                          (_selectedMonthIndex - 1).clamp(0, _months.length - 1);
                                      _selectedMonth = DateTime(
                                        DateTime.now().year,
                                        _selectedMonthIndex + 1,
                                      );
                                      _selectedDate = DateTime(
                                        _selectedMonth.year,
                                        _selectedMonth.month,
                                        1,
                                      );
                                      _alertShownForDate = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.chevron_left),
                                splashRadius: 18,
                              ),
                              IconButton(
                                onPressed: () {
                                  if (_viewMode == 'Daily') {
                                    final monthDays = _daysInSelectedMonth();
                                    final currentIndex = monthDays.indexWhere(
                                      (date) =>
                                          date.year == _selectedDate.year &&
                                          date.month == _selectedDate.month &&
                                          date.day == _selectedDate.day,
                                    );
                                    final nextIndex = (currentIndex + 1).clamp(
                                      0,
                                      monthDays.length - 1,
                                    );
                                    setState(() {
                                      _selectedDate = monthDays[nextIndex];
                                      _alertShownForDate = false;
                                    });
                                  } else {
                                    setState(() {
                                      _selectedMonthIndex =
                                          (_selectedMonthIndex + 1).clamp(0, _months.length - 1);
                                      _selectedMonth = DateTime(
                                        DateTime.now().year,
                                        _selectedMonthIndex + 1,
                                      );
                                      _selectedDate = DateTime(
                                        _selectedMonth.year,
                                        _selectedMonth.month,
                                        1,
                                      );
                                      _alertShownForDate = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.chevron_right),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _viewMode = 'Daily'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _viewMode == 'Daily'
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: _viewMode == 'Daily'
                                        ? [
                                            const BoxShadow(
                                              color: Color(0x0F000000),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: const Center(child: Text('Daily')),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _viewMode = 'Monthly'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _viewMode == 'Monthly'
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: _viewMode == 'Monthly'
                                        ? [
                                            const BoxShadow(
                                              color: Color(0x0F000000),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: const Center(child: Text('Monthly')),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_viewMode == 'Daily')
                        SizedBox(
                          height: 78,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _daysInSelectedMonth().length,
                            itemBuilder: (context, index) {
                              final date = _daysInSelectedMonth()[index];
                              final isSelected = date.year == _selectedDate.year &&
                                  date.month == _selectedDate.month &&
                                  date.day == _selectedDate.day;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDate = date;
                                    _alertShownForDate = false;
                                  });
                                },
                                child: Container(
                                  width: 62,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF7B4DE2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _weekdays[date.weekday % 7],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        SizedBox(
                          height: 78,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _months.length,
                            itemBuilder: (context, index) {
                              final isSelected = index == _selectedMonthIndex;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMonthIndex = index;
                                    _selectedMonth = DateTime(
                                      DateTime.now().year,
                                      index + 1,
                                    );
                                    _selectedDate = DateTime(
                                      _selectedMonth.year,
                                      _selectedMonth.month,
                                      1,
                                    );
                                    _alertShownForDate = false;
                                  });
                                },
                                child: Container(
                                  width: 74,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF7B4DE2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _months[index],
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_viewMode == 'Daily' && hasHistory && selectedReadings.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'No data was recorded on ${_formatDate(_selectedDate)}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  )
                else if (_viewMode == 'Monthly' && selectedMonthReadings.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'No data was recorded in ${_months[_selectedMonthIndex]} ${_selectedMonth.year}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  )
                else
                  for (final metric in metrics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _ReportCard(
                        title: metric.title,
                        subtitle: _viewMode == 'Daily'
                            ? 'Selected date: ${_selectedDate.day}'
                            : 'Selected month: ${_months[_selectedMonthIndex]}',
                        child: SizedBox(
                          height: 220,
                          width: 900,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 900,
                              child: CustomPaint(
                                painter: TrendChartPainter(
                                  values: metric.values,
                                  labels: metric.labels,
                                  color: metric.color,
                                  unit: metric.unit,
                                  minValue: metric.minValue,
                                  maxValue: metric.maxValue,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _MetricReport {
  final String id;
  final String title;
  final String unit;
  final Color color;
  final List<double> values;
  final List<String> labels;
  final double minValue;
  final double maxValue;

  const _MetricReport({
    required this.id,
    required this.title,
    required this.unit,
    required this.color,
    required this.values,
    required this.labels,
    required this.minValue,
    required this.maxValue,
  });
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class TrendChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String unit;
  final double minValue;
  final double maxValue;

  const TrendChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.unit,
    required this.minValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 52.0;
    const top = 42.0;
    const right = 20.0;
    const bottom = 34.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.5;

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.6), color.withOpacity(0.1)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final effectiveMin = values.isEmpty ? minValue : minValue;
    final effectiveMax = values.isEmpty ? maxValue : maxValue;
    final yRange = effectiveMax - effectiveMin;

    final tickCount = 4;
    for (int i = 0; i <= tickCount; i++) {
      final ratio = i / tickCount;
      final y = top + chartHeight * (1 - ratio);
      final value = effectiveMin + (yRange * ratio);

      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        axisPaint,
      );

      final labelText = value >= 100
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(value >= 10 ? 0 : 1);
      final labelPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(4, y - labelPainter.height / 2 - 6),
      );
    }

    final points = <Offset>[];
    if (values.isNotEmpty) {
      final pointSpacing = values.length > 1 ? values.length - 1 : 1;
      for (int i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? left + chartWidth / 2
            : left + (i / pointSpacing) * chartWidth;
        final normalized = ((values[i] - effectiveMin) / (yRange == 0 ? 1 : yRange));
        final y = top + chartHeight * (1 - normalized);
        points.add(Offset(x, y));
      }
    }

    canvas.drawLine(
      Offset(left, top),
      Offset(left, size.height - bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, size.height - bottom),
      Offset(size.width - right, size.height - bottom),
      axisPaint,
    );

    if (points.isNotEmpty) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      final fillPath = Path.from(path)
        ..lineTo(size.width - right, size.height - bottom)
        ..lineTo(left, size.height - bottom)
        ..close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    final textStyle = TextStyle(color: Colors.grey.shade600, fontSize: 10);
    final labelSpacing = labels.length > 1 ? labels.length - 1 : 1;
    for (int i = 0; i < labels.length; i++) {
      final x = labels.length == 1
          ? left + chartWidth / 2
          : left + (i / labelSpacing) * chartWidth;
      final label = labels[i];
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 22),
      );
    }

    final unitTextSpan = TextSpan(
      text: unit,
      style: const TextStyle(color: Colors.black54, fontSize: 10),
    );
    final unitPainter = TextPainter(
      text: unitTextSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    unitPainter.paint(canvas, Offset(8, 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
