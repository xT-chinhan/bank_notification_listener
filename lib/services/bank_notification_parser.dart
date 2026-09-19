import 'package:uuid/uuid.dart';
import '../models/parsed_transaction.dart';
import '../models/raw_notification.dart';

/// Service responsible for identifying bank notifications and parsing them
/// into structured [ParsedTransaction] objects using regular expressions and heuristics.
class BankNotificationParser {
  static const Uuid _uuid = Uuid();

  /// Known package names of banking and e-wallet applications in Vietnam.
  static const Set<String> _bankPackageNames = {
    // Vietcombank
    'com.vcb',
    'com.vietcombank',
    'com.vcb.digibank',
    // MB Bank
    'com.mbmobile',
    'com.mbbank',
    // Techcombank
    'com.techcombank.mobile',
    'com.techcombank.bb.omb',
    'vn.com.techcombank.bb.app',
    // VPBank
    'com.vnpay.vpbankonline',
    'com.vpb.vpbankonline',
    'vn.vpbank.online',
    // ACB
    'mobile.acb.com.vn',
    'com.acb.mobile',
    // TPBank
    'com.tpb.mb.gprsandroid',
    'com.tpbank.mobile',
    // BIDV
    'com.vnpay.bidv',
    'com.bidv.smartbanking',
    // MoMo
    'com.mservice.momotransfer',
    // ZaloPay
    'vn.com.vng.zalopay',
    // VietinBank
    'com.vietinbank.ipay',
    // Agribank
    'com.vnpay.agribank',
    // Timo
    'vn.timo.app',
    // Sacombank
    'com.vnpay.sacombank',
    // VIB
    'com.vib.vibmobile',
    // OCB
    'com.ocb.omni.app',
    // SHB
    'com.shb.mobile',
    // HDBank
    'com.hdbank.mobile',
    // Viettel Money
    'com.viettel.viettelpay',
    // SeABank
    'vn.com.seabank.mb1',
    // MSB
    'com.msb.smartbanking',
    // BVBank
    'com.vccb',
  };

  /// Common keywords found in banking notifications.
  static const List<String> _bankKeywords = [
    'biến động số dư',
    'bien dong so du',
    'giao dịch',
    'giao dich',
    'số dư',
    'so du',
    'chuyển khoản',
    'chuyen khoan',
    'thanh toán',
    'thanh toan',
    'vietcombank',
    'vcb',
    'mbbank',
    'mb bank',
    'techcombank',
    'tcb',
    'vpbank',
    'acb',
    'tpbank',
    'bidv',
    'momo',
    'zalopay',
    'vietinbank',
    'agribank',
    'sacombank',
    'tiền vào',
    'tiền ra',
    'nhận tiền',
    'chuyển tiền',
  ];

  /// Checks whether a notification originates from a bank or fintech e-wallet.
  /// Matches against known package names, titles, or body keywords.
  static bool isBankApp(String packageName, String title, String text) {
    final lowerPkg = packageName.trim().toLowerCase();
    if (lowerPkg.isNotEmpty) {
      for (final bankPkg in _bankPackageNames) {
        if (lowerPkg == bankPkg || lowerPkg.contains(bankPkg)) {
          return true;
        }
      }
    }

    final lowerTitle = title.toLowerCase();
    final lowerText = text.toLowerCase();
    final combined = '$lowerTitle $lowerText';

    for (final kw in _bankKeywords) {
      if (combined.contains(kw)) {
        return true;
      }
    }

    // Also check unaccented version
    final normalized = _removeDiacritics(combined);
    for (final kw in _bankKeywords) {
      final normalizedKw = _removeDiacritics(kw);
      if (normalized.contains(normalizedKw)) {
        return true;
      }
    }

    return false;
  }

