import 'dart:async';

import 'package:flutter/material.dart';
import '../models/parsed_transaction.dart';
import '../models/raw_notification.dart';
import '../services/bank_notification_parser.dart';
import '../services/notification_bridge.dart';
import '../widgets/transaction_card.dart';

/// Ultra-premium responsive Bank Notification Monitor screen.
/// Implements adaptive responsive constraints so it maintains a perfect mobile
/// form factor on all devices and screen sizes (phones, tablets, and desktop Chrome).
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isCheckingPermission = true;
  bool _isIgnoringBattery = true;

  final List<RawNotification> _notifications = [];
  final Map<String, ParsedTransaction?> _parsedCache = {};

  StreamSubscription<RawNotification>? _subscription;

  bool _dialogShownOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission(promptIfDenied: true);
    _checkBatteryOptimization();
    _loadSavedNotifications();
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
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      _checkBatteryOptimization();
      _loadSavedNotifications();
    }
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      final ignoring =
          await NotificationBridge.instance.isIgnoringBatteryOptimizations();
      if (mounted) {
        setState(() => _isIgnoringBattery = ignoring);
      }
    } catch (_) {}
  }

  Future<void> _loadSavedNotifications() async {
    try {
      final saved = await NotificationBridge.instance.getSavedNotifications();
      if (!mounted || saved.isEmpty) return;
      setState(() {
        for (final item in saved) {
          final isDup = _notifications.any((n) =>
              n.packageName == item.packageName &&
              n.title.trim() == item.title.trim() &&
              n.text.trim() == item.text.trim() &&
              (n.timestamp - item.timestamp).abs() < 2000);
          if (!isDup) {
            _notifications.add(item);
            _parsedCache[item.id] = BankNotificationParser.parse(item);
          }
        }
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
    } catch (e) {
      debugPrint('Error loading saved notifications: $e');
    }
  }

  Future<void> _checkPermission({bool promptIfDenied = false}) async {
    setState(() => _isCheckingPermission = true);
    try {
      final granted = await NotificationBridge.instance.isPermissionGranted();
      if (mounted) {
        setState(() {
          _isPermissionGranted = granted;
          _isCheckingPermission = false;
        });
        if (!granted && promptIfDenied && !_dialogShownOnce) {
          _dialogShownOnce = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isPermissionGranted) {
              _promptInitialPermissionDialog();
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingPermission = false);
      }
    }
  }

  void _promptInitialPermissionDialog() {
    _showThreeStepPermissionPopup(context);
  }

  /// Deduplicate notifications by package, title, and text content (sorted newest first)
  List<RawNotification> get _uniqueNotifications {
    final seen = <String>{};
    final list = <RawNotification>[];
    for (final n in _notifications) {
      final key = '${n.packageName}|${n.title.trim()}|${n.text.trim()}';
      if (seen.add(key)) {
        list.add(n);
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  void _subscribeToStream() {
    _subscription =
        NotificationBridge.instance.notificationStream.listen((notification) {
      final parsed = BankNotificationParser.parse(notification);
      if (mounted) {
        setState(() {
          // Remove any existing duplicate notification with identical content
          _notifications.removeWhere((n) =>
              n.packageName == notification.packageName &&
              n.title.trim() == notification.title.trim() &&
              n.text.trim() == notification.text.trim());
          _notifications.insert(0, notification);
          _parsedCache[notification.id] = parsed;
        });
      }
    });
  }

  void _confirmClearAll() {
    if (_notifications.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Xóa toàn bộ lịch sử?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Thao tác này sẽ xóa sạch ${_notifications.length} thông báo hiện có trên màn hình.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              NotificationBridge.instance.clearSavedNotifications();
              setState(() {
                _notifications.clear();
                _parsedCache.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Đã xóa toàn bộ lịch sử thông báo'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Xóa tất cả', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 620;

        return Scaffold(
          backgroundColor: isWideScreen
              ? (isDark ? const Color(0xFF070A10) : const Color(0xFFE2E8F0))
              : theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: isWideScreen
                        ? [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.7)
                                  : Colors.black.withValues(alpha: 0.12),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      // Header Section
                      _buildHeader(context),

                      // Status & Permission Banner (Active 24/7 or Grant Permission)
                      _buildPermissionWidget(context),

                      const SizedBox(height: 6),

                      // Stream list of cards or clean empty state (deduplicated)
                      Expanded(
                        child: () {
                          final displayList = _uniqueNotifications;
                          return displayList.isEmpty
                              ? _buildEmptyState(context)
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(top: 4, bottom: 30),
                                  itemCount: displayList.length,
                                  itemBuilder: (context, index) {
                                    final notification = displayList[index];
                                    final parsed = _parsedCache[notification.id];
                                    return TransactionCard(
                                      key: ValueKey(notification.id),
                                      notification: notification,
                                      parsedTransaction: parsed,
                                    );
                                  },
                                );
                        }(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Elegant Header with Title and Settings Icon
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'chinhan-xT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    letterSpacing: -0.8,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quản lý chi tiêu cá nhân',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Delete History Button (if items exist)
          if (_notifications.isNotEmpty)
            _buildRoundActionButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Xóa lịch sử',
              onTap: _confirmClearAll,
              isDark: isDark,
            ),

          if (_notifications.isNotEmpty) const SizedBox(width: 8),

          // Settings Button (opens permission & settings sheet)
          _buildRoundActionButton(
            icon: Icons.tune_rounded,
            tooltip: 'Cài đặt & Quyền',
            onTap: () => _showSettingsSheet(context),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  /// 2.5D Round Icon Action Button
  Widget _buildRoundActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0x0A0F172A),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
        onPressed: onTap,
      ),
    );
  }

  /// Permission status indicator & Interactive Banner
  Widget _buildPermissionWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isCheckingPermission) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đang kiểm tra quyền thông báo...',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Permission is GRANTED: sleek 2.5D active listening pill
    if (_isPermissionGranted) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF064E3B), Color(0xFF062E25)]
                : const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.4 : 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF10B981),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chạy ngầm 24/7 (Đang hoạt động)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.1,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!_isIgnoringBattery) ...[
              InkWell(
                onTap: () => _showBackgroundGuideSheet(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFD97706)),
                      const SizedBox(width: 2),
                      Text(
                        'Tối ưu pin',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            InkWell(
              onTap: () => _showBackgroundGuideSheet(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  size: 19,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Permission NOT GRANTED: 2.5D action card with working grant button
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF3B1E08), Color(0xFF281305)]
              : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_paused_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Chưa bật quyền thông báo',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
              icon: const Icon(Icons.touch_app_rounded, size: 18),
              label: const Text(
                'Cấp Quyền Ngay (3 Bước Đơn Giản)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
              ),
              onPressed: () => _showThreeStepPermissionPopup(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Ultra-clean minimal empty state (waiting for live notifications)
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
                      : const [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0x140F172A),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                size: 36,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Đang chờ thông báo mới...',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Settings & Permissions Bottom Sheet
  void _showSettingsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cài Đặt & Quyền Hệ Thống',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Permission Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isPermissionGranted
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          color: _isPermissionGranted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Quyền Đọc Thông Báo (Notification Access)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isPermissionGranted
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _isPermissionGranted ? 'ĐÃ BẬT' : 'CHƯA CẤP',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              color: _isPermissionGranted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Open Settings Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                        label: const Text(
                          'Mở Cài Đặt Hệ Thống Android',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          NotificationBridge.instance.openSettings();
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Refresh Permission Check Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Kiểm Tra Lại Trạng Thái',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: () {
                          _checkPermission();
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Unlock Restricted Settings Button (for Android 13+)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.touch_app_rounded, size: 16),
                        label: const Text(
                          'Xem 3 bước kích hoạt quyền (Android 13+)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showThreeStepPermissionPopup(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Privacy & Security Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 20, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ứng dụng chỉ nhận diện thông báo biến động số dư để ghi nhận chi tiêu cá nhân. Dữ liệu xử lý an toàn nội bộ trên thiết bị.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_notifications.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    label: const Text(
                      'Xóa Toàn Bộ Lịch Sử Thông Báo',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _confirmClearAll();
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  /// Friendly 3-step popup to activate notification permissions
  void _showThreeStepPermissionPopup(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 36,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kích hoạt trong 3 bước',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17.5,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Thực hiện 3 bước để app hoạt động tốt nhé ✨',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                  const SizedBox(height: 16),

                  // Step 1
                  _buildFriendlyStepCard(
                    number: '1',
                    title: 'Bạn cần vào Thông tin ứng dụng',
                    subtitle: 'Bấm nút màu xanh bên dưới để vào thẳng trang cài đặt của chinhan-xT.',
                    icon: Icons.touch_app_rounded,
                    isDark: isDark,
                  ),

                  // Step 2
                  _buildFriendlyStepCard(
                    number: '2',
                    title: 'Cho phép cài đặt bị hạn chế',
                    subtitle: 'Bấm vào biểu tượng dấu 3 chấm (⋮) ở góc trên bên phải màn hình và chọn "Cho phép cài đặt bị hạn chế".',
                    icon: Icons.more_vert_rounded,
                    isDark: isDark,
                  ),

                  // Step 3
                  _buildFriendlyStepCard(
                    number: '3',
                    title: 'Khởi động lại app và cấp quyền ngay',
                    subtitle: 'Mở lại app chinhan-xT và gạt bật quyền thông báo để app bắt đầu ghi nhận giao dịch.',
                    icon: Icons.check_circle_rounded,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 16),

                  // Button 1: Open App Details
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Bước 1: Mở Thông Tin Ứng Dụng Ngay',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        NotificationBridge.instance.openAppDetails();
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Button 2: Direct Open Notification Settings
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 18),
                      label: const Text(
                        'Bước 3: Mở Màn Hình Bật Quyền Hệ Thống',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        NotificationBridge.instance.openSettings();
                      },
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

  Widget _buildFriendlyStepCard({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Icon(icon, size: 16, color: const Color(0xFF10B981)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBackgroundGuideSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cấu Hình Chạy Ngầm 24/7',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đảm bảo ứng dụng bắt thông báo ngay cả khi tắt app',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Item 1: Foreground Service
                  _buildGuideActionCard(
                    isDark: isDark,
                    title: 'Dịch vụ Chạy Ngầm (Foreground Service)',
                    desc: 'Dịch vụ đang ghim thông báo trên khay trạng thái để Android không kill ứng dụng.',
                    icon: Icons.shield_rounded,
                    statusText: 'Đang hoạt động',
                    isOk: true,
                    btnText: 'Khởi động lại',
                    onAction: () async {
                      await NotificationBridge.instance.startForegroundService();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Đã kích hoạt lại Dịch vụ Chạy Ngầm'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),

                  // Item 2: Battery Optimization
                  _buildGuideActionCard(
                    isDark: isDark,
                    title: 'Tối Ưu Hóa Pin (Doze Mode)',
                    desc: _isIgnoringBattery
                        ? 'Đã bật chế độ Không hạn chế pin. Ứng dụng sẽ không bị Android đóng băng khi tắt màn hình.'
                        : 'Cần cấp quyền Bỏ qua tối ưu pin để CPU không bị ngắt kết nối khi điện thoại ngủ sâu.',
                    icon: Icons.battery_charging_full_rounded,
                    statusText: _isIgnoringBattery ? 'Đã tắt tối ưu (Tốt)' : 'Chưa tắt tối ưu',
                    isOk: _isIgnoringBattery,
                    btnText: 'Tắt tối ưu pin ngay',
                    onAction: () async {
                      await NotificationBridge.instance.requestIgnoreBatteryOptimizations();
                      await Future<void>.delayed(const Duration(milliseconds: 500));
                      _checkBatteryOptimization();
                    },
                  ),

                  // Item 3: Autostart (Xiaomi, Oppo, Vivo, Samsung)
                  _buildGuideActionCard(
                    isDark: isDark,
                    title: 'Tự Khởi Chạy (Autostart)',
                    desc: 'Trên máy Xiaomi (HyperOS/MIUI), Oppo, Vivo, Samsung, bật quyền này để app tự khởi động lại khi reboot.',
                    icon: Icons.power_settings_new_rounded,
                    statusText: 'Cài đặt của hãng',
                    isOk: true,
                    btnText: 'Mở Cài Đặt Tự Khởi Chạy',
                    onAction: () {
                      NotificationBridge.instance.openAutostartSettings();
                    },
                  ),

                  // Item 4: Lock App tip
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF0F766E)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mẹo Khóa App trong Đa Nhiệm (Recent Apps)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Mở màn hình đa nhiệm (Recent Apps) ➔ Nhấn giữ ứng dụng chinhan-xT ➔ Chọn biểu tượng Ổ Khóa 🔒 để không bị nút "Xóa tất cả" dọn sạch.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text(
                        'Đã Hiểu & Hoàn Tất',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
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

  Widget _buildGuideActionCard({
    required bool isDark,
    required String title,
    required String desc,
    required IconData icon,
    required String statusText,
    required bool isOk,
    required String btnText,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOk
              ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFA7F3D0))
              : (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: isOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOk
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                      : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isOk ? const Color(0xFF10B981) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
              ),
              onPressed: onAction,
              child: Text(
                btnText,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

