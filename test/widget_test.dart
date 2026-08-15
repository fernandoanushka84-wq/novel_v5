import 'package:flutter_test/flutter_test.dart';

import 'package:novel_mobile_app/main.dart';

void main() {
  testWidgets('renders the main navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const InkittCloneApp());
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
  });
}
