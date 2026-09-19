import 'dart:convert';

/// Represents a raw notification captured from the system NotificationListenerService.
class RawNotification {
  final String id;
  final String packageName;
  final String title;
  final String text;
  final String? subText;
  final int timestamp;
  final bool isBankNotification;

  const RawNotification({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    this.subText,
    required this.timestamp,
    this.isBankNotification = false,
  });

  /// Converts this [RawNotification] to a Map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'packageName': packageName,
      'title': title,
      'text': text,
      'subText': subText,
      'timestamp': timestamp,
      'isBankNotification': isBankNotification,
    };
  }

  /// Creates a [RawNotification] from a Map with dynamic keys and values.
  factory RawNotification.fromMap(Map<dynamic, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    final parsedTimestamp = rawTimestamp is num
        ? rawTimestamp.toInt()
        : int.tryParse(rawTimestamp?.toString() ?? '') ?? 0;

    final rawIsBank = map['isBankNotification'];
    final isBank = rawIsBank == true ||
        rawIsBank == 1 ||
        rawIsBank?.toString().toLowerCase() == 'true';

    return RawNotification(
      id: map['id']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      subText: map['subText']?.toString(),
      timestamp: parsedTimestamp,
      isBankNotification: isBank,
    );
  }

  /// Converts this [RawNotification] to a JSON string.
  String toJson() => json.encode(toMap());

  /// Creates a [RawNotification] from a JSON string.
  factory RawNotification.fromJson(String source) =>
      RawNotification.fromMap(json.decode(source) as Map<dynamic, dynamic>);

  /// Creates a copy of this [RawNotification] with optional updated values.
  RawNotification copyWith({
    String? id,
    String? packageName,
    String? title,
    String? text,
    String? subText,
    int? timestamp,
    bool? isBankNotification,
  }) {
    return RawNotification(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      title: title ?? this.title,
      text: text ?? this.text,
      subText: subText ?? this.subText,
      timestamp: timestamp ?? this.timestamp,
      isBankNotification: isBankNotification ?? this.isBankNotification,
    );
  }

  @override
  String toString() {
    return 'RawNotification(id: $id, packageName: $packageName, title: $title, text: $text, subText: $subText, timestamp: $timestamp, isBankNotification: $isBankNotification)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RawNotification &&
        other.id == id &&
        other.packageName == packageName &&
        other.title == title &&
        other.text == text &&
        other.subText == subText &&
        other.timestamp == timestamp &&
        other.isBankNotification == isBankNotification;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      packageName,
      title,
      text,
      subText,
      timestamp,
      isBankNotification,
    );
  }
}
