import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/parsed_transaction.dart';
import '../models/raw_notification.dart';

/// Card widget to display a single notification item in the monitor list.
/// Highlights financial transactions (Credit vs Debit) and allows tapping to
/// inspect raw & parsed JSON payloads with one-click copy.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isBank = parsedTransaction != null;

    final dateFormatted = DateFormat('HH:mm:ss • dd/MM/yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(notification.timestamp),
    );

    return Card(
      elevation: isBank ? 2 : 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBank
              ? (parsedTransaction!.isCredit
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.deepOrange.withValues(alpha: 0.5))
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isBank ? 1.5 : 1,
        ),
      ),
      color: isBank
          ? (isDark
              ? (parsedTransaction!.isCredit
                  ? const Color(0xFF0F2618)
                  : const Color(0xFF2B1410))
              : (parsedTransaction!.isCredit
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED)))
          : (isDark ? const Color(0xFF1E1E24) : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap ?? () => _showDetailDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: App icon, Title / Package, Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAppIcon(context),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _getHeaderTitle(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBank) ...[
                              const SizedBox(width: 6),
                              _buildBankBadge(context),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateFormatted  •  ${_getShortPackage(notification.packageName)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Highlight section for parsed financial transactions
              if (isBank) ...[
                _buildFinancialHighlight(context),
                const SizedBox(height: 10),
              ],

              // Body: Raw notification text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notification.subText != null &&
                        notification.subText!.trim().isNotEmpty) ...[
                      Text(
                        notification.subText!.trim(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      notification.text.isNotEmpty
                          ? notification.text
                          : '(Không có nội dung văn bản)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    if (parsedTransaction != null && parsedTransaction!.title.isNotEmpty) {
      return parsedTransaction!.title;
    }
    if (notification.title.isNotEmpty) {
      return notification.title;
    }
    return notification.packageName;
  }

  String _getShortPackage(String pkg) {
    if (pkg.isEmpty) return 'Unknown';
    final parts = pkg.split('.');
    if (parts.length >= 2) {
      return parts.sublist(parts.length - 2).join('.');
    }
    return pkg;
  }

  Widget _buildAppIcon(BuildContext context) {
    final titleLower = (parsedTransaction?.title ?? notification.title).toLowerCase();
    final pkgLower = notification.packageName.toLowerCase();

    IconData icon = Icons.notifications_active_outlined;
    Color iconColor = Colors.grey;
    Color bgColor = Colors.grey.withValues(alpha: 0.15);

    if (titleLower.contains('vietcombank') || pkgLower.contains('vcb')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFF006633);
      bgColor = const Color(0xFFE8F5E9);
    } else if (titleLower.contains('mb') || pkgLower.contains('mbmobile')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFF002B7F);
      bgColor = const Color(0xFFE3F2FD);
    } else if (titleLower.contains('techcombank') || pkgLower.contains('techcombank')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFFE51A24);
      bgColor = const Color(0xFFFFEBEE);
    } else if (titleLower.contains('vpbank') || pkgLower.contains('vpbank')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFF00965E);
      bgColor = const Color(0xFFE8F5E9);
    } else if (titleLower.contains('acb') || pkgLower.contains('acb')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFF005696);
      bgColor = const Color(0xFFE1F5FE);
    } else if (titleLower.contains('tpbank') || pkgLower.contains('tpb')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFF7B1FA2);
      bgColor = const Color(0xFFF3E5F5);
    } else if (titleLower.contains('bidv') || pkgLower.contains('bidv')) {
      icon = Icons.account_balance_rounded;
      iconColor = const Color(0xFF007236);
      bgColor = const Color(0xFFE8F5E9);
    } else if (titleLower.contains('momo') || pkgLower.contains('momotransfer')) {
      icon = Icons.account_balance_wallet_rounded;
      iconColor = const Color(0xFFA50064);
      bgColor = const Color(0xFFFCE4EC);
    } else if (titleLower.contains('zalopay') || pkgLower.contains('zalopay')) {
      icon = Icons.wallet_rounded;
      iconColor = const Color(0xFF0068FF);
      bgColor = const Color(0xFFE3F2FD);
    } else if (parsedTransaction != null) {
      icon = Icons.account_balance_rounded;
      iconColor = Colors.teal;
      bgColor = Colors.teal.withValues(alpha: 0.15);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  Widget _buildBankBadge(BuildContext context) {
    final isCredit = parsedTransaction!.isCredit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isCredit
            ? Colors.green.withValues(alpha: 0.18)
            : Colors.deepOrange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isCredit ? 'THU NHẬP' : 'CHI TIÊU',
        style: TextStyle(
          color: isCredit ? Colors.green.shade800 : Colors.deepOrange.shade800,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFinancialHighlight(BuildContext context) {
    final tx = parsedTransaction!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currencyFormatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? (tx.isCredit
                ? const Color(0xFF143320)
                : const Color(0xFF381A15))
            : (tx.isCredit
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFECE0)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tx.isCredit
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.deepOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Amount + Confidence badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tx.formattedAmount,
                style: TextStyle(
                  color: tx.isCredit
                      ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                      : (isDark ? const Color(0xFFFB7185) : const Color(0xFFDC2626)),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              if (tx.confidence < 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Độ tin cậy: ${(tx.confidence * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Chips: Category, Account, Balance
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildInfoChip(
                context,
                icon: Icons.label_outline_rounded,
                label: tx.category,
                color: Colors.indigo,
              ),
              if (tx.accountNumber != null && tx.accountNumber!.isNotEmpty)
                _buildInfoChip(
                  context,
                  icon: Icons.credit_card_rounded,
                  label: 'TK: ${tx.accountNumber}',
                  color: Colors.blueGrey,
                ),
              if (tx.balance != null)
                _buildInfoChip(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Dư: ${currencyFormatter.format(tx.balance).trim()}',
                  color: Colors.teal,
                ),
            ],
          ),

          if (tx.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tx.note,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? color.shade900.withValues(alpha: 0.4) : color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? color.shade700.withValues(alpha: 0.5) : color.shade200,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? color.shade200 : color.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? color.shade100 : color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final parsedJson = parsedTransaction != null
            ? const JsonEncoder.withIndent('  ').convert(parsedTransaction!.toMap())
            : null;
        final rawJson =
            const JsonEncoder.withIndent('  ').convert(notification.toMap());

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              _buildAppIcon(dialogContext),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getHeaderTitle(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      notification.packageName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: DefaultTabController(
              length: parsedJson != null ? 2 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (parsedJson != null)
                    const TabBar(
                      labelColor: Colors.blueAccent,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(text: 'Parsed Transaction'),
                        Tab(text: 'Raw Notification'),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SizedBox(
                      height: 320,
                      child: parsedJson != null
                          ? TabBarView(
                              children: [
                                _buildJsonView(
                                  dialogContext,
                                  title: 'Schema App_Quan_ly_chi_tieu_ca_nhan',
                                  jsonString: parsedJson,
                                ),
                                _buildJsonView(
                                  dialogContext,
                                  title: 'Android Notification Payload',
                                  jsonString: rawJson,
                                ),
                              ],
                            )
                          : _buildJsonView(
                              dialogContext,
                              title: 'Android Notification Payload',
                              jsonString: rawJson,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (parsedJson != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Sao chép Parsed JSON'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: parsedJson));
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép Parsed JSON vào bộ nhớ tạm!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            FilledButton.icon(
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Sao chép Tất cả'),
              onPressed: () {
                final allData = {
                  'rawNotification': notification.toMap(),
                  if (parsedTransaction != null)
                    'parsedTransaction': parsedTransaction!.toMap(),
                };
                Clipboard.setData(ClipboardData(
                  text: const JsonEncoder.withIndent('  ').convert(allData),
                ));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép toàn bộ dữ liệu vào bộ nhớ tạm!'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJsonView(
    BuildContext context, {
    required String title,
    required String jsonString,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141419) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: jsonString));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã sao chép $title!'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                jsonString,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
