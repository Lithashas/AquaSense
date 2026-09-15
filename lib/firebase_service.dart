import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_options.dart';

class FirebaseService {
  static bool isConfigured = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isConfigured = true;
    } catch (_) {
      isConfigured = false;
    }
  }

  static Stream<DatabaseEvent> sensorData() {
    return FirebaseDatabase.instance.ref('sensor_data').onValue;
  }

  static Stream<DatabaseEvent> connectivityData() {
    return FirebaseDatabase.instance.ref().onValue;
  }

  static Stream<List<HistoryReading>> sensorHistory() {
    return FirebaseDatabase.instance.ref('sensorHistory').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <HistoryReading>[];

      final readings = <HistoryReading>[];
      for (final entry in value.entries) {
        if (entry.value is! Map) continue;
        try {
          readings.add(
            HistoryReading.fromMap(entry.key.toString(), entry.value as Map),
          );
        } catch (_) {
          // Ignore malformed history entries so one bad record does not break charts.
        }
      }

      readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return readings;
    });
  }
}

class CircuitStatus {
  final double battery;
  final bool sensorConnected;
  final bool wifiConnected;
  final DateTime? lastSeen;

  const CircuitStatus({
    required this.battery,
    required this.sensorConnected,
    required this.wifiConnected,
    required this.lastSeen,
  });

  factory CircuitStatus.fromSnapshot(DataSnapshot snapshot) {
    final root = snapshot.value;
    if (root is! Map) {
      return const CircuitStatus(
        battery: 0,
        sensorConnected: false,
        wifiConnected: false,
        lastSeen: null,
      );
    }

    final sensorData = root['sensor_data'];
    final calibrationData = root['calibration_data'];
    final hasSensorValues = sensorData is Map &&
        sensorData['Battery'] != null &&
        sensorData['PH'] != null &&
        sensorData['TDS'] != null &&
        sensorData['Temp'] != null &&
        sensorData['Turbidity'] != null;
    final rawLastSeen = calibrationData is Map
        ? calibrationData['last_seen'] ?? calibrationData['lastSeen']
        : null;
    final lastSeen = _parseTimestamp(rawLastSeen);
    final isFresh = lastSeen != null &&
        DateTime.now().difference(lastSeen).abs() <=
            const Duration(minutes: 2);
    final battery = sensorData is Map
        ? double.tryParse(sensorData['Battery']?.toString() ?? '') ?? 0
        : 0;

    return CircuitStatus(
      battery: battery.clamp(0, 100).toDouble(),
      sensorConnected: lastSeen == null ? hasSensorValues : hasSensorValues && isFresh,
      wifiConnected: lastSeen == null ? hasSensorValues : isFresh,
      lastSeen: lastSeen,
    );
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value is num) {
      final milliseconds = value < 100000000000
          ? value.toInt() * 1000
          : value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (value != null) return DateTime.tryParse(value.toString());
    return null;
  }
}

class HistoryReading {
  final DateTime timestamp;
  final double pH;
  final double tds;
  final double turbidity;
  final double temperature;

  const HistoryReading({
    required this.timestamp,
    required this.pH,
    required this.tds,
    required this.turbidity,
    required this.temperature,
  });

  factory HistoryReading.fromMap(String key, Map data) {
    final rawTimestamp = data['timestamp'] ?? key;
    final timestamp = rawTimestamp is num
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp.toInt())
        : DateTime.tryParse(rawTimestamp.toString());
    if (timestamp == null) {
      throw const FormatException('History reading has no valid timestamp.');
    }

    double number(String field) {
      final value = data[field];
      if (value is num) return value.toDouble();
      return double.parse(value.toString());
    }

    return HistoryReading(
      timestamp: timestamp,
      pH: number('pH'),
      tds: number('tds'),
      turbidity: number('turbidity'),
      temperature: number('temperature'),
    );
  }
}
