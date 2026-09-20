import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/parsed_transaction.dart';
import '../models/raw_notification.dart';

/// Ultra-premium 2.5D card representing a single notification or bank transaction.
/// Features SVG-style gradient brand badges with colored drop-shadow,
/// high-contrast bold typography, and smooth squircle corners.
class TransactionCard extends StatelessWidget {
  final RawNotification notification;
  final ParsedTransaction? parsedTransaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.notification,
    this.parsedTransaction,
    this.onTap,
  });

  bool get isBank => parsedTransaction != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateFormatted = DateFormat('HH:mm:ss • dd/MM/yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(notification.timestamp),
    );

    // Card background subtle gradient
    final List<Color> cardGradient = isBank
        ? (parsedTransaction!.isCredit
            ? (isDark
                ? const [Color(0xFF13231B), Color(0xFF0E1A14)]
                : const [Color(0xFFFFFFFF), Color(0xFFF2FBF6)])
            : (isDark
                ? const [Color(0xFF261517), Color(0xFF1C0F11)]
                : const [Color(0xFFFFFFFF), Color(0xFFFFF6F5)]))
        : (isDark
            ? const [Color(0xFF1E2430), Color(0xFF161A24)]
            : const [Color(0xFFFFFFFF), Color(0xFFF9FAFB)]);

    // 2.5D Soft layered elevation shadow
    final List<BoxShadow> cardShadow = [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : const Color(0x0D0F172A),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : const Color(0x060F172A),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: cardShadow,
        border: Border.all(
          color: isBank
              ? (parsedTransaction!.isCredit
                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25)
                  : const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.35 : 0.25))
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap ?? () => _showDetailSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Brand Icon, Title & Account, Amount Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // SVG-style 2.5D Brand Icon Badge
                    _buildBrandBadge(context),
                    const SizedBox(width: 12),

                    // Title and Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDisplayTitle(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (isBank && parsedTransaction!.accountNumber != null) ...[
                                Text(
                                  'TK ${parsedTransaction!.accountNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8),
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  dateFormatted,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11.5,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Amount Badge (if parsed financial transaction)
                    if (isBank) ...[
                      const SizedBox(width: 8),
                      _buildAmountPill(context),
                    ],
                  ],
                ),

                // Content / Note Section
                const SizedBox(height: 12),
                _buildBodyContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2.5D SVG-style Icon badge with colored drop-shadow
  Widget _buildBrandBadge(BuildContext context) {
    final style = _getBankStyle();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.gradient,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: style.shadowColor.withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: style.monogram != null
            ? Text(
                style.monogram!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.3,
                ),
              )
            : Icon(
                style.iconData,
                color: Colors.white,
                size: 22,
              ),
      ),
    );
  }

  /// Amount Pill with 2.5D subtle elevation
  Widget _buildAmountPill(BuildContext context) {
    final isCredit = parsedTransaction!.isCredit;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color textColor = isCredit
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
        : (isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C));

    final Color bgColor = isCredit
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFD1FAE5))
        : (isDark ? const Color(0xFF881337).withValues(alpha: 0.5) : const Color(0xFFFFE4E6));

    final Color borderColor = isCredit
        ? const Color(0xFF10B981).withValues(alpha: 0.3)
        : const Color(0xFFF43F5E).withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: (isCredit ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
                .withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        parsedTransaction!.formattedAmount,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: textColor,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// Body content showing note/narration or notification message
  Widget _buildBodyContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isBank) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note / Narration
            if (parsedTransaction!.note.isNotEmpty) ...[
              Text(
                parsedTransaction!.note,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Category tag and Balance
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.6)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    parsedTransaction!.category,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ),

                // Balance if present
                if (parsedTransaction!.balance != null)
                  Text(
                    'Số dư: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(parsedTransaction!.balance)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // Non-bank raw notification body
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.subText != null && notification.subText!.trim().isNotEmpty) ...[
            Text(
              notification.subText!.trim(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            notification.text.isNotEmpty ? notification.text : '(Không có nội dung)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayTitle() {
    if (parsedTransaction != null && parsedTransaction!.title.isNotEmpty) {
      return parsedTransaction!.title;
    }
    if (notification.title.isNotEmpty) {
      return notification.title;
    }
    return notification.packageName.split('.').last;
  }

  _BankStyle _getBankStyle() {
    final title = _getDisplayTitle().toLowerCase();
    final pkg = notification.packageName.toLowerCase();

    if (title.contains('vietcombank') || title.contains('vcb') || pkg.contains('vcb')) {
      return const _BankStyle(
        gradient: [Color(0xFF10B981), Color(0xFF047857)],
        shadowColor: Color(0xFF10B981),
        monogram: 'VCB',
      );
    }
    if (title.contains('mb') || pkg.contains('mbmobile')) {
      return const _BankStyle(
        gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        shadowColor: Color(0xFF3B82F6),
        monogram: 'MB',
      );
    }
    if (title.contains('techcombank') || title.contains('tcb') || pkg.contains('techcombank')) {
      return const _BankStyle(
        gradient: [Color(0xFFEF4444), Color(0xFFB91C1C)],
        shadowColor: Color(0xFFEF4444),
        monogram: 'TCB',
      );
    }
    if (title.contains('vpbank') || pkg.contains('vpbank')) {
      return const _BankStyle(
        gradient: [Color(0xFF10B981), Color(0xFF059669)],
        shadowColor: Color(0xFF10B981),
        monogram: 'VPB',
      );
    }
    if (title.contains('acb') || pkg.contains('acb')) {
      return const _BankStyle(
        gradient: [Color(0xFF0284C7), Color(0xFF0369A1)],
        shadowColor: Color(0xFF0284C7),
        monogram: 'ACB',
      );
    }
    if (title.contains('tpbank') || pkg.contains('tpb')) {
      return const _BankStyle(
        gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        shadowColor: Color(0xFF8B5CF6),
        monogram: 'TPB',
      );
    }
    if (title.contains('bidv') || pkg.contains('bidv')) {
      return const _BankStyle(
        gradient: [Color(0xFF0D9488), Color(0xFF0F766E)],
        shadowColor: Color(0xFF0D9488),
        monogram: 'BIDV',
      );
    }
    if (title.contains('momo') || pkg.contains('momotransfer')) {
      return const _BankStyle(
        gradient: [Color(0xFFEC4899), Color(0xFFBE185D)],
        shadowColor: Color(0xFFEC4899),
        monogram: 'MoMo',
      );
    }
    if (title.contains('zalopay') || pkg.contains('zalopay')) {
      return const _BankStyle(
        gradient: [Color(0xFF0068FF), Color(0xFF0049B7)],
        shadowColor: Color(0xFF0068FF),
        monogram: 'Zalo',
      );
    }

    if (isBank) {
      return const _BankStyle(
        gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
        shadowColor: Color(0xFF6366F1),
        iconData: Icons.account_balance_rounded,
      );
    }

    // Default other app
    return const _BankStyle(
      gradient: [Color(0xFF64748B), Color(0xFF334155)],
      shadowColor: Color(0xFF64748B),
      iconData: Icons.notifications_active_rounded,
    );
  }

  /// Detail BottomSheet with 1-click JSON copy
  void _showDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final parsedJson = parsedTransaction != null
        ? const JsonEncoder.withIndent('  ').convert(parsedTransaction!.toMap())
        : null;
    final rawJson =
        const JsonEncoder.withIndent('  ').convert(notification.toMap());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _buildBrandBadge(context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDisplayTitle(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            isBank
                                ? 'Đã bóc tách giao dịch chuẩn'
                                : 'Thông báo hệ thống',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isBank
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content Area
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (parsedJson != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Parsed Transaction (Schema App)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text(
                              'Sao chép JSON',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: parsedJson));
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Đã sao chép Parsed Transaction JSON'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: SelectableText(
                          parsedJson,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Raw Payload
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Raw Android Notification Payload',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text(
                            'Sao chép',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: rawJson));
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✓ Đã sao chép Raw Notification JSON'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SelectableText(
                        rawJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

class _BankStyle {
  final List<Color> gradient;
  final Color shadowColor;
  final String? monogram;
  final IconData iconData;

  const _BankStyle({
    required this.gradient,
    required this.shadowColor,
    this.monogram,
    this.iconData = Icons.account_balance_rounded,
  });
}
