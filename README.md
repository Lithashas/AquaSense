# aqua_sense

Flutter dashboard for live water-quality readings from Firebase Realtime Database.

## Firebase setup

1. Create a Firebase project and enable Realtime Database.
2. Install the FlutterFire CLI, then run `flutterfire configure` from this folder. Select Android and iOS. This adds the platform Firebase config files required by `Firebase.initializeApp()`.
3. Add this object at the database path `/sensorData` (or publish the same fields from the ESP32):

```json
{
	"pH": 7.2,
	"tds": 450,
	"turbidity": 12,
	"temperature": 28.5,
	"battery": 85,
	"online": true
}
```

The dashboard listens to `/sensorData` with a realtime stream, so incoming writes appear without a refresh. Configure Realtime Database security rules for the app before production use.

## Interval history

Reports retrieve timestamped records from `/sensorHistory` and update whenever Firebase changes. Store one child per reading using a millisecond timestamp key:

```json
{
	"sensorHistory": {
		"1735689600000": {
			"timestamp": 1735689600000,
			"pH": 7.2,
			"tds": 450,
			"turbidity": 12,
			"temperature": 28.5
		}
	}
}
```

The ESP32, Cloud Function, or other writer must create these history records at the desired interval. The Flutter app only retrieves them; it cannot recover historical values that were never saved.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
