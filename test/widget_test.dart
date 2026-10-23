// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:gold_pawn_erp/main.dart';

void main() {
  testWidgets('Gold Pawn ERP app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GoldPawnERPApp());
    expect(find.byType(GoldPawnERPApp), findsOneWidget);
  });
}
