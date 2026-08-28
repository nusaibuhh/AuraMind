import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/savoring_log.dart';
import '../../providers/savoring_provider.dart';

class SavoringHistoryScreen extends StatefulWidget {
  const SavoringHistoryScreen({super.key});

  @override
  State<SavoringHistoryScreen> createState() => _SavoringHistoryScreenState();
}

class _SavoringHistoryScreenState extends State<SavoringHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavoringProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavoringProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Past reflections')),
      body: RefreshIndicator(
        onRefresh: provider.loadHistory,
        child: provider.isHistoryLoading && provider.history.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.history.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(28),
                    children: [
                      const SizedBox(height: 100),
                      Icon(
                        provider.error == null
                            ? Icons.auto_awesome_outlined
                            : Icons.cloud_off_rounded,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.65),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        provider.error ??
                            'Completed reflections will appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    itemCount: provider.history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _HistoryLogCard(log: provider.history[index]),
                  ),
      ),
    );
  }
}

class _HistoryLogCard extends StatelessWidget {
  const _HistoryLogCard({required this.log});

  final SavoringLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 9),
              Text(
                _readableDate(log.logDate),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in log.entries) ...[
            _HistoryEntry(entry: entry),
            if (entry.position != log.entries.last.position)
              const Divider(height: 24),
          ],
        ],
      ),
    );
  }

  String _readableDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final SavoringEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            '${entry.position}',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.positiveEvent,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'What helped: ${entry.whyHappened}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
