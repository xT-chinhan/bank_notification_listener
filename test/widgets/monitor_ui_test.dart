import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_notification_listener/models/parsed_transaction.dart';
import 'package:bank_notification_listener/models/raw_notification.dart';
import 'package:bank_notification_listener/screens/monitor_screen.dart';
import 'package:bank_notification_listener/widgets/transaction_card.dart';

void main() {
  group('TransactionCard Widget Tests', () {
    testWidgets('renders non-bank raw notification correctly', (tester) async {
      final notif = RawNotification(
        id: 'test_1',
        packageName: 'com.facebook.katana',
        title: 'Facebook',
        text: 'Nguyễn Văn B đã thích ảnh của bạn.',
        timestamp: 1789442000000,
        isBankNotification: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(
              notification: notif,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Nguyễn Văn B đã thích ảnh của bạn.'), findsOneWidget);
    });

    testWidgets('renders bank parsed credit transaction with green badge & tags',
        (tester) async {
      final notif = RawNotification(
        id: 'test_2',
        packageName: 'com.VCB',
        title: 'Vietcombank',
        text: 'TK 0123456789 +200,000VND...',
        timestamp: 1789442100000,
        isBankNotification: true,
      );

      final parsed = ParsedTransaction(
        id: 'tx_vcb_01',
        title: 'Vietcombank',
        amount: 200000,
        type: 'credit',
        timestamp: 1789442100000,
        accountNumber: '...6789',
        category: 'Chuyển tiền',
        note: 'Tien thu no',
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
      expect(find.textContaining('+ 200.000'), findsOneWidget);
      expect(find.text('TK ...6789'), findsOneWidget);
      expect(find.text('Tien thu no'), findsOneWidget);
      expect(find.text('Chuyển tiền'), findsOneWidget);
      expect(find.textContaining('5.200.000'), findsOneWidget);
    });

    testWidgets('renders bank parsed debit transaction with debit badge',
        (tester) async {
      final notif = RawNotification(
        id: 'test_3',
        packageName: 'com.mbmobile',
        title: 'MBBank',
        text: 'TK 123 -35,000VND ND: Tra sua',
        timestamp: 1789442200000,
        isBankNotification: true,
      );

      final parsed = ParsedTransaction(
        id: 'tx_mb_01',
        title: 'MBBank',
        amount: 35000,
        type: 'debit',
        timestamp: 1789442200000,
        category: 'Ăn uống',
        note: 'Tra sua gong cha',
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
      expect(find.textContaining('35.000'), findsOneWidget);
      expect(find.text('Tra sua gong cha'), findsOneWidget);
    });

    testWidgets('tapping TransactionCard opens detail sheet with JSON inspection',
        (tester) async {
      final notif = RawNotification(
        id: 'test_detail',
        packageName: 'com.VCB',
        title: 'Vietcombank',
        text: 'TK 0123 +200,000VND',
        timestamp: 1789442100000,
        isBankNotification: true,
      );

      final parsed = ParsedTransaction(
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

      // Detail sheet is open
      expect(find.text('Parsed Transaction (Schema App)'), findsOneWidget);
      expect(find.text('Raw Android Notification Payload'), findsOneWidget);
      expect(find.text('Sao chép JSON'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Parsed Transaction (Schema App)'), findsNothing);
    });
  });

  group('MonitorScreen UI Tests', () {
    testWidgets('displays Bank Monitor header, empty state, and opens settings sheet',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MonitorScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('chinhan-xT'), findsOneWidget);
      expect(find.text('Quản lý chi tiêu cá nhân'), findsOneWidget);
      expect(find.text('Đang chờ thông báo mới...'), findsOneWidget);

      // Tap Settings Button
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Settings Sheet is open
      expect(find.text('Cài Đặt & Quyền Hệ Thống'), findsOneWidget);
      expect(find.textContaining('Quyền Đọc Thông Báo'), findsOneWidget);
      expect(find.text('Mở Cài Đặt Hệ Thống Android'), findsOneWidget);
      expect(find.text('Kiểm Tra Lại Trạng Thái'), findsOneWidget);

      // Close Settings Sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Cài Đặt & Quyền Hệ Thống'), findsNothing);
    });
  });
}
