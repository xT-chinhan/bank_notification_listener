import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_notification_listener/models/parsed_transaction.dart';
import 'package:bank_notification_listener/services/mock_bank_samples.dart';
import 'package:bank_notification_listener/widgets/simulation_sheet.dart';
import 'package:bank_notification_listener/widgets/transaction_card.dart';
import 'package:bank_notification_listener/screens/monitor_screen.dart';

void main() {
  group('TransactionCard Widget Tests', () {
    testWidgets('renders non-bank raw notification correctly', (tester) async {
      final notif = MockBankSamples.facebookNotification;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(notification: notif),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Nguyễn Văn B đã thích ảnh của bạn.'), findsOneWidget);
      expect(find.text('THU NHẬP'), findsNothing);
      expect(find.text('CHI TIÊU'), findsNothing);
    });

    testWidgets('renders bank parsed credit transaction with green badge & tags',
        (tester) async {
      final notif = MockBankSamples.vietcombankCredit;
      const parsed = ParsedTransaction(
        id: 'tx_vcb_01',
        title: 'Vietcombank',
        amount: 200000,
        type: 'credit',
        timestamp: 1789442100000,
        category: 'Chuyển tiền',
        note: 'Nguyen Van A chuyen tien',
        accountNumber: '0123456789',
        balance: 5200000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(
              notification: notif,
              parsedTransaction: parsed,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Vietcombank'), findsOneWidget);
      expect(find.text('THU NHẬP'), findsOneWidget);
      expect(find.text('+ 200.000 đ'), findsOneWidget);
      expect(find.text('Chuyển tiền'), findsOneWidget);
      expect(find.text('TK: 0123456789'), findsOneWidget);
    });

    testWidgets('renders bank parsed debit transaction with CHI TIEU badge',
        (tester) async {
      final notif = MockBankSamples.mbbankDebit;
      const parsed = ParsedTransaction(
        id: 'tx_mb_01',
        title: 'MBBank',
        amount: 35000,
        type: 'debit',
        timestamp: 1789456815000,
        category: 'Ăn uống',
        note: 'Tra sua gong cha',
        accountNumber: '123456789999',
        balance: 12815000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(
              notification: notif,
              parsedTransaction: parsed,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MBBank'), findsOneWidget);
      expect(find.text('CHI TIÊU'), findsOneWidget);
      expect(find.text('- 35.000 đ'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
    });

    testWidgets('tapping TransactionCard opens detail dialog with JSON inspection',
        (tester) async {
      final notif = MockBankSamples.vietcombankCredit;
      const parsed = ParsedTransaction(
        id: 'tx_vcb_01',
        title: 'Vietcombank',
        amount: 200000,
        type: 'credit',
        timestamp: 1789442100000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(
              notification: notif,
              parsedTransaction: parsed,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap card
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Parsed Transaction'), findsOneWidget);
      expect(find.text('Raw Notification'), findsOneWidget);
      expect(find.text('Sao chép Parsed JSON'), findsOneWidget);
      expect(find.text('Sao chép Tất cả'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Parsed Transaction'), findsNothing);
    });
  });

  group('SimulationSheet Tests', () {
    testWidgets('renders all bank samples and filter tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimulationSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bộ Giả Lập Thông Báo'), findsOneWidget);
      expect(find.text('Bắn Tất Cả'), findsOneWidget);
      expect(find.textContaining('Tất cả'), findsOneWidget);
      expect(find.textContaining('Ngân hàng'), findsOneWidget);
      expect(find.textContaining('Khác'), findsOneWidget);
    });
  });

  group('MonitorScreen UI Tests', () {
    testWidgets('displays empty state and responds to filter toggle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MonitorScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Bank Notification Monitor'), findsOneWidget);
      expect(find.textContaining('Tất cả thông báo'), findsOneWidget);
      expect(find.textContaining('Chỉ ngân hàng'), findsOneWidget);
      expect(find.text('Test Giả Lập Ngân Hàng'), findsOneWidget);
      expect(find.text('Bấm Để Test Giả Lập'), findsOneWidget);

      // Toggle filter chip
      await tester.tap(find.textContaining('Chỉ ngân hàng'));
      await tester.pump();
      expect(find.text('Chưa có thông báo ngân hàng nào'), findsOneWidget);
    });
  });
}