  /// Parses a [RawNotification] into a [ParsedTransaction].
  /// Returns `null` if the notification does not describe a valid financial transaction.
  static ParsedTransaction? parse(RawNotification notification) {
    final title = notification.title.trim();
    final text = notification.text.trim();
    final subText = notification.subText?.trim() ?? '';
    final fullText = '$title $text $subText'.trim();

    if (text.isEmpty && title.isEmpty) return null;

    final isKnownBank = isBankApp(notification.packageName, title, text);

    // If it's not a bank app and has no financial keywords, ignore it early.
    if (!isKnownBank) {
      final hasMoneySyntax = RegExp(
        r'([+-]?\s*[\d\.,]+)\s*(?:VND|VNĐ|đ|dong|đồng)',
        caseSensitive: false,
      ).hasMatch(fullText);
      final hasBankSyntax = RegExp(
        r'(?:TK|STK|Số dư|So du|SD:|GD:|Biến động số dư)',
        caseSensitive: false,
      ).hasMatch(fullText);

      if (!hasMoneySyntax || !hasBankSyntax) {
        return null;
      }
    }

    // Determine the bank identifier
    final bankKey = _detectBankKey(notification.packageName, title, text);

    // Primary text to parse: notification.text has the transaction details.
    // If notification.text is empty, fallback to title + fullText.
    final parseTarget = text.isNotEmpty ? text : fullText;

    _ParseResult? result;

    switch (bankKey) {
      case 'vietcombank':
        result = _parseVietcombank(notification, parseTarget);
        break;
      case 'mbbank':
        result = _parseMBBank(notification, parseTarget);
        break;
      case 'techcombank':
        result = _parseTechcombank(notification, parseTarget);
        break;
      case 'vpbank':
        result = _parseVPBank(notification, parseTarget);
        break;
      case 'acb':
        result = _parseACB(notification, parseTarget);
        break;
      case 'tpbank':
        result = _parseTPBank(notification, parseTarget);
        break;
      case 'bidv':
        result = _parseBIDV(notification, parseTarget);
        break;
      case 'momo':
        result = _parseMoMo(notification, parseTarget);
        break;
      case 'zalopay':
        result = _parseZaloPay(notification, parseTarget);
        break;
      default:
        result = null;
        break;
    }

    // Fallback parser if specific bank parsing yielded nothing or bank not recognized
    result ??= _parseGeneric(notification, parseTarget, bankKey);

    if (result == null || result.amount <= 0) {
      return null;
    }

    final effectiveTimestamp = notification.timestamp > 0
        ? notification.timestamp
        : DateTime.now().millisecondsSinceEpoch;

    final category = _determineCategory(result.note, parseTarget, result.type);

    return ParsedTransaction(
      id: _uuid.v4(),
      title: result.bankTitle,
      amount: result.amount,
      type: result.type,
      timestamp: effectiveTimestamp,
      category: category,
      note: result.note,
      accountNumber: result.accountNumber,
      balance: result.balance,
      rawContent: '${notification.title}: ${notification.text}',
      confidence: result.confidence,
    );
  }

  // ---------------------------------------------------------------------------
  // Bank Detection Helpers
  // ---------------------------------------------------------------------------

  static String _detectBankKey(String packageName, String title, String text) {
    final lowerPkg = packageName.toLowerCase();
    final lowerCombined = '$title $text'.toLowerCase();

    if (lowerPkg.contains('vcb') ||
        lowerPkg.contains('vietcombank') ||
        lowerCombined.contains('vietcombank') ||
        lowerCombined.contains('vcb')) {
      return 'vietcombank';
    }
    if (lowerPkg.contains('mbmobile') ||
        lowerPkg.contains('mbbank') ||
        lowerCombined.contains('mbbank') ||
        lowerCombined.contains('mb bank')) {
      return 'mbbank';
    }
    if (lowerPkg.contains('techcombank') ||
        lowerCombined.contains('techcombank') ||
        lowerCombined.contains('tcb')) {
      return 'techcombank';
    }
    if (lowerPkg.contains('vpbank') ||
        lowerPkg.contains('vpb') ||
        lowerCombined.contains('vpbank')) {
      return 'vpbank';
    }
    if (lowerPkg.contains('acb') || lowerCombined.contains('acb')) {
      return 'acb';
    }
    if (lowerPkg.contains('tpb') || lowerCombined.contains('tpbank')) {
      return 'tpbank';
    }
    if (lowerPkg.contains('bidv') || lowerCombined.contains('bidv')) {
      return 'bidv';
    }
    if (lowerPkg.contains('momo') || lowerCombined.contains('momo')) {
      return 'momo';
    }
    if (lowerPkg.contains('zalopay') || lowerCombined.contains('zalopay')) {
      return 'zalopay';
    }
    return 'generic';
  }

