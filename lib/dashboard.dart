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
        selectedItemColor: Colors.blue[800],
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

  Stream<WaterReading> _waterReadings() {
    return FirebaseService.sensorData().map(
      (event) => WaterReading.fromSnapshot(event.snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('AquaSense Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<WaterReading>(
        stream: FirebaseService.isConfigured ? _waterReadings() : null,
        builder: (context, snapshot) {
          if (!FirebaseService.isConfigured) {
            return const _FirebaseMessage(
              message:
                  'Firebase is not configured. Run flutterfire configure, then restart the app.',
              icon: Icons.settings_input_antenna_rounded,
            );
          }
          if (snapshot.hasError) {
            return _FirebaseMessage(
              message:
                  'Unable to read sensorData from Firebase. Check Firebase setup and database rules.',
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
          final statusColor = isGoodToUse ? Colors.green : Colors.red;
          final statusText = isGoodToUse ? 'Good to use' : 'Not suitable';

          return Padding(
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
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                    children: [
                      GestureDetector(
                        onTap: () => onMetricSelected('pH'),
                        child: SensorCard(
                          title: 'pH Level',
                          value: reading.pH.toStringAsFixed(2),
                          unit: 'pH',
                          icon: Icons.science,
                          color: Colors.purple,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMetricSelected('TDS'),
                        child: SensorCard(
                          title: 'TDS',
                          value: reading.tds.toStringAsFixed(0),
                          unit: 'ppm',
                          icon: Icons.water_drop,
                          color: Colors.blue,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMetricSelected('Turbidity'),
                        child: SensorCard(
                          title: 'Turbidity',
                          value: reading.turbidity.toStringAsFixed(1),
                          unit: 'NTU',
                          icon: Icons.blur_on,
                          color: Colors.brown,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onMetricSelected('Temp'),
                        child: SensorCard(
                          title: 'Temp',
                          value: reading.temperature.toStringAsFixed(1),
                          unit: '°C',
                          icon: Icons.thermostat,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Manual reading requested from ESP32...',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Take Reading Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Device Connectivity',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
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
            (
              'Battery Pack',
              '${status.battery.toStringAsFixed(0)}%',
              'Realtime battery level',
              Icons.battery_charging_full_rounded,
              Colors.orange,
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
    final annotationSpan = TextSpan(text: 'Usage', style: annotationStyle);
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
  int _selectedDayIndex = 2;
  int _selectedMonthIndex = 1;

  static const List<_MetricReport> _allMetrics = [
    _MetricReport(
      id: 'pH',
      title: 'pH Trend',
      unit: 'pH',
      color: Colors.purple,
      values: [6.8, 7.0, 7.1, 7.2, 7.3, 7.2, 7.1],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
    ),
    _MetricReport(
      id: 'TDS',
      title: 'TDS Trend',
      unit: 'ppm',
      color: Colors.blue,
      values: [420, 440, 470, 450, 460, 430, 450],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
    ),
    _MetricReport(
      id: 'Turbidity',
      title: 'Turbidity Trend',
      unit: 'NTU',
      color: Colors.brown,
      values: [15, 14, 12, 11, 13, 12, 12],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
    ),
    _MetricReport(
      id: 'Temp',
      title: 'Temperature Trend',
      unit: '°C',
      color: Colors.orange,
      values: [26.5, 27.0, 28.1, 28.5, 29.0, 28.4, 28.5],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
    ),
    _MetricReport(
      id: 'WQI',
      title: 'Water Quality Index Trend',
      unit: 'WQI',
      color: Colors.green,
      values: [70, 74, 76, 79, 81, 77, 77],
      labels: ['06:00', '08:00', '10:00', '12:00', '14:00', '16:00', '18:00'],
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
  ];

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
    final monthlyPattern = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0];

    return monthlyPattern.asMap().entries.map((entry) {
      final index = entry.key;
      final pos = entry.value;
      final metricBias = switch (metric.id) {
        'pH' => 0.2,
        'TDS' => 12.0,
        'Turbidity' => 1.8,
        'Temp' => 1.5,
        'WQI' => 4.0,
        _ => 0.0,
      };
      final value =
          metric.values[index % metric.values.length] +
          pos +
          (monthIndex * 1.8) +
          metricBias;
      return switch (metric.id) {
        'pH' => value.clamp(6.0, 8.5).toDouble(),
        'TDS' => value.clamp(350.0, 520.0).toDouble(),
        'Turbidity' => value.clamp(5.0, 25.0).toDouble(),
        'Temp' => value.clamp(24.0, 34.0).toDouble(),
        'WQI' => value.clamp(55.0, 95.0).toDouble(),
        _ => value.toDouble(),
      };
    }).toList();
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
      final monthlyLabels = ['01', '05', '10', '15', '20', '25', '30'];
      return metrics.map((metric) {
        return _MetricReport(
          id: metric.id,
          title: metric.title,
          unit: metric.unit,
          color: metric.color,
          values: _monthlyValuesForMetric(metric, _selectedMonthIndex),
          labels: monthlyLabels,
        );
      }).toList();
    }

    final dailyLabels = ['00:00', '06:00', '12:00', '18:00', '00:00'];
    return metrics.map((metric) {
      return _MetricReport(
        id: metric.id,
        title: metric.title,
        unit: metric.unit,
        color: metric.color,
        values: _dailyValuesForMetric(
          metric,
          _selectedDayIndex,
          _selectedMonthIndex,
        ),
        labels: dailyLabels,
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
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
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
          final hasHistory = snapshot.data!.isNotEmpty;
          final metrics = hasHistory
              ? _buildHistoryMetricList(snapshot.data!)
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
                            selectedDateText,
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
                            onPressed: () {
                              if (_viewMode == 'Daily') {
                                setState(
                                  () => _selectedDayIndex =
                                      (_selectedDayIndex - 1).clamp(
                                        0,
                                        _dayNumbers.length - 1,
                                      ),
                                );
                              } else {
                                setState(
                                  () => _selectedMonthIndex =
                                      (_selectedMonthIndex - 1).clamp(
                                        0,
                                        _months.length - 1,
                                      ),
                                );
                              }
                            },
                            icon: const Icon(Icons.chevron_left),
                            splashRadius: 18,
                          ),
                          IconButton(
                            onPressed: () {
                              if (_viewMode == 'Daily') {
                                setState(
                                  () => _selectedDayIndex =
                                      (_selectedDayIndex + 1).clamp(
                                        0,
                                        _dayNumbers.length - 1,
                                      ),
                                );
                              } else {
                                setState(
                                  () => _selectedMonthIndex =
                                      (_selectedMonthIndex + 1).clamp(
                                        0,
                                        _months.length - 1,
                                      ),
                                );
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
                    Row(
                      children: List.generate(_weekdays.length, (index) {
                        final isSelected = index == _selectedDayIndex;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDayIndex = index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF7B4DE2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _weekdays[index],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_dayNumbers[index]}',
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
                          ),
                        );
                      }),
                    )
                  else
                    Row(
                      children: List.generate(_months.length, (index) {
                        final isSelected = index == _selectedMonthIndex;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedMonthIndex = index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (final metric in metrics)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _ReportCard(
                  title: metric.title,
                  subtitle: _viewMode == 'Daily'
                      ? 'Selected date: ${_dayNumbers[_selectedDayIndex]}'
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

  const _MetricReport({
    required this.id,
    required this.title,
    required this.unit,
    required this.color,
    required this.values,
    required this.labels,
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

  const TrendChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const top = 20.0;
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

    final minValue = values.reduce((a, b) => a < b ? a : b) * 0.9;
    final maxValue = values.reduce((a, b) => a > b ? a : b) * 1.1;
    final yRange = maxValue - minValue;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = left + (i / (values.length - 1)) * chartWidth;
      final y =
          size.height -
          bottom -
          ((values[i] - minValue) / (yRange == 0 ? 1 : yRange)) * chartHeight;
      points.add(Offset(x, y));
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

    final textStyle = TextStyle(color: Colors.grey.shade600, fontSize: 10);
    for (int i = 0; i < labels.length; i++) {
      final x = left + (i / (labels.length - 1)) * chartWidth;
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
