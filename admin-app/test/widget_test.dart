import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_app/app.dart';

void main() {
  testWidgets('AdminApp renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));

    expect(find.text('管理后台'), findsOneWidget);
  });
}