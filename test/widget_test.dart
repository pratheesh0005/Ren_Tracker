import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ren_tracker/shared/widgets/stat_card.dart';

void main() {
  testWidgets('StatCard renders label, value and icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Total Staff',
            value: '42',
            color: Colors.blue,
            icon: Icons.people,
          ),
        ),
      ),
    );

    expect(find.text('Total Staff'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.byIcon(Icons.people), findsOneWidget);
  });
}
