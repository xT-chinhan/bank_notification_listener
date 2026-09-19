import 'package:flutter_test/flutter_test.dart';
import 'package:bank_notification_listener/models/raw_notification.dart';
import 'package:bank_notification_listener/models/parsed_transaction.dart';
import 'package:bank_notification_listener/services/mock_bank_samples.dart';

void main() {
  group('RawNotification Model Tests', () {
    test('should correctly serialize toMap and deserialize fromMap', () {
      const notification = RawNotification(
        id: 'test-raw-01',
        packageName: 'com.VCB',
        title: 'Vietcombank',
        text: 'TK 0123456789 +200,000VND',
        subText: 'Biến động số dư',
        timestamp: 1789442100000,
        isBankNotification: true,
      );

      final map = notification.toMap();
      expect(map['id'], 'test-raw-01');
      expect(map['packageName'], 'com.VCB');
      expect(map['title'], 'Vietcombank');
      expect(map['text'], 'TK 0123456789 +200,000VND');
      expect(map['subText'], 'Biến động số dư');
      expect(map['timestamp'], 1789442100000);
      expect(map['isBankNotification'], true);

      final deserialized = RawNotification.fromMap(map);
      expect(deserialized, equals(notification));
      expect(deserialized.id, notification.id);
      expect(deserialized.packageName, notification.packageName);
      expect(deserialized.title, notification.title);
      expect(deserialized.text, notification.text);
      expect(deserialized.subText, notification.subText);
      expect(deserialized.timestamp, notification.timestamp);
      expect(deserialized.isBankNotification, notification.isBankNotification);
    });

    test('should correctly serialize toJson and deserialize fromJson', () {
      const notification = RawNotification(
        id: 'test-raw-json',
        packageName: 'com.mbmobile',
        title: 'MBBank',
        text: 'TK 123456789999 +2,500,000VND',
        subText: null,
        timestamp: 1789435800000,
        isBankNotification: true,
      );

      final jsonString = notification.toJson();
      final deserialized = RawNotification.fromJson(jsonString);

      expect(deserialized, equals(notification));
      expect(deserialized.subText, isNull);
    });

    test('should handle loose dynamic typing in fromMap', () {
      final dynamicMap = <dynamic, dynamic>{
        'id': 12345,
        'packageName': 'com.test.app',
        'title': 'Test App',
        'text': 'Test message',
        'subText': null,
        'timestamp': '1789435800000',
        'isBankNotification': 'true',
      };

      final parsed = RawNotification.fromMap(dynamicMap);
      expect(parsed.id, '12345');
      expect(parsed.packageName, 'com.test.app');
      expect(parsed.timestamp, 1789435800000);
      expect(parsed.isBankNotification, isTrue);
    });

    test('should copyWith properly', () {
      const original = RawNotification(
        id: 'orig-id',
        packageName: 'com.orig',
        title: 'Orig Title',
        text: 'Orig Text',
        timestamp: 1000,
        isBankNotification: false,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        isBankNotification: true,
      );

      expect(updated.id, 'orig-id');
      expect(updated.packageName, 'com.orig');
      expect(updated.title, 'Updated Title');
      expect(updated.text, 'Orig Text');
      expect(updated.timestamp, 1000);
      expect(updated.isBankNotification, true);
    });

    test('should support toString and hashCode', () {
      const n1 = RawNotification(
        id: '1',
        packageName: 'pkg',
        title: 'T',
        text: 'txt',
        timestamp: 1,
      );
      const n2 = RawNotification(
        id: '1',
        packageName: 'pkg',
        title: 'T',
        text: 'txt',
        timestamp: 1,
      );

      expect(n1.toString(), contains('RawNotification'));
      expect(n1.hashCode, equals(n2.hashCode));
    });
  });

  group('ParsedTransaction Model Tests', () {
    test('should correctly serialize toMap and deserialize fromMap', () {
      const tx = ParsedTransaction(
        id: 'uuid-1234-5678',
        title: 'Vietcombank',
        amount: 200000,
        type: 'credit',
        timestamp: 1789442100000,
        category: 'Chuyển tiền',
        note: 'Nguyen Van A chuyen tien',
        accountNumber: '...6789',
        balance: 5200000,
        rawContent: 'TK 0123456789 tai VCB +200,000VND...',
        confidence: 0.98,
      );

      final map = tx.toMap();
      expect(map['id'], 'uuid-1234-5678');
      expect(map['title'], 'Vietcombank');
      expect(map['amount'], 200000);
      expect(map['type'], 'credit');
      expect(map['timestamp'], 1789442100000);
      expect(map['category'], 'Chuyển tiền');
      expect(map['note'], 'Nguyen Van A chuyen tien');
      expect(map['accountNumber'], '...6789');
      expect(map['balance'], 5200000);
      expect(map['rawContent'], 'TK 0123456789 tai VCB +200,000VND...');
      expect(map['confidence'], 0.98);

      final deserialized = ParsedTransaction.fromMap(map);
      expect(deserialized, equals(tx));
      expect(deserialized.isCredit, isTrue);
      expect(deserialized.isDebit, isFalse);
    });

    test('should correctly serialize toJson and deserialize fromJson', () {
      const tx = ParsedTransaction(
        id: 'uuid-9876',
        title: 'MBBank',
        amount: 35000,
        type: 'debit',
        timestamp: 1789456815000,
        category: 'Ăn uống',
        note: 'Tra sua gong cha',
        accountNumber: '...9999',
        balance: 12815000,
        rawContent: 'Bien dong so du...',
        confidence: 0.95,
      );

      final jsonString = tx.toJson();
      final deserialized = ParsedTransaction.fromJson(jsonString);

      expect(deserialized, equals(tx));
      expect(deserialized.isDebit, isTrue);
      expect(deserialized.isCredit, isFalse);
    });

    test('should properly format formattedAmount with currency and sign', () {
      const creditTx = ParsedTransaction(
        id: 'credit-tx',
        title: 'Vietcombank',
        amount: 50000,
        type: 'credit',
        timestamp: 1789442100000,
      );

      const debitTx = ParsedTransaction(
        id: 'debit-tx',
        title: 'Techcombank',
        amount: 120000,
        type: 'debit',
        timestamp: 1789442100000,
      );

      // Verify credit formatted amount
      final creditFormatted = creditTx.formattedAmount;
      expect(creditFormatted.startsWith('+ '), isTrue);
      expect(creditFormatted.contains('50.000'), isTrue);
      expect(creditFormatted.endsWith('đ'), isTrue);

      // Verify debit formatted amount
      final debitFormatted = debitTx.formattedAmount;
      expect(debitFormatted.startsWith('- '), isTrue);
      expect(debitFormatted.contains('120.000'), isTrue);
      expect(debitFormatted.endsWith('đ'), isTrue);
    });

    test('should copyWith properly', () {
      const original = ParsedTransaction(
        id: 'tx-1',
        title: 'VPBank',
        amount: 45000,
        type: 'debit',
        timestamp: 1789533900000,
      );

      final updated = original.copyWith(
        category: 'Mua sắm',
        balance: 1230000,
        note: 'Nap tien dien thoai',
      );

      expect(updated.id, 'tx-1');
      expect(updated.title, 'VPBank');
      expect(updated.amount, 45000);
      expect(updated.category, 'Mua sắm');
      expect(updated.balance, 1230000);
      expect(updated.note, 'Nap tien dien thoai');
    });

    test('should support toString and hashCode', () {
      const t1 = ParsedTransaction(
        id: '1',
        title: 'ACB',
        amount: 100,
        type: 'debit',
        timestamp: 10,
      );
      const t2 = ParsedTransaction(
        id: '1',
        title: 'ACB',
        amount: 100,
        type: 'debit',
        timestamp: 10,
      );

      expect(t1.toString(), contains('ParsedTransaction'));
      expect(t1.hashCode, equals(t2.hashCode));
    });
  });

  group('MockBankSamples Tests', () {
    test('should contain at least 10 samples', () {
      expect(MockBankSamples.samples.length, greaterThanOrEqualTo(10));
      expect(MockBankSamples.samples.length, equals(12));
    });

    test('should have bank and non-bank samples separated correctly', () {
      final bankSamples = MockBankSamples.bankSamples;
      final nonBankSamples = MockBankSamples.nonBankSamples;

      expect(bankSamples.length, equals(11));
      expect(nonBankSamples.length, equals(1));
      expect(nonBankSamples.first.packageName, 'com.facebook.katana');
      expect(nonBankSamples.first.isBankNotification, isFalse);
    });

    test('should verify all specific required mock samples are present', () {
      // 1. Vietcombank credit (+200.000VND)
      expect(MockBankSamples.vietcombankCredit.packageName, 'com.VCB');
      expect(MockBankSamples.vietcombankCredit.text, contains('+200,000VND'));
      expect(MockBankSamples.vietcombankCredit.isBankNotification, isTrue);

      // 2. Vietcombank debit (-50.000VND)
      expect(MockBankSamples.vietcombankDebit.packageName, 'com.VCB');
      expect(MockBankSamples.vietcombankDebit.text, contains('-50,000VND'));
      expect(MockBankSamples.vietcombankDebit.isBankNotification, isTrue);

      // 3. MBBank credit (+2.500.000VND, ND: Luong thang 9)
      expect(MockBankSamples.mbbankCredit.packageName, 'com.mbmobile');
      expect(MockBankSamples.mbbankCredit.text, contains('+2,500,000VND'));
      expect(MockBankSamples.mbbankCredit.text, contains('Luong thang 9'));
      expect(MockBankSamples.mbbankCredit.isBankNotification, isTrue);

      // 4. MBBank debit (-35.000VND, ND: Tra sua gong cha)
      expect(MockBankSamples.mbbankDebit.packageName, 'com.mbmobile');
      expect(MockBankSamples.mbbankDebit.text, contains('-35,000VND'));
      expect(MockBankSamples.mbbankDebit.text, contains('Tra sua gong cha'));
      expect(MockBankSamples.mbbankDebit.isBankNotification, isTrue);

      // 5. Techcombank debit (-100.000 VND)
      expect(MockBankSamples.techcombankDebit.packageName, 'com.techcombank.bb.omb');
      expect(MockBankSamples.techcombankDebit.text, contains('-100,000 VND'));
      expect(MockBankSamples.techcombankDebit.isBankNotification, isTrue);

      // 6. VPBank debit (PS: -45.000VND)
      expect(MockBankSamples.vpbankDebit.packageName, 'com.vpb.vpbankonline');
      expect(MockBankSamples.vpbankDebit.text, contains('PS: -45,000VND'));
      expect(MockBankSamples.vpbankDebit.isBankNotification, isTrue);

      // 7. ACB debit (-120.000 VND)
      expect(MockBankSamples.acbDebit.packageName, 'mobile.acb.com.vn');
      expect(MockBankSamples.acbDebit.text, contains('120,000 VND'));
      expect(MockBankSamples.acbDebit.isBankNotification, isTrue);

      // 8. TPBank credit (+500.000 VND)
      expect(MockBankSamples.tpbankCredit.packageName, 'com.tpb.mb.gprsandroid');
      expect(MockBankSamples.tpbankCredit.text, contains('+500,000 VND'));
      expect(MockBankSamples.tpbankCredit.isBankNotification, isTrue);

      // 9. BIDV credit (+300.000 VND)
      expect(MockBankSamples.bidvCredit.packageName, 'com.vnpay.bidv');
      expect(MockBankSamples.bidvCredit.text, contains('+300,000 VND'));
      expect(MockBankSamples.bidvCredit.isBankNotification, isTrue);

      // 10. MoMo receive (+50.000đ từ Nguyễn Văn A)
      expect(MockBankSamples.momoReceive.packageName, 'com.mservice.momotransfer');
      expect(MockBankSamples.momoReceive.text, contains('+50.000đ'));
      expect(MockBankSamples.momoReceive.text, contains('Nguyễn Văn A'));
      expect(MockBankSamples.momoReceive.isBankNotification, isTrue);

      // 11. MoMo payment (-25.000đ tại Circle K)
      expect(MockBankSamples.momoPayment.packageName, 'com.mservice.momotransfer');
      expect(MockBankSamples.momoPayment.text, contains('-25.000đ'));
      expect(MockBankSamples.momoPayment.text, contains('Circle K'));
      expect(MockBankSamples.momoPayment.isBankNotification, isTrue);

      // 12. Non-bank notification (Facebook)
      expect(MockBankSamples.facebookNotification.packageName, 'com.facebook.katana');
      expect(MockBankSamples.facebookNotification.text, contains('Nguyễn Văn B đã thích ảnh của bạn'));
      expect(MockBankSamples.facebookNotification.isBankNotification, isFalse);
    });
  });
}
