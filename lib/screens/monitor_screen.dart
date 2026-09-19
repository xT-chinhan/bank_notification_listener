import 'dart:async';
import 'package:flutter/material.dart';
import '../models/parsed_transaction.dart';
import '../models/raw_notification.dart';
import '../services/bank_notification_parser.dart';
import '../services/notification_bridge.dart';
import '../widgets/simulation_sheet.dart';
import '../widgets/transaction_card.dart';

/// Main monitoring dashboard screen that captures and displays incoming notifications
/// in real time, parses financial transactions, and provides simulation testing tools.
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isCheckingPermission = true;
  bool _onlyBankFilter = false;

  final List<RawNotification> _notifications = [];
  final Map<String, ParsedTransaction?> _parsedCache = {};

  StreamSubscription<RawNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _subscribeToStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user switches back to this app after opening Android settings,
    // automatically re-check whether notification listener permission was granted.
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);
    try {
      final granted = await NotificationBridge.instance.isPermissionGranted();
      if (mounted) {
        setState(() {
          _isPermissionGranted = granted;
          _isCheckingPermission = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingPermission = false);
      }
    }
  }

  void _subscribeToStream() {
    _subscription =
        NotificationBridge.instance.notificationStream.listen((notification) {
      final parsed = BankNotificationParser.parse(notification);
      if (mounted) {
        setState(() {
          // Keep newest notifications at index 0 (top of the list)
          _notifications.insert(0, notification);
          _parsedCache[notification.id] = parsed;
        });
      }
    });
  }

  List<RawNotification> get _filteredList {
    if (!_onlyBankFilter) return _notifications;
    return _notifications.where((n) {
      return _parsedCache[n.id] != null ||
          n.isBankNotification ||
          BankNotificationParser.isBankApp(n.packageName, n.title, n.text);
    }).toList();
  }

  int get _bankCount {
    return _notifications.where((n) {
      return _parsedCache[n.id] != null ||
          n.isBankNotification ||
          BankNotificationParser.isBankApp(n.packageName, n.title, n.text);
    }).length;
  }

  void _confirmClearAll() {
    if (_notifications.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa toàn bộ lịch sử?'),
        content: Text(
          'Thao tác này sẽ xóa tất cả ${_notifications.length} thông báo hiện có trên màn hình.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() {
                _notifications.clear();
                _parsedCache.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa toàn bộ lịch sử thông báo'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filteredList;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bank Notification Monitor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Lắng nghe & bóc tách giao dịch ngân hàng',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới quyền',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkPermission,
          ),
          IconButton(
            tooltip: 'Cài đặt quyền',
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: () => NotificationBridge.instance.openSettings(),
          ),
          if (_notifications.isNotEmpty)
            IconButton(
              tooltip: 'Xóa lịch sử',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Banner (Permission State)
            _buildPermissionBanner(context),

            // Filter Bar
            _buildFilterBar(context),

            const Divider(height: 1),

            // Notification List or Empty State
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 90),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final notification = items[index];
                        final parsed = _parsedCache[notification.id];
                        return TransactionCard(
                          key: ValueKey(notification.id),
                          notification: notification,
                          parsedTransaction: parsed,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_simulate',
        icon: const Icon(Icons.science_rounded, size: 22),
        label: const Text(
          'Test Giả Lập Ngân Hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => SimulationSheet.show(context),
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isCheckingPermission) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Đang kiểm tra quyền đọc thông báo...',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_isPermissionGranted) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0D2818).withValues(alpha: 0.9)
              : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🟢 Đang lắng nghe thông báo hệ thống',
                style: TextStyle(
                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _checkPermission,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Permission not granted warning banner
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => NotificationBridge.instance.openSettings(),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF3B1E08).withValues(alpha: 0.9)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEA580C),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Chưa cấp quyền đọc thông báo',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bấm vào đây để mở Cài đặt và bật quyền cho ứng dụng.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFFC2410C),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => NotificationBridge.instance.openSettings(),
                child: const Text(
                  'Cấp quyền',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          FilterChip(
            selected: !_onlyBankFilter,
            showCheckmark: false,
            avatar: Icon(
              Icons.all_inbox_rounded,
              size: 16,
              color: !_onlyBankFilter
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.primary,
            ),
            label: Text('Tất cả thông báo (${_notifications.length})'),
            onSelected: (selected) {
              if (selected) setState(() => _onlyBankFilter = false);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: _onlyBankFilter,
            showCheckmark: false,
            avatar: Icon(
              Icons.account_balance_rounded,
              size: 16,
              color: _onlyBankFilter
                  ? Theme.of(context).colorScheme.onPrimary
                  : Colors.teal,
            ),
            label: Text('Chỉ ngân hàng ($_bankCount)'),
            onSelected: (selected) {
              setState(() => _onlyBankFilter = selected);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _onlyBankFilter
                    ? Icons.account_balance_outlined
                    : Icons.notifications_none_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _onlyBankFilter
                  ? 'Chưa có thông báo ngân hàng nào'
                  : 'Chưa nhận được thông báo nào',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _onlyBankFilter
                  ? 'Khi có biến động số dư từ Vietcombank, MB, Techcombank... thông báo sẽ xuất hiện tại đây.'
                  : 'Ứng dụng đang chạy nền và sẵn sàng nhận thông báo.\nBạn cũng có thể bấm nút bên dưới để test ngay.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.science_rounded, size: 18),
              label: const Text('Bấm Để Test Giả Lập'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => SimulationSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
