import '../models/raw_notification.dart';

/// Provides realistic mock notification samples for Vietnamese banks and e-wallets,
/// as well as non-bank notifications for testing notification filter rules.
class MockBankSamples {
  /// Vietcombank incoming transfer sample (+200.000 VND).
  static const RawNotification vietcombankCredit = RawNotification(
    id: 'mock_vcb_credit_01',
    packageName: 'com.VCB',
    title: 'Vietcombank',
    text: 'TK 0123456789 tại VCB +200,000VND vào 10:15 15/09/2026. Số dư 5,200,000VND. Ref MBVCB.123456789. Nguyen Van A chuyen tien',
    subText: 'Biến động số dư',
    timestamp: 1789442100000,
    isBankNotification: true,
  );

  /// Vietcombank outgoing payment sample (-50.000 VND).
  static const RawNotification vietcombankDebit = RawNotification(
    id: 'mock_vcb_debit_01',
    packageName: 'com.VCB',
    title: 'Vietcombank',
    text: 'TK 0123456789 tại VCB -50,000VND vào 09:30 14/09/2026. Số dư 5,000,000VND. Ref MBVCB.987654321. Thanh toan hoa don internet',
    subText: 'Biến động số dư',
    timestamp: 1789353000000,
    isBankNotification: true,
  );

  /// MBBank incoming salary sample (+2.500.000 VND, ND: Luong thang 9).
  static const RawNotification mbbankCredit = RawNotification(
    id: 'mock_mb_credit_01',
    packageName: 'com.mbmobile',
    title: 'MBBank',
    text: 'Biến động số dư: TK 123456789999 +2,500,000VND lúc 15/09/2026 08:30:00. Số dư: 15,350,000VND. ND: Luong thang 9',
    subText: 'Thông báo biến động số dư',
    timestamp: 1789435800000,
    isBankNotification: true,
  );

  /// MBBank outgoing expense sample (-35.000 VND, ND: Tra sua gong cha).
  static const RawNotification mbbankDebit = RawNotification(
    id: 'mock_mb_debit_01',
    packageName: 'com.mbmobile',
    title: 'MBBank',
    text: 'Biến động số dư: TK 123456789999 -35,000VND lúc 15/09/2026 14:20:15. Số dư: 12,815,000VND. ND: Tra sua gong cha',
    subText: 'Thông báo biến động số dư',
    timestamp: 1789456815000,
    isBankNotification: true,
  );

  /// Techcombank outgoing payment sample (-100.000 VND).
  static const RawNotification techcombankDebit = RawNotification(
    id: 'mock_tcb_debit_01',
    packageName: 'com.techcombank.bb.omb',
    title: 'Techcombank',
    text: 'GD: -100,000 VND tai Circle K luc 16/09/2026 18:00. TK: ...5678. So du: 3,450,000 VND. ND: Thanh toan QR',
    subText: 'Biến động số dư tài khoản',
    timestamp: 1789556400000,
    isBankNotification: true,
  );

  /// VPBank outgoing transaction sample (PS: -45.000 VND).
  static const RawNotification vpbankDebit = RawNotification(
    id: 'mock_vpb_debit_01',
    packageName: 'com.vpb.vpbankonline',
    title: 'VPBank NEO',
    text: 'TK 123456789: PS: -45,000VND lúc 16/09/2026 11:45. SD: 1,230,000VND. ND: Nap tien dien thoai',
    subText: 'Thông báo thay đổi số dư',
    timestamp: 1789533900000,
    isBankNotification: true,
  );

  /// ACB outgoing transaction sample (-120.000 VND).
  static const RawNotification acbDebit = RawNotification(
    id: 'mock_acb_debit_01',
    packageName: 'mobile.acb.com.vn',
    title: 'ACB ONE',
    text: 'ACB: TK 987654321 giam 120,000 VND luc 17/09/2026 12:10. So du 4,100,000 VND. ND: An trua cung dong nghiep',
    subText: 'Thông báo giao dịch',
    timestamp: 1789621800000,
    isBankNotification: true,
  );

  /// TPBank incoming transaction sample (+500.000 VND).
  static const RawNotification tpbankCredit = RawNotification(
    id: 'mock_tpb_credit_01',
    packageName: 'com.tpb.mb.gprsandroid',
    title: 'TPBank Mobile',
    text: 'TK 09876543201 +500,000 VND luc 17/09/2026 15:30. So du 8,900,000 VND. ND: Chuyen tien sinh hoat phi',
    subText: 'Thông báo biến động số dư',
    timestamp: 1789633800000,
    isBankNotification: true,
  );

  /// BIDV incoming transaction sample (+300.000 VND).
  static const RawNotification bidvCredit = RawNotification(
    id: 'mock_bidv_credit_01',
    packageName: 'com.vnpay.bidv',
    title: 'BIDV SmartBanking',
    text: 'TK 21510001234567 tai BIDV +300,000 VND vao 18/09/2026 09:00. So du: 2,500,000 VND. ND: Hoan tien mua sam',
    subText: 'Biến động số dư',
    timestamp: 1789696800000,
    isBankNotification: true,
  );

  /// MoMo receive money sample (+50.000đ từ Nguyễn Văn A).
  static const RawNotification momoReceive = RawNotification(
    id: 'mock_momo_credit_01',
    packageName: 'com.mservice.momotransfer',
    title: 'MoMo',
    text: 'Bạn vừa nhận được +50.000đ từ Nguyễn Văn A. Lời nhắn: Tien ca phe',
    subText: 'Nhận tiền thành công',
    timestamp: 1789710000000,
    isBankNotification: true,
  );

  /// MoMo payment sample (-25.000đ tại Circle K).
  static const RawNotification momoPayment = RawNotification(
    id: 'mock_momo_debit_01',
    packageName: 'com.mservice.momotransfer',
    title: 'MoMo',
    text: 'Bạn đã thanh toán thành công -25.000đ tại Circle K. Mã giao dịch 99887766.',
    subText: 'Thanh toán hóa đơn',
    timestamp: 1789720000000,
    isBankNotification: true,
  );

  /// Non-bank regular notification sample (e.g. Facebook).
  static const RawNotification facebookNotification = RawNotification(
    id: 'mock_fb_non_bank_01',
    packageName: 'com.facebook.katana',
    title: 'Facebook',
    text: 'Nguyễn Văn B đã thích ảnh của bạn.',
    subText: null,
    timestamp: 1789725000000,
    isBankNotification: false,
  );

  /// Complete list of mock notification samples.
  static const List<RawNotification> samples = <RawNotification>[
    vietcombankCredit,
    vietcombankDebit,
    mbbankCredit,
    mbbankDebit,
    techcombankDebit,
    vpbankDebit,
    acbDebit,
    tpbankCredit,
    bidvCredit,
    momoReceive,
    momoPayment,
    facebookNotification,
  ];

  /// Returns only the bank/fintech notification samples.
  static List<RawNotification> get bankSamples =>
      samples.where((notification) => notification.isBankNotification).toList();

  /// Returns only the non-bank notification samples.
  static List<RawNotification> get nonBankSamples =>
      samples.where((notification) => !notification.isBankNotification).toList();
}
