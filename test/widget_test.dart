// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:aqua_sense/main.dart';

void main() {
  testWidgets('AquaSense splash screen transitions to app home', (WidgetTester tester) async {
    await tester.pumpWidget(const AquaSenseApp());

    expect(find.text('AquaSense'), findsOneWidget);
    expect(find.text('Smart Water Monitoring'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('AquaSense Dashboard'), findsOneWidget);
    expect(find.text('Live Reservoir Data'), findsOneWidget);
    expect(find.text('pH Level'), findsOneWidget);
    expect(find.text('TDS'), findsOneWidget);
    expect(find.text('Take Reading Now'), findsOneWidget);

    await tester.tap(find.text('Take Reading Now'));
    await tester.pump();

    expect(find.text('Manual reading requested from ESP32...'), findsOneWidget);
  });
}
