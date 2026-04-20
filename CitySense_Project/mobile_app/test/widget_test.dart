import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/app.dart';

void main() {
  testWidgets('CitySense shell renders the main navigation labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CitySenseApp());

    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });
}
