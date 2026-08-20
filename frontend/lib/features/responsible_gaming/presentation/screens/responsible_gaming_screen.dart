import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/responsible_gaming_provider.dart';

class ResponsibleGamingScreen extends ConsumerStatefulWidget {
  const ResponsibleGamingScreen({super.key});

  @override
  ConsumerState<ResponsibleGamingScreen> createState() =>
      _ResponsibleGamingScreenState();
}

class _ResponsibleGamingScreenState
    extends ConsumerState<ResponsibleGamingScreen> {
  final _dailyController = TextEditingController();
  final _singleController = TextEditingController();

  @override
  void dispose() {
    _dailyController.dispose();
    _singleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(responsibleGamingProvider).valueOrNull ??
        const ResponsibleGamingSettings.defaults();
    return Scaffold(
      appBar: AppBar(title: const Text('Responsible Gaming')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Card(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Set limits that help you keep betting within a budget. These local controls are applied before a bet is submitted and do not require manual approval.',
                style: TextStyle(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _limitCard(
            title: 'Daily stake limit',
            value: settings.dailyStakeLimit,
            controller: _dailyController,
            onSave: () => _saveLimit(
              _dailyController,
              (value) => ref
                  .read(responsibleGamingProvider.notifier)
                  .setDailyStakeLimit(value),
            ),
          ),
          const SizedBox(height: 12),
          _limitCard(
            title: 'Single-bet limit',
            value: settings.singleBetLimit,
            controller: _singleController,
            onSave: () => _saveLimit(
              _singleController,
              (value) => ref
                  .read(responsibleGamingProvider.notifier)
                  .setSingleBetLimit(value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Take a break',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  Text(
                    settings.isCoolOffActive
                        ? 'Cool-off active until ${settings.coolOffUntil!.toLocal()}'
                        : 'Pause bet placement for a short period.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _breakButton('1 hour', const Duration(hours: 1)),
                      _breakButton('24 hours', const Duration(hours: 24)),
                      _breakButton('7 days', const Duration(days: 7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Self-exclusion',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  Text(
                    settings.isSelfExcluded
                        ? 'Self-exclusion active until ${settings.selfExcludedUntil!.toLocal()}'
                        : 'Block bet placement for a longer period.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(responsibleGamingProvider.notifier)
                        .startSelfExclusion(const Duration(days: 30)),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Self-exclude for 30 days'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(responsibleGamingProvider.notifier).clearLimits();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Local limits cleared.')),
              );
            },
            child: const Text('Clear local limits'),
          ),
        ],
      ),
    );
  }

  Widget _limitCard({
    required String title,
    required double? value,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              value == null
                  ? 'No limit set'
                  : '${value.toStringAsFixed(0)} MMK',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Limit in MMK',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: onSave, child: const Text('Save limit')),
          ],
        ),
      ),
    );
  }

  Widget _breakButton(String label, Duration duration) {
    return OutlinedButton(
      onPressed: () =>
          ref.read(responsibleGamingProvider.notifier).startCoolOff(duration),
      child: Text(label),
    );
  }

  Future<void> _saveLimit(
    TextEditingController controller,
    Future<void> Function(double?) save,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = controller.text.trim();
    final value = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && (value == null || value <= 0)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid positive MMK limit.')),
      );
      return;
    }
    await save(value);
    if (!mounted) return;
    controller.clear();
    messenger.showSnackBar(
      const SnackBar(content: Text('Responsible-gaming limit saved.')),
    );
  }
}
