import 'package:flutter_test/flutter_test.dart';

import 'package:sklad_client/main.dart';

void main() {
  testWidgets('SkladApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SkladApp());
    expect(find.byType(SkladApp), findsOneWidget);
  });
}
