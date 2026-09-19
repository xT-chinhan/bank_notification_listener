import 'package:flutter_test/flutter_test.dart';
import 'package:bank_notification_listener/main.dart';

void main() {
  testWidgets('MonitorScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BankNotificationApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that AppBar title and key UI elements appear
    expect(find.text('Bank Notification Monitor'), findsOneWidget);
    expect(find.text('Test Giả Lập Ngân Hàng'), findsOneWidget);
  });
}
