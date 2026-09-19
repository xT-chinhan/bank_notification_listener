import 'package:flutter/material.dart';
import '../models/raw_notification.dart';
import '../services/mock_bank_samples.dart';
import '../services/notification_bridge.dart';

/// BottomSheet that lets users select and inject realistic mock banking notifications
/// into the live NotificationBridge stream for instantaneous verification.
class SimulationSheet extends StatefulWidget {
  const SimulationSheet({super.key});

  /// Helper static method to display the simulation sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SimulationSheet(),
    );
  }

  @override
  State<SimulationSheet> createState() => _SimulationSheetState();
}

class _SimulationSheetState extends State<SimulationSheet> {
  int _selectedFilterIndex = 0; // 0: All, 1: Banks only, 2: Non-banks

  List<RawNotification> get _filteredSamples {
    switch (_selectedFilterIndex) {
      case 1:
        return MockBankSamples.bankSamples;
      case 2:
        return MockBankSamples.nonBankSamples;
      default:
        return MockBankSamples.samples;
    }
  }

  void _inject(RawNotification sample) {
    // Generate a unique ID and current timestamp so it appears right at the top as newly received
    final simulated = sample.copyWith(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}_${sample.id}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    NotificationBridge.instance.injectSimulatedNotification(simulated);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã giả lập thông báo từ ${sample.title}!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _injectAll() async {
    Navigator.pop(context);
    final bankSamples = MockBankSamples.bankSamples;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang bắn tuần tự ${bankSamples.length} mẫu ngân hàng...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    for (int i = 0; i < bankSamples.length; i++) {
      final sample = bankSamples[i];
      final simulated = sample.copyWith(
        id: 'sim_all_${DateTime.now().millisecondsSinceEpoch}_$i',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      NotificationBridge.instance.injectSimulatedNotification(simulated);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final samples = _filteredSamples;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181820) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bộ Giả Lập Thông Báo',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Chọn mẫu để test tức thì trên màn hình',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _injectAll,
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Bắn Tất Cả'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Segmented Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterTab(0, 'Tất cả (${MockBankSamples.samples.length})'),
                const SizedBox(width: 8),
                _buildFilterTab(1, 'Ngân hàng (${MockBankSamples.bankSamples.length})'),
                const SizedBox(width: 8),
                _buildFilterTab(2, 'Khác (${MockBankSamples.nonBankSamples.length})'),
              ],
            ),
          ),

          const Divider(height: 20),

          // List of Mock Samples
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: samples.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = samples[index];
                return _buildSampleTile(context, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSampleTile(BuildContext context, RawNotification sample) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine sample accent color & icons
    final title = sample.title.toLowerCase();
    Color accentColor = Colors.teal;
    IconData icon = Icons.account_balance_rounded;

    if (title.contains('vietcombank')) {
      accentColor = const Color(0xFF006633);
    } else if (title.contains('mb')) {
      accentColor = const Color(0xFF002B7F);
    } else if (title.contains('techcombank')) {
      accentColor = const Color(0xFFE51A24);
    } else if (title.contains('vpbank')) {
      accentColor = const Color(0xFF00965E);
    } else if (title.contains('acb')) {
      accentColor = const Color(0xFF005696);
    } else if (title.contains('tpbank')) {
      accentColor = const Color(0xFF7B1FA2);
    } else if (title.contains('bidv')) {
      accentColor = const Color(0xFF007236);
    } else if (title.contains('momo')) {
      accentColor = const Color(0xFFA50064);
      icon = Icons.account_balance_wallet_rounded;
    } else if (!sample.isBankNotification) {
      accentColor = Colors.grey;
      icon = Icons.notifications_none_rounded;
    }

    // Identify credit vs debit indicator from text
    final isCredit = sample.text.contains('+') || sample.text.contains('nhận');
    final isDebit = sample.text.contains('-') || sample.text.contains('thanh toán') || sample.text.contains('giam');

    return Material(
      color: isDark ? const Color(0xFF22222C) : const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _inject(sample),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sample.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isCredit)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '+ THU',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else if (isDebit)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '- CHI',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sample.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
