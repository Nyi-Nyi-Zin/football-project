import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betting_app/main.dart';

void main() {
  testWidgets('Betting app renders root widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BettingApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(BettingApp), findsOneWidget);
  });
}
