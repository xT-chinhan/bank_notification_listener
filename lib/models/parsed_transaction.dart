import 'dart:convert';
import 'package:intl/intl.dart';

/// Represents a parsed transaction extracted from a bank notification.
/// Designed for 100% compatibility with the transactions schema of App_Quan_ly_chi_tieu_ca_nhan.
class ParsedTransaction {
  /// Unique identifier (UUID).
  final String id;

  /// Bank / App name (e.g. 'Vietcombank', 'MBBank', 'Techcombank', 'MoMo').
  final String title;

  /// Positive integer amount in VND.
  final int amount;

  /// Transaction type: 'credit' (income/thu) or 'debit' (expense/chi).
  final String type;

  /// Epoch timestamp in milliseconds (millisecondsSinceEpoch).
  final int timestamp;

  /// Transaction category (e.g. 'Chuyển tiền', 'Ăn uống', 'Mua sắm', 'Lương', 'Khác').
  final String category;

  /// Transaction note or description.
  final String note;

  /// Masked or extracted account number (e.g. '...1234').
  final String? accountNumber;

  /// Account balance after transaction, if available.
  final int? balance;

  /// Original raw notification string.
  final String rawContent;

  /// Parsing confidence score from 0.0 to 1.0.
  final double confidence;

  const ParsedTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.timestamp,
    this.category = 'Khác',
    this.note = '',
    this.accountNumber,
    this.balance,
    this.rawContent = '',
    this.confidence = 1.0,
  });

  /// Whether this transaction is an incoming credit (+).
  bool get isCredit => type.toLowerCase() == 'credit';

  /// Whether this transaction is an outgoing debit (-).
  bool get isDebit => type.toLowerCase() == 'debit';

  /// Returns a formatted amount string with sign and Vietnamese currency symbol,
  /// e.g. '+ 50.000 đ' or '- 120.000 đ'.
  String get formattedAmount {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatted = formatter.format(amount.abs()).trim();
    final sign = isCredit ? '+' : '-';
    return '$sign $formatted';
  }

  /// Converts this [ParsedTransaction] to a Map compatible with Firestore and local DB schemas.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'timestamp': timestamp,
      'category': category,
      'note': note,
      'accountNumber': accountNumber,
      'balance': balance,
      'rawContent': rawContent,
      'confidence': confidence,
    };
  }

  /// Creates a [ParsedTransaction] from a Map.
  factory ParsedTransaction.fromMap(Map<String, dynamic> map) {
    final rawAmount = map['amount'];
    final parsedAmount = rawAmount is num
        ? rawAmount.toInt().abs()
        : (int.tryParse(rawAmount?.toString() ?? '') ?? 0).abs();

    final rawTimestamp = map['timestamp'];
    final parsedTimestamp = rawTimestamp is num
        ? rawTimestamp.toInt()
        : int.tryParse(rawTimestamp?.toString() ?? '') ?? 0;

    final rawBalance = map['balance'];
    final parsedBalance = rawBalance is num
        ? rawBalance.toInt()
        : int.tryParse(rawBalance?.toString() ?? '');

    final rawConfidence = map['confidence'];
    final parsedConfidence = rawConfidence is num
        ? rawConfidence.toDouble()
        : double.tryParse(rawConfidence?.toString() ?? '') ?? 1.0;

    return ParsedTransaction(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      amount: parsedAmount,
      type: map['type']?.toString() ?? 'debit',
      timestamp: parsedTimestamp,
      category: map['category']?.toString() ?? 'Khác',
      note: map['note']?.toString() ?? '',
      accountNumber: map['accountNumber']?.toString(),
      balance: parsedBalance,
      rawContent: map['rawContent']?.toString() ?? '',
      confidence: parsedConfidence,
    );
  }

  /// Converts this [ParsedTransaction] to a JSON string.
  String toJson() => json.encode(toMap());

  /// Creates a [ParsedTransaction] from a JSON string.
  factory ParsedTransaction.fromJson(String source) =>
      ParsedTransaction.fromMap(
        Map<String, dynamic>.from(json.decode(source) as Map),
      );

  /// Creates a copy of this [ParsedTransaction] with optional updated values.
  ParsedTransaction copyWith({
    String? id,
    String? title,
    int? amount,
    String? type,
    int? timestamp,
    String? category,
    String? note,
    String? accountNumber,
    int? balance,
    String? rawContent,
    double? confidence,
  }) {
    return ParsedTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      note: note ?? this.note,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      rawContent: rawContent ?? this.rawContent,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() {
    return 'ParsedTransaction(id: $id, title: $title, amount: $amount, type: $type, timestamp: $timestamp, category: $category, note: $note, accountNumber: $accountNumber, balance: $balance, rawContent: $rawContent, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedTransaction &&
        other.id == id &&
        other.title == title &&
        other.amount == amount &&
        other.type == type &&
        other.timestamp == timestamp &&
        other.category == category &&
        other.note == note &&
        other.accountNumber == accountNumber &&
        other.balance == balance &&
        other.rawContent == rawContent &&
        other.confidence == confidence;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      amount,
      type,
      timestamp,
      category,
      note,
      accountNumber,
      balance,
      rawContent,
      confidence,
    );
  }
}
