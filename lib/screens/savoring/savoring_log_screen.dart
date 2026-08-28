import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/savoring_log.dart';
import '../../providers/savoring_provider.dart';
import 'savoring_history_screen.dart';

class SavoringLogScreen extends StatefulWidget {
  const SavoringLogScreen({super.key});

  @override
  State<SavoringLogScreen> createState() => _SavoringLogScreenState();
}

class _SavoringLogScreenState extends State<SavoringLogScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  final List<TextEditingController> _eventControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _whyControllers =
      List.generate(3, (_) => TextEditingController());
  int _currentPage = 0;
  String? _boundLogId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<SavoringProvider>();
      await provider.loadToday();
      if (mounted) _bindControllers(provider.todayLog);
    });
  }

  void _bindControllers(SavoringLog? log) {
    if (log == null || _boundLogId == log.id) return;
    _boundLogId = log.id;
    for (var index = 0; index < 3; index++) {
      final entry = log.entries.firstWhere(
        (item) => item.position == index + 1,
        orElse: () => SavoringEntry(
          position: index + 1,
          positiveEvent: '',
          whyHappened: '',
        ),
      );
      _eventControllers[index].text = entry.positiveEvent;
      _whyControllers[index].text = entry.whyHappened;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _eventControllers) {
      controller.dispose();
    }
    for (final controller in _whyControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveDraft() async {
    FocusScope.of(context).unfocus();
    final saved = await context.read<SavoringProvider>().saveDraft();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Your draft is saved privately.'
            : context.read<SavoringProvider>().error ?? 'Could not save yet.'),
      ),
    );
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<SavoringProvider>();
    final firstIncomplete =
        provider.todayLog?.entries.indexWhere((entry) => !entry.isComplete) ??
            -1;
    if (firstIncomplete >= 0) {
      await _pageController.animateToPage(
        firstIncomplete,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    final completed = await provider.complete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(completed
            ? 'Your three good things are saved for today.'
            : provider.error ?? 'Could not finish your reflection yet.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<SavoringProvider>();
    final log = provider.todayLog;
    _bindControllers(log);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Three Good Things'),
        actions: [
          IconButton(
            tooltip: 'Reflection history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SavoringHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: provider.isTodayLoading && log == null
            ? const Center(child: CircularProgressIndicator())
            : log == null
                ? _LoadError(
                    message:
                        provider.error ?? 'Could not open your reflection.',
                    onRetry: provider.loadToday,
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
                        child: Column(
                          children: [
                            Icon(
                              log.isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.auto_awesome_rounded,
                              color: log.isCompleted
                                  ? const Color(0xFF4E8463)
                                  : const Color(0xFFD49A37),
                              size: 30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              log.isCompleted
                                  ? 'Today’s reflection is complete'
                                  : 'Small moments count',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              log.isCompleted
                                  ? 'You can revisit each card, or look back through your history.'
                                  : 'Write what felt good or meaningful, then notice what helped it happen.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: 3,
                          onPageChanged: (value) =>
                              setState(() => _currentPage = value),
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                var distance = 0.0;
                                if (_pageController.hasClients &&
                                    _pageController.position.haveDimensions) {
                                  distance = ((_pageController.page ??
                                              _currentPage.toDouble()) -
                                          index)
                                      .abs()
                                      .clamp(0.0, 1.0);
                                }
                                return Transform.scale(
                                  scale: 1 - (distance * 0.045),
                                  child: Opacity(
                                    opacity: 1 - (distance * 0.18),
                                    child: child,
                                  ),
                                );
                              },
                              child: _ReflectionCard(
                                index: index,
                                readOnly: log.isCompleted,
                                eventController: _eventControllers[index],
                                whyController: _whyControllers[index],
                                onEventChanged: (value) => provider.updateEntry(
                                  index + 1,
                                  positiveEvent: value,
                                ),
                                onWhyChanged: (value) => provider.updateEntry(
                                  index + 1,
                                  whyHappened: value,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Card ${_currentPage + 1} of 3',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            final selected = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: selected ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            );
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        child: log.isCompleted
                            ? SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const SavoringHistoryScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('View past reflections'),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          provider.isSaving ? null : _saveDraft,
                                      child: const Text('Save for later'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed:
                                          provider.isSaving ? null : _finish,
                                      icon: provider.isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.check_rounded),
                                      label: const Text('Finish'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.index,
    required this.readOnly,
    required this.eventController,
    required this.whyController,
    required this.onEventChanged,
    required this.onWhyChanged,
  });

  final int index;
  final bool readOnly;
  final TextEditingController eventController;
  final TextEditingController whyController;
  final ValueChanged<String> onEventChanged;
  final ValueChanged<String> onWhyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      const Color(0xFFFFF1D6),
      const Color(0xFFE8F3E8),
      const Color(0xFFECE7F8),
    ];
    final accents = [
      const Color(0xFFC88722),
      const Color(0xFF4E8463),
      const Color(0xFF7962A7),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: colors[index],
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accents[index].withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accents[index].withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: accents[index],
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Good thing ${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, color: accents[index]),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              key: Key('savoring-event-${index + 1}'),
              controller: eventController,
              readOnly: readOnly,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              onChanged: onEventChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'What good thing happened?',
                'Be specific—even a quiet cup of tea counts.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: Key('savoring-why-${index + 1}'),
              controller: whyController,
              readOnly: readOnly,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              onChanged: onWhyChanged,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'What helped this happen?',
                'A choice, a person, timing, effort, or simple chance.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.82),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
