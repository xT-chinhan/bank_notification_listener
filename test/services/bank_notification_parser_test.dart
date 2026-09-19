import 'package:flutter_test/flutter_test.dart';
import 'package:bank_notification_listener/models/raw_notification.dart';
import 'package:bank_notification_listener/services/bank_notification_parser.dart';
import 'package:bank_notification_listener/services/mock_bank_samples.dart';

void main() {
  group('BankNotificationParser - isBankApp', () {
    test('identifies known bank packages correctly', () {
      expect(
        BankNotificationParser.isBankApp('com.VCB', 'Notification', ''),
        isTrue,
      );
      expect(BankNotificationParser.isBankApp('com.mbmobile', '', ''), isTrue);
      expect(
        BankNotificationParser.isBankApp('com.techcombank.mobile', '', ''),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp('com.vnpay.vpbankonline', '', ''),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp('mobile.acb.com.vn', '', ''),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp('com.tpb.mb.gprsandroid', '', ''),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp('com.vnpay.bidv', '', ''),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp('com.mservice.momotransfer', '', ''),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp('vn.com.vng.zalopay', '', ''),
        isTrue,
      );
    });

    test('identifies bank apps by title and text keywords', () {
      expect(
        BankNotificationParser.isBankApp(
          'com.unknown.app',
          'Vietcombank',
          'Biến động số dư tài khoản',
        ),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp(
          'com.unknown.app',
          'Thông báo',
          'Giao dịch thanh toán thành công 50.000 đ',
        ),
        isTrue,
      );
      expect(
        BankNotificationParser.isBankApp(
          'com.unknown.app',
          'MBBank',
          'So du tai khoan thay doi',
        ),
        isTrue,
      );
    });

    test('rejects non-bank apps and regular chat notifications', () {
      expect(
        BankNotificationParser.isBankApp(
          'com.facebook.katana',
          'Facebook',
          'Nguyễn Văn A đã bình luận bài viết của bạn',
        ),
        isFalse,
      );
      expect(
        BankNotificationParser.isBankApp(
          'com.zing.zalo',
          'Zalo',
          'Bạn có tin nhắn mới từ Lan',
        ),
        isFalse,
      );
      expect(
        BankNotificationParser.isBankApp(
          'org.telegram.messenger',
          'Telegram',
          'Hello, are we meeting today?',
        ),
        isFalse,
      );
    });
  });

  group('BankNotificationParser - Bank Parsing Engine (12+ Real Cases)', () {
    // 1. Vietcombank Credit
    test('1. Vietcombank - Credit (+200.000 VND)', () {
      final tx = BankNotificationParser.parse(
        MockBankSamples.vietcombankCredit,
      );
      expect(tx, isNotNull);
      expect(tx!.title, 'Vietcombank');
      expect(tx.amount, 200000);
      expect(tx.type, 'credit');
      expect(tx.isCredit, isTrue);
      expect(tx.accountNumber, '0123456789');
      expect(tx.balance, 5200000);
      expect(tx.note, contains('Nguyen Van A chuyen tien'));
      expect(tx.category, 'Chuyển tiền');
    });

    // 2. Vietcombank Debit
    test('2. Vietcombank - Debit (-50.000 VND)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.vietcombankDebit);
      expect(tx, isNotNull);
      expect(tx!.title, 'Vietcombank');
      expect(tx.amount, 50000);
      expect(tx.type, 'debit');
      expect(tx.isDebit, isTrue);
      expect(tx.accountNumber, '0123456789');
      expect(tx.balance, 5000000);
      expect(tx.note, contains('Thanh toan hoa don internet'));
      expect(tx.category, 'Hóa đơn & Tiện ích');
    });

    // 3. MBBank Credit
    test('3. MBBank - Credit (+2.500.000 VND, Lương)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.mbbankCredit);
      expect(tx, isNotNull);
      expect(tx!.title, 'MBBank');
      expect(tx.amount, 2500000);
      expect(tx.type, 'credit');
      expect(tx.accountNumber, '123456789999');
      expect(tx.balance, 15350000);
      expect(tx.note, 'Luong thang 9');
      expect(tx.category, 'Lương');
    });

    // 4. MBBank Debit
    test('4. MBBank - Debit (-35.000 VND, Trà sữa)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.mbbankDebit);
      expect(tx, isNotNull);
      expect(tx!.title, 'MBBank');
      expect(tx.amount, 35000);
      expect(tx.type, 'debit');
      expect(tx.accountNumber, '123456789999');
      expect(tx.balance, 12815000);
      expect(tx.note, 'Tra sua gong cha');
      expect(tx.category, 'Ăn uống');
    });

    // 5. Techcombank Debit
    test('5. Techcombank - Debit (-100.000 VND, Circle K)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.techcombankDebit);
      expect(tx, isNotNull);
      expect(tx!.title, 'Techcombank');
      expect(tx.amount, 100000);
      expect(tx.type, 'debit');
      expect(tx.accountNumber, '...5678');
      expect(tx.balance, 3450000);
      expect(tx.note, 'Thanh toan QR');
      expect(tx.category, 'Mua sắm');
    });

    // 6. Techcombank Credit
    test('6. Techcombank - Credit (+3.000.000 VND, Thưởng KPI)', () {
      const notif = RawNotification(
        id: 'test_tcb_credit',
        packageName: 'com.techcombank.mobile',
        title: 'Techcombank',
        text:
            'TK 19031234567890 nhan duoc +3,000,000 VND luc 10:00 15/09/2026. So du: 8,000,000 VND. Noi dung: Thuong KPI thang 8',
        timestamp: 1789440000000,
        isBankNotification: true,
      );
      final tx = BankNotificationParser.parse(notif);
      expect(tx, isNotNull);
      expect(tx!.title, 'Techcombank');
      expect(tx.amount, 3000000);
      expect(tx.type, 'credit');
      expect(tx.balance, 8000000);
      expect(tx.note, 'Thuong KPI thang 8');
      expect(tx.category, 'Lương');
    });

    // 7. VPBank Debit
    test('7. VPBank - Debit (-45.000 VND, Nạp tiền điện thoại)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.vpbankDebit);
      expect(tx, isNotNull);
      expect(tx!.title, 'VPBank NEO');
      expect(tx.amount, 45000);
      expect(tx.type, 'debit');
      expect(tx.accountNumber, '123456789');
      expect(tx.balance, 1230000);
      expect(tx.note, 'Nap tien dien thoai');
      expect(tx.category, 'Hóa đơn & Tiện ích');
    });

    // 8. VPBank Credit
    test('8. VPBank - Credit (+1.200.000 VND)', () {
      const notif = RawNotification(
        id: 'test_vpb_credit',
        packageName: 'com.vpb.vpbankonline',
        title: 'VPBank',
        text:
            'TK 123456789: PS: +1,200,000VND lúc 17/09/2026. SD: 3,000,000VND. ND: Ban tra tien an toi',
        timestamp: 1789533900000,
        isBankNotification: true,
      );
      final tx = BankNotificationParser.parse(notif);
      expect(tx, isNotNull);
      expect(tx!.amount, 1200000);
      expect(tx.type, 'credit');
      expect(tx.balance, 3000000);
      expect(tx.note, 'Ban tra tien an toi');
      expect(tx.category, 'Ăn uống');
    });

    // 9. ACB Debit
    test('9. ACB - Debit (-120.000 VND, Ăn trưa)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.acbDebit);
      expect(tx, isNotNull);
      expect(tx!.title, 'ACB ONE');
      expect(tx.amount, 120000);
      expect(tx.type, 'debit');
      expect(tx.accountNumber, '987654321');
      expect(tx.balance, 4100000);
      expect(tx.note, 'An trua cung dong nghiep');
      expect(tx.category, 'Ăn uống');
    });

    // 10. ACB Credit
    test('10. ACB - Credit (+500.000 VND)', () {
      const notif = RawNotification(
        id: 'test_acb_credit',
        packageName: 'mobile.acb.com.vn',
        title: 'ACB ONE',
        text:
            'ACB: TK 987654321 tang 500,000 VND luc 18/09/2026 09:15. So du 4,600,000 VND. ND: Khach tra tien hang',
        timestamp: 1789621800000,
        isBankNotification: true,
      );
      final tx = BankNotificationParser.parse(notif);
      expect(tx, isNotNull);
      expect(tx!.amount, 500000);
      expect(tx.type, 'credit');
      expect(tx.balance, 4600000);
      expect(tx.note, 'Khach tra tien hang');
    });

    // 11. TPBank Credit
    test('11. TPBank - Credit (+500.000 VND, Sinh hoạt phí)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.tpbankCredit);
      expect(tx, isNotNull);
      expect(tx!.title, 'TPBank Mobile');
      expect(tx.amount, 500000);
      expect(tx.type, 'credit');
      expect(tx.accountNumber, '09876543201');
      expect(tx.balance, 8900000);
      expect(tx.note, 'Chuyen tien sinh hoat phi');
      expect(tx.category, 'Chuyển tiền');
    });

    // 12. TPBank Debit
    test('12. TPBank - Debit (-150.000 VND, Xăng Petrolimex)', () {
      const notif = RawNotification(
        id: 'test_tpb_debit',
        packageName: 'com.tpb.mb.gprsandroid',
        title: 'TPBank',
        text:
            'TPBank: TK ...43201 -150,000 VND luc 18/09/2026 10:00. SD: 8,750,000 VND. ND: Mua xang Petrolimex',
        timestamp: 1789633800000,
        isBankNotification: true,
      );
      final tx = BankNotificationParser.parse(notif);
      expect(tx, isNotNull);
      expect(tx!.amount, 150000);
      expect(tx.type, 'debit');
      expect(tx.accountNumber, '...43201');
      expect(tx.balance, 8750000);
      expect(tx.note, 'Mua xang Petrolimex');
      expect(tx.category, 'Di chuyển');
    });

    // 13. BIDV Credit
    test('13. BIDV - Credit (+300.000 VND, Hoàn tiền)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.bidvCredit);
      expect(tx, isNotNull);
      expect(tx!.title, 'BIDV SmartBanking');
      expect(tx.amount, 300000);
      expect(tx.type, 'credit');
      expect(tx.accountNumber, '21510001234567');
      expect(tx.balance, 2500000);
      expect(tx.note, 'Hoan tien mua sam');
      expect(tx.category, 'Mua sắm');
    });

    // 14. BIDV Debit
    test('14. BIDV - Debit (-200.000 VND, Rút tiền ATM)', () {
      const notif = RawNotification(
        id: 'test_bidv_debit',
        packageName: 'com.vnpay.bidv',
        title: 'BIDV SmartBanking',
        text:
            'BIDV: TK 21510001234567 -200,000 VND vao 18/09/2026. So du: 2,300,000 VND. ND: Rut tien tai ATM',
        timestamp: 1789696800000,
        isBankNotification: true,
      );
      final tx = BankNotificationParser.parse(notif);
      expect(tx, isNotNull);
      expect(tx!.amount, 200000);
      expect(tx.type, 'debit');
      expect(tx.accountNumber, '21510001234567');
      expect(tx.balance, 2300000);
      expect(tx.note, 'Rut tien tai ATM');
    });

    // 15. MoMo Credit
    test('15. MoMo - Credit (+50.000đ, Tiền cà phê)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.momoReceive);
      expect(tx, isNotNull);
      expect(tx!.title, 'MoMo');
      expect(tx.amount, 50000);
      expect(tx.type, 'credit');
      expect(tx.note, 'Tien ca phe');
      expect(tx.category, 'Ăn uống');
    });

    // 16. MoMo Debit
    test('16. MoMo - Debit (-25.000đ, Circle K)', () {
      final tx = BankNotificationParser.parse(MockBankSamples.momoPayment);
      expect(tx, isNotNull);
      expect(tx!.title, 'MoMo');
      expect(tx.amount, 25000);
      expect(tx.type, 'debit');
      expect(tx.note, 'Circle K');
      expect(tx.category, 'Mua sắm');
    });

    // 17. ZaloPay Credit & Debit
    test('17. ZaloPay - Credit and Debit parsing', () {
      const zalopayCredit = RawNotification(
        id: 'test_zalopay_credit',
        packageName: 'vn.com.vng.zalopay',
        title: 'ZaloPay',
        text:
            'Bạn vừa nhận 100.000đ từ Trần Văn C. Lời nhắn: Chuyen tien an trua',
        timestamp: 1789710000000,
        isBankNotification: true,
      );
      final txCredit = BankNotificationParser.parse(zalopayCredit);
      expect(txCredit, isNotNull);
      expect(txCredit!.title, 'ZaloPay');
      expect(txCredit.amount, 100000);
      expect(txCredit.type, 'credit');
      expect(txCredit.note, 'Chuyen tien an trua');
      expect(txCredit.category, 'Ăn uống');

      const zalopayDebit = RawNotification(
        id: 'test_zalopay_debit',
        packageName: 'vn.com.vng.zalopay',
        title: 'ZaloPay',
        text: 'Thanh toán thành công 65.000đ cho đơn hàng Tiki. Mã GD: 123456',
        timestamp: 1789720000000,
        isBankNotification: true,
      );
      final txDebit = BankNotificationParser.parse(zalopayDebit);
      expect(txDebit, isNotNull);
      expect(txDebit!.title, 'ZaloPay');
      expect(txDebit.amount, 65000);
      expect(txDebit.type, 'debit');
      expect(txDebit.note, 'đơn hàng Tiki');
      expect(txDebit.category, 'Mua sắm');
    });

    // 18. Generic Fallback (VietinBank, Agribank, Timo with 'k')
    test('18. Generic Fallback - Other Banks and shorthand k amounts', () {
      const vietinNotif = RawNotification(
        id: 'test_vietin',
        packageName: 'com.vietinbank.ipay',
        title: 'VietinBank iPay',
        text:
            'TK 101001234567 -80,000 VND luc 12:00. So du: 1,200,000 VND. ND: GrabFood an trua',
        timestamp: 1789720000000,
        isBankNotification: true,
      );
      final txVietin = BankNotificationParser.parse(vietinNotif);
      expect(txVietin, isNotNull);
      expect(txVietin!.amount, 80000);
      expect(txVietin.type, 'debit');
      expect(txVietin.category, 'Ăn uống');

      const timoNotif = RawNotification(
        id: 'test_timo',
        packageName: 'vn.timo.app',
        title: 'Timo',
        text: 'Bạn đã thanh toán 50k tại Highlands Coffee',
        timestamp: 1789720000000,
        isBankNotification: true,
      );
      final txTimo = BankNotificationParser.parse(timoNotif);
      expect(txTimo, isNotNull);
      expect(txTimo!.amount, 50000);
      expect(txTimo.type, 'debit');
      expect(txTimo.category, 'Ăn uống');
    });
  });

  group('BankNotificationParser - Spam & Non-bank Rejection', () {
    test('returns null for non-bank social notifications (Facebook)', () {
      final tx = BankNotificationParser.parse(
        MockBankSamples.facebookNotification,
      );
      expect(tx, isNull);
    });

    test('returns null for chat messages without financial intent (Zalo)', () {
      const chatNotif = RawNotification(
        id: 'test_chat_zalo',
        packageName: 'com.zing.zalo',
        title: 'Zalo',
        text: 'Bạn có tin nhắn mới từ Lan: Tối nay đi ăn lẩu không?',
        timestamp: 1789725000000,
        isBankNotification: false,
      );
      final tx = BankNotificationParser.parse(chatNotif);
      expect(tx, isNull);
    });

    test(
      'returns null for bank promotional notices without transaction amount',
      () {
        const promoNotif = RawNotification(
          id: 'test_bank_promo',
          packageName: 'com.VCB',
          title: 'Vietcombank',
          text:
              'Ưu đãi đặc biệt: Mở thẻ tín dụng quốc tế hoàn tiền đến 20%, nhận ngay vali du lịch cao cấp!',
          timestamp: 1789725000000,
          isBankNotification: true,
        );
        final tx = BankNotificationParser.parse(promoNotif);
        expect(tx, isNull);
      },
    );

    test('returns null for e-commerce promotions without banking context', () {
      const ecomNotif = RawNotification(
        id: 'test_shopee_deal',
        packageName: 'com.shopee.vn',
        title: 'Shopee',
        text: 'Deal sốc 9k hôm nay! Hàng triệu mã freeship 0Đ đang chờ bạn.',
        timestamp: 1789725000000,
        isBankNotification: false,
      );
      final tx = BankNotificationParser.parse(ecomNotif);
      expect(tx, isNull);
    });
  });

  group('BankNotificationParser - Full MockBankSamples Verification', () {
    test('verifies all bank samples in MockBankSamples parse successfully', () {
      for (final sample in MockBankSamples.bankSamples) {
        final tx = BankNotificationParser.parse(sample);
        expect(
          tx,
          isNotNull,
          reason: 'Failed to parse sample: ${sample.id} (${sample.text})',
        );
        expect(tx!.amount, greaterThan(0));
        expect(['credit', 'debit'], contains(tx.type));
      }
    });

    test('verifies non-bank samples in MockBankSamples return null', () {
      for (final sample in MockBankSamples.nonBankSamples) {
        final tx = BankNotificationParser.parse(sample);
        expect(
          tx,
          isNull,
          reason: 'Non-bank sample should return null: ${sample.id}',
        );
      }
    });
  });
}