  // ---------------------------------------------------------------------------
  // Specific Bank Parsers
  // ---------------------------------------------------------------------------

  /// Vietcombank Parser
  static _ParseResult? _parseVietcombank(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK\s*([0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:Số dư|So du|SD:?)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    // Pattern 1: Signed amount e.g. +200,000VND or -50,000VND
    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    } else {
      // Pattern 2: After VCB e.g. "tại VCB 200,000VND"
      final vcbAmountMatch = RegExp(
        r'(?:tại VCB|VCB:?)\s*([+-]?\s*[\d\.,]+)\s*(?:VND|VNĐ|đ)',
        caseSensitive: false,
      ).firstMatch(text);
      if (vcbAmountMatch != null) {
        final raw = vcbAmountMatch.group(1)!.replaceAll(' ', '');
        if (raw.startsWith('+')) {
          type = 'credit';
        } else if (raw.startsWith('-')) {
          type = 'debit';
        }
        amount = _parseCleanNumber(raw);
      }
    }

    if (amount == null) return null;

    type ??= _inferTypeFromKeywords(text);

    // Extract content/note
    String note = '';
    final ndMatch = RegExp(
      r'ND:\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (ndMatch != null && ndMatch.group(1)!.trim().isNotEmpty) {
      note = ndMatch.group(1)!.trim();
    } else {
      // Look for Ref e.g. Ref MBVCB.123456789. Nguyen Van A chuyen tien
      final refMatch = RegExp(
        r'Ref\s+[\w\.-]+\.\s*(.*)',
        caseSensitive: false,
      ).firstMatch(text);
      if (refMatch != null && refMatch.group(1)!.trim().isNotEmpty) {
        note = refMatch.group(1)!.replaceAll(RegExp(r'\.+$'), '').trim();
      }
    }

    return _ParseResult(
      bankTitle: 'Vietcombank',
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// MB Bank Parser
  static _ParseResult? _parseMBBank(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK\s*([0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:Số dư|So du|SD:?)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    // Pattern 1: GD:\s*([+-]?[\d\.,]+)
    final gdMatch = RegExp(
      r'GD:\s*([+-]?\s*[\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (gdMatch != null) {
      final raw = gdMatch.group(1)!.replaceAll(' ', '');
      if (raw.startsWith('+')) type = 'credit';
      if (raw.startsWith('-')) type = 'debit';
      amount = _parseCleanNumber(raw);
    }

    // Pattern 2: Signed amount after account number or in text
    if (amount == null) {
      final signedMatch = RegExp(
        r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
        caseSensitive: false,
      ).firstMatch(text);
      if (signedMatch != null) {
        type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
        amount = _parseCleanNumber(signedMatch.group(2)!);
      }
    }

    if (amount == null) return null;

    type ??= _inferTypeFromKeywords(text);

    // Note: ND:\s*(.*?)(?:\.\|SD\||SD:|\.|$|\n)
    var note = '';
    final ndMatch = RegExp(
      r'ND:\s*(.*?)(?:\.\|SD\||SD:|\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (ndMatch != null) {
      note = ndMatch.group(1)!.trim();
    }

    return _ParseResult(
      bankTitle: 'MBBank',
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// Techcombank Parser
  static _ParseResult? _parseTechcombank(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK:?\s*([0-9xX\*]+|\.{3}[0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:So du|Số dư|SD:?)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    // Check signed pattern
    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    } else {
      final amountMatch = RegExp(
        r'(?:GD:?|nhan duoc|chuyen thanh cong)?\s*([+-]?\s*[\d\.,]+)\s*(?:VND|VNĐ|đ)',
        caseSensitive: false,
      ).firstMatch(text);
      if (amountMatch != null) {
        amount = _parseCleanNumber(amountMatch.group(1)!);
      }
    }

    if (amount == null) return null;

    type ??= _inferTypeFromKeywords(text);

    var note = '';
    final noteMatch = RegExp(
      r'(?:Noi dung|ND|Lý do|Nội dung):\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (noteMatch != null) {
      note = noteMatch.group(1)!.trim();
    } else {
      final taiMatch = RegExp(
        r'tai\s+([A-Za-z0-9\s]+?)(?:\s+luc|\s+ngay|\.|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (taiMatch != null) {
        note = taiMatch.group(1)!.trim();
      }
    }

    return _ParseResult(
      bankTitle: 'Techcombank',
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// VPBank Parser
  static _ParseResult? _parseVPBank(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK\s*([0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:SD|Số dư|So du)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    final psMatch = RegExp(
      r'PS:\s*([+-]?\s*[\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (psMatch != null) {
      final raw = psMatch.group(1)!.replaceAll(' ', '');
      if (raw.startsWith('+')) type = 'credit';
      if (raw.startsWith('-')) type = 'debit';
      amount = _parseCleanNumber(raw);
    } else {
      final signedMatch = RegExp(
        r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
        caseSensitive: false,
      ).firstMatch(text);
      if (signedMatch != null) {
        type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
        amount = _parseCleanNumber(signedMatch.group(2)!);
      }
    }

    if (amount == null) return null;

    type ??= _inferTypeFromKeywords(text);

    var note = '';
    final noteMatch = RegExp(
      r'ND:\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (noteMatch != null) {
      note = noteMatch.group(1)!.trim();
    }

    final bankTitle = n.title.contains('VPBank NEO') ? 'VPBank NEO' : 'VPBank';

    return _ParseResult(
      bankTitle: bankTitle,
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// ACB Parser
  static _ParseResult? _parseACB(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK\s*([0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:So du|Số dư|SD)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    final giamMatch = RegExp(
      r'(?:giam|giảm|-)\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (giamMatch != null) {
      type = 'debit';
      amount = _parseCleanNumber(giamMatch.group(1)!);
    } else {
      final tangMatch = RegExp(
        r'(?:tang|tăng|\+)\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
        caseSensitive: false,
      ).firstMatch(text);
      if (tangMatch != null) {
        type = 'credit';
        amount = _parseCleanNumber(tangMatch.group(1)!);
      }
    }

    if (amount == null) return null;

    var note = '';
    final noteMatch = RegExp(
      r'ND:\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (noteMatch != null) {
      note = noteMatch.group(1)!.trim();
    }

    final bankTitle = n.title.contains('ACB ONE') ? 'ACB ONE' : 'ACB';

    return _ParseResult(
      bankTitle: bankTitle,
      amount: amount,
      type: type ?? 'debit',
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// TPBank Parser
  static _ParseResult? _parseTPBank(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK\s*([0-9xX\*]+|\.{3}[0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:So du|Số dư|SD:?)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    }

    if (amount == null) return null;

    type ??= _inferTypeFromKeywords(text);

    var note = '';
    final noteMatch = RegExp(
      r'ND:\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (noteMatch != null) {
      note = noteMatch.group(1)!.trim();
    }

    final bankTitle = n.title.contains('TPBank Mobile')
        ? 'TPBank Mobile'
        : 'TPBank';

    return _ParseResult(
      bankTitle: bankTitle,
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// BIDV Parser
  static _ParseResult? _parseBIDV(RawNotification n, String text) {
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(r'TK\s*([0-9xX\*]+)', caseSensitive: false),
      ),
    );

    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:So du|Số dư|SD:?)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    int? amount;
    String? type;

    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    }

    if (amount == null) return null;

    type ??= _inferTypeFromKeywords(text);

    var note = '';
    final noteMatch = RegExp(
      r'ND:\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (noteMatch != null) {
      note = noteMatch.group(1)!.trim();
    }

    final bankTitle = n.title.contains('BIDV SmartBanking')
        ? 'BIDV SmartBanking'
        : 'BIDV';

    return _ParseResult(
      bankTitle: bankTitle,
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 1.0,
    );
  }

  /// MoMo Parser
  static _ParseResult? _parseMoMo(RawNotification n, String text) {
    int? amount;
    String? type;

    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:đ|VND|VNĐ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    } else {
      final amountMatch = RegExp(
        r'([\d\.,]+)\s*(?:đ|VND|VNĐ)',
        caseSensitive: false,
      ).firstMatch(text);
      if (amountMatch != null) {
        amount = _parseCleanNumber(amountMatch.group(1)!);
      }
    }

    if (amount == null) return null;

    final normalized = _removeDiacritics(text.toLowerCase());
    if (type == null) {
      if (normalized.contains('nhan') || normalized.contains('hoan tien')) {
        type = 'credit';
      } else if (normalized.contains('thanh toan') ||
          normalized.contains('chuyen tien') ||
          normalized.contains('nap tien')) {
        type = 'debit';
      } else {
        type = _inferTypeFromKeywords(text);
      }
    }

    var note = '';
    final messageMatch = RegExp(
      r'(?:Lời nhắn|Loi nhan|nội dung|Noi dung):\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (messageMatch != null && messageMatch.group(1)!.trim().isNotEmpty) {
      note = messageMatch.group(1)!.trim();
    } else {
      final taiMatch = RegExp(
        r'tại\s+(.*?)(?:\.|\s*Mã giao dịch|\s*Ma GD|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (taiMatch != null && taiMatch.group(1)!.trim().isNotEmpty) {
        note = taiMatch.group(1)!.trim();
      } else {
        final tuMatch = RegExp(
          r'từ\s+(.*?)(?:\.|\s*Lời nhắn|\s*Loi nhan|$)',
          caseSensitive: false,
        ).firstMatch(text);
        if (tuMatch != null && tuMatch.group(1)!.trim().isNotEmpty) {
          note = tuMatch.group(1)!.trim();
        }
      }
    }

    return _ParseResult(
      bankTitle: 'MoMo',
      amount: amount,
      type: type,
      accountNumber: null,
      balance: null,
      note: note,
      confidence: 1.0,
    );
  }

  /// ZaloPay Parser
  static _ParseResult? _parseZaloPay(RawNotification n, String text) {
    int? amount;
    String? type;

    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:đ|VND|VNĐ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    } else {
      final amountMatch = RegExp(
        r'([\d\.,]+)\s*(?:đ|VND|VNĐ)',
        caseSensitive: false,
      ).firstMatch(text);
      if (amountMatch != null) {
        amount = _parseCleanNumber(amountMatch.group(1)!);
      }
    }

    if (amount == null) return null;

    final normalized = _removeDiacritics(text.toLowerCase());
    if (type == null) {
      if (normalized.contains('nhan') || normalized.contains('hoan tien')) {
        type = 'credit';
      } else if (normalized.contains('thanh toan') ||
          normalized.contains('chuyen tien')) {
        type = 'debit';
      } else {
        type = _inferTypeFromKeywords(text);
      }
    }

    var note = '';
    final messageMatch = RegExp(
      r'(?:Lời nhắn|Loi nhan|nội dung|Noi dung):\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (messageMatch != null && messageMatch.group(1)!.trim().isNotEmpty) {
      note = messageMatch.group(1)!.trim();
    } else {
      final choMatch = RegExp(
        r'cho\s+(.*?)(?:\.|\s*Mã GD|\s*Mã giao dịch|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (choMatch != null && choMatch.group(1)!.trim().isNotEmpty) {
        note = choMatch.group(1)!.trim();
      }
    }

    return _ParseResult(
      bankTitle: 'ZaloPay',
      amount: amount,
      type: type,
      accountNumber: null,
      balance: null,
      note: note,
      confidence: 1.0,
    );
  }

  /// Generic Fallback Parser
  static _ParseResult? _parseGeneric(
    RawNotification n,
    String text,
    String bankKey,
  ) {
    // 1. Extract balance first to avoid capturing balance as amount
    final balanceStr = _extractFirstMatch(
      text,
      RegExp(r'(?:Số dư|So du|SD:?)\s*:?\s*([\d\.,]+)', caseSensitive: false),
    );
    final balance = balanceStr != null ? _parseCleanNumber(balanceStr) : null;

    // 2. Extract account number
    final account = _cleanAccount(
      _extractFirstMatch(
        text,
        RegExp(
          r'(?:TK|STK|Tài khoản|Tai khoan)\s*:?\s*([0-9xX\*]+|\.{3}[0-9xX\*]+)',
          caseSensitive: false,
        ),
      ),
    );

    // 3. Extract transaction amount
    int? amount;
    String? type;

    // Check signed amount: [+-]50,000 VND
    final signedMatch = RegExp(
      r'([+-])\s*([\d\.,]+)\s*(?:VND|VNĐ|đ)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (signedMatch != null) {
      type = signedMatch.group(1) == '+' ? 'credit' : 'debit';
      amount = _parseCleanNumber(signedMatch.group(2)!);
    }

    // Check currency suffix: 100,000 VND / 100.000 đ
    if (amount == null) {
      final matches = RegExp(
        r'([\d\.,]+)\s*(?:VND|VNĐ|đ|dong|đồng)',
        caseSensitive: false,
      ).allMatches(text);

      for (final m in matches) {
        final candidate = _parseCleanNumber(m.group(1)!);
        if (candidate != null && candidate != balance) {
          amount = candidate;
          break;
        }
      }
    }

    // Check shorthand currency: 50k, 100k
    if (amount == null) {
      final kMatch = RegExp(
        r'(\d+(?:[\.,]\d+)?)\s*k\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (kMatch != null) {
        final val = double.tryParse(kMatch.group(1)!.replaceAll(',', '.'));
        if (val != null && val > 0) {
          amount = (val * 1000).round();
        }
      }
    }

    if (amount == null || amount <= 0) return null;

    type ??= _inferTypeFromKeywords(text);

    // Extract note
    var note = '';
    final noteMatch = RegExp(
      r'(?:ND|Noi dung|Nội dung|Lời nhắn|Loi nhan|Lý do|Ly do|Ref):\s*(.*?)(?:\.|$|\n)',
      caseSensitive: false,
    ).firstMatch(text);
    if (noteMatch != null) {
      note = noteMatch.group(1)!.trim();
    }

    // Derive bank display title
    final bankTitle = _deriveBankTitle(n.title, bankKey);

    return _ParseResult(
      bankTitle: bankTitle,
      amount: amount,
      type: type,
      accountNumber: account,
      balance: balance,
      note: note,
      confidence: 0.85,
    );
  }

  // ---------------------------------------------------------------------------
  // Utility & Heuristic Helpers
  // ---------------------------------------------------------------------------

  /// Infers 'credit' vs 'debit' from Vietnamese financial transaction keywords using word boundaries.
  static String _inferTypeFromKeywords(String text) {
    final lower = text.toLowerCase();
    final normalized = _removeDiacritics(lower);

    if (text.contains('+')) return 'credit';
    if (text.contains('-')) return 'debit';

    final creditPatterns = [
      RegExp(
        r'\b(?:nhan|nhan duoc|tang|duoc chuyen|cong|chuyen vao|hoan tien|nap vao|thu nhap)\b',
      ),
      RegExp(
        r'\b(?:nhận|nhận được|tăng|được chuyển|cộng|chuyển vào|hoàn tiền|nạp vào|thu nhập)\b',
      ),
    ];

    final debitPatterns = [
      RegExp(
        r'\b(?:giam|thanh toan|rut|tru|chuyen di|chuyen cho|chuyen thanh cong|ck di|mua)\b',
      ),
      RegExp(
        r'\b(?:giảm|thanh toán|rút|trừ|chuyển đi|chuyển cho|chuyển thành công|ck đi|mua)\b',
      ),
    ];

    int creditScore = 0;
    for (final p in creditPatterns) {
      if (p.hasMatch(lower) || p.hasMatch(normalized)) creditScore += 2;
    }

    int debitScore = 0;
    for (final p in debitPatterns) {
      if (p.hasMatch(lower) || p.hasMatch(normalized)) debitScore += 2;
    }

    if (creditScore > debitScore) return 'credit';
    if (debitScore > creditScore) return 'debit';
    return 'debit';
  }

  /// Categorizes the transaction based on note and content keywords.
  static String _determineCategory(String note, String fullText, String type) {
    final searchTarget = '$note $fullText'.toLowerCase();
    final normalized = _removeDiacritics(searchTarget);

    // 1. Lương (Salary / Bonus)
    if (_containsAny(normalized, [
      'luong',
      'salary',
      'thuong kpi',
      'thuong',
      'bonus',
      'tam ung',
      'payroll',
    ])) {
      return 'Lương';
    }

    // 2. Mua sắm (Shopping / Convenience Store)
    if (_containsAny(normalized, [
      'circle k',
      'shopee',
      'lazada',
      'tiki',
      'tiktok shop',
      'sieu thi',
      'vinmart',
      'winmart',
      'coop',
      'bach hoa xanh',
      'quan ao',
      'shop',
      'store',
      'mall',
      'mart',
      'mua do',
      'mua sam',
      'qr',
    ])) {
      return 'Mua sắm';
    }

    // 3. Ăn uống (Food & Beverage)
    if (_containsAny(normalized, [
      'cafe',
      'coffee',
      'ca phe',
      'an uong',
      'an trua',
      'an sang',
      'an toi',
      'tra sua',
      'gong cha',
      'highlands',
      'phuc long',
      'starbucks',
      'kfc',
      'lotteria',
      'mcdonald',
      'pizza',
      'food',
      'baemin',
      'shopeefood',
      'now.vn',
      'com ',
      'pho ',
      'bun ',
      'lau ',
      'nhau ',
    ])) {
      return 'Ăn uống';
    }

    // 4. Di chuyển (Transport)
    if (_containsAny(normalized, [
      'grab',
      'be ',
      'be taxi',
      'xanh sm',
      'gojek',
      'taxi',
      'xang',
      'petrolimex',
      've xe',
      've tau',
      've may bay',
      'vietjet',
      'vietnam airlines',
      'bamboo',
    ])) {
      return 'Di chuyển';
    }

    // 5. Hóa đơn & Tiện ích (Bills & Utilities)
    if (_containsAny(normalized, [
      'internet',
      'tien dien',
      'tien nuoc',
      'cuoc',
      'viettel',
      'mobifone',
      'vinaphone',
      'fpt',
      'nap tien dien thoai',
      'phi duy tri',
      'truyen hinh',
      'dien luc',
      'hoa don',
    ])) {
      return 'Hóa đơn & Tiện ích';
    }

    // 6. Chuyển tiền (Transfer)
    if (_containsAny(normalized, [
      'chuyen tien',
      'chuyen khoan',
      'ck',
      'gui tien',
      'chuyen cho',
      'sinh hoat phi',
      'hoan tien',
      'tra tien',
    ])) {
      return 'Chuyển tiền';
    }

    // Fallback based on type
    return type == 'credit' ? 'Chuyển tiền' : 'Khác';
  }

  static bool _containsAny(String source, List<String> keywords) {
    for (final kw in keywords) {
      if (source.contains(kw)) return true;
    }
    return false;
  }

  static String? _cleanAccount(String? raw) {
    if (raw == null) return null;
    return raw.replaceAll(RegExp(r'[\.,;:\s]+$'), '').trim();
  }

  static String? _extractFirstMatch(String text, RegExp regExp) {
    final match = regExp.firstMatch(text);
    return match?.group(1)?.trim();
  }

  static int? _parseCleanNumber(String str) {
    final cleanDigits = str.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) return null;
    return int.tryParse(cleanDigits);
  }

  static String _deriveBankTitle(String title, String bankKey) {
    switch (bankKey) {
      case 'vietcombank':
        return 'Vietcombank';
      case 'mbbank':
        return 'MBBank';
      case 'techcombank':
        return 'Techcombank';
      case 'vpbank':
        return 'VPBank';
      case 'acb':
        return 'ACB';
      case 'tpbank':
        return 'TPBank';
      case 'bidv':
        return 'BIDV';
      case 'momo':
        return 'MoMo';
      case 'zalopay':
        return 'ZaloPay';
      default:
        return title.isNotEmpty ? title : 'Ngân hàng khác';
    }
  }

  /// Removes Vietnamese diacritics / accent marks from a string.
  static String _removeDiacritics(String str) {
    const withDiacritics =
        'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ'
        'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }
}

/// Helper container holding parsed bank transaction properties.
class _ParseResult {
  final String bankTitle;
  final int amount;
  final String type;
  final String? accountNumber;
  final int? balance;
  final String note;
  final double confidence;

  const _ParseResult({
    required this.bankTitle,
    required this.amount,
    required this.type,
    this.accountNumber,
    this.balance,
    this.note = '',
    this.confidence = 1.0,
  });
}
