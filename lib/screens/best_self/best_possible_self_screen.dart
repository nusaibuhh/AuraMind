import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/best_self_vision.dart';
import '../../providers/auth_provider.dart';

class BestPossibleSelfScreen extends StatefulWidget {
  const BestPossibleSelfScreen({super.key, this.initialVision});

  final String? initialVision;

  @override
  State<BestPossibleSelfScreen> createState() => _BestPossibleSelfScreenState();
}

class _BestPossibleSelfScreenState extends State<BestPossibleSelfScreen> {
  static const _accent = Color(0xFF5E8C76);
  final _visionController = TextEditingController();
  final Map<String, TextEditingController> _areaControllers = {
    for (final area in _areas) area.title: TextEditingController(),
  };
  int _step = 0;
  int _timeline = 3;

  static const _areas = [
    _Area('Career & Growth', 'What are you doing? What have you achieved?', Icons.work_outline, Color(0xFFE4F0EA)),
    _Area('Relationships', 'Who is in your life? How are your connections?', Icons.favorite_border, Color(0xFFFFECE8)),
    _Area('Health & Well-being', 'How do you feel physically and mentally?', Icons.eco_outlined, Color(0xFFE7F1E8)),
    _Area('Lifestyle & Environment', 'Where do you live? What does your daily life look like?', Icons.home_outlined, Color(0xFFF0ECF8)),
    _Area('Personal Growth', 'What have you learned? Who have you become?', Icons.star_outline, Color(0xFFFFF2D7)),
  ];

  @override
  void initState() {
    super.initState();
    _visionController.text = widget.initialVision ?? '';
  }

  @override
  void dispose() {
    _visionController.dispose();
    for (final controller in _areaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step == 2 && _visionController.text.trim().isEmpty) {
      _showMessage('Write a few words about the future you imagine.');
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  String get _summary {
    final highlights = _areaControllers.entries
        .where((entry) => entry.value.text.trim().isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value.text.trim()}')
        .join('\n');
    return [_visionController.text.trim(), highlights]
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }

  Future<void> _save() async {
    final vision = _summary;
    final savedVision = BestSelfVision(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timeline: _timeline,
      vision: vision,
      createdAt: DateTime.now(),
    );
    try {
      await context.read<AuthProvider>().api.saveBestSelfVision(savedVision);
    } catch (_) {
      _showMessage('Your vision could not be saved. Check that the backend is running.');
      return;
    }
    if (!mounted) return;
    setState(() => _step = 5);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editArea(_Area area) async {
    final controller = _areaControllers[area.title]!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(area.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(area.prompt),
            const SizedBox(height: 16),
            TextField(controller: controller, maxLines: 4, autofocus: true, decoration: const InputDecoration(hintText: 'Write freely...', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Save highlight'))),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      0 => _intro(),
      1 => _timelinePage(),
      2 => _visionPage(),
      3 => _areasPage(),
      4 => _reviewPage(),
      _ => _completePage(),
    };
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(child: page),
    );
  }

  Widget _shell({required Widget child, bool showProgress = true}) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    child: Column(
      children: [
        Row(children: [IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)), if (showProgress) ...[const SizedBox(width: 10), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (_step - 1) / 4, minHeight: 9, color: _accent, backgroundColor: const Color(0xFFECEDEB)))), const SizedBox(width: 14), Text('$_step of 5', style: const TextStyle(color: Color(0xFF53615C)))]]),
        const SizedBox(height: 20),
        Expanded(child: child),
      ],
    ),
  );

  Widget _intro() => _shell(
    showProgress: false,
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Spacer(),
      Container(height: 146, width: 146, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEAF2EB)), child: const Icon(Icons.wb_sunny_outlined, size: 72, color: Color(0xFFD9AD52))),
      const SizedBox(height: 30),
      const Text('Best Possible Self ✨', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      const Text('Imagine a future where\neverything has gone ideally.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.45)),
      const SizedBox(height: 32),
      const _InfoLine(Icons.schedule_outlined, 'Takes about 10–15 minutes'),
      const SizedBox(height: 14),
      const _InfoLine(Icons.sentiment_satisfied_alt_outlined, 'Best used when you’re feeling good or hopeful'),
      const Spacer(),
      _primaryButton('Begin', _next),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Maybe later', style: TextStyle(color: _accent))),
    ]),
  );

  Widget _timelinePage() => _shell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Choose your timeline', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
    const SizedBox(height: 10),
    const Text('How far into the future would you like to imagine?', style: TextStyle(color: Color(0xFF53615C), fontSize: 16)),
    const SizedBox(height: 22),
    for (final item in const [(1, '1 Year', 'A short-term ideal future'), (2, '2 Years', 'A bit more growth and progress'), (3, '3 Years', 'A balanced future vision'), (5, '5 Years', 'A big-picture ideal future')]) ...[
      _timelineOption(item.$1, item.$2, item.$3), const SizedBox(height: 10),
    ],
    const Spacer(),
    _primaryButton('Continue', _next),
  ]));

  Widget _timelineOption(int value, String title, String subtitle) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => setState(() => _timeline = value),
    child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _timeline == value ? const Color(0xFFF1F6F1) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _timeline == value ? _accent : const Color(0xFFE1E2DF))), child: Row(children: [Icon(_timeline == value ? Icons.radio_button_checked : Icons.radio_button_off, color: _timeline == value ? _accent : const Color(0xFFB7BBB7)), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF53615C)))])])),
  );

  Widget _visionPage() => _shell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Center(child: Icon(Icons.eco_outlined, color: _accent, size: 40)),
    const SizedBox(height: 18),
    const Center(child: Text('Let’s imagine your\nbest future', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700))),
    const SizedBox(height: 12),
    Center(child: Text('Where are you in $_timeline years?\nWhat does your life look like?', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF53615C), height: 1.45))),
    const SizedBox(height: 24),
    Expanded(child: TextField(controller: _visionController, maxLines: null, expands: true, maxLength: 1000, textAlignVertical: TextAlignVertical.top, decoration: InputDecoration(hintText: 'Write freely...', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE1E2DF)))))),
    const SizedBox(height: 16), _primaryButton('Continue', _next),
  ]));

  Widget _areasPage() => _shell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Explore different areas', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    const Text('Share a few highlights in each area.', style: TextStyle(color: Color(0xFF53615C))),
    const SizedBox(height: 16),
    Expanded(child: ListView.separated(itemCount: _areas.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, index) { final area = _areas[index]; final complete = _areaControllers[area.title]!.text.trim().isNotEmpty; return InkWell(onTap: () => _editArea(area), borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE7E8E5))), child: Row(children: [CircleAvatar(backgroundColor: area.color, child: Icon(area.icon, color: _accent)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(area.title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(complete ? 'Highlight added' : area.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF53615C)))])), Icon(complete ? Icons.check_circle : Icons.chevron_right, color: complete ? _accent : const Color(0xFF53615C))]))); })),
    _primaryButton('Continue', _next),
  ]));

  Widget _reviewPage() => _shell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Review your vision', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8), Text('Here’s a summary of your $_timeline-year Best Possible Self.', style: const TextStyle(color: Color(0xFF53615C))),
    const SizedBox(height: 16), Expanded(child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFF3F7F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE7DC))), child: SingleChildScrollView(child: Text(_summary, style: const TextStyle(fontSize: 16, height: 1.55))))),
    const SizedBox(height: 16), _primaryButton('Save & Continue', _save), TextButton(onPressed: () => setState(() => _step = 2), child: const Center(child: Text('Write more', style: TextStyle(color: _accent)))),
  ]));

  Widget _completePage() => _shell(showProgress: false, child: Column(children: [
    const Spacer(), const CircleAvatar(radius: 33, backgroundColor: Color(0xFFF2F4E8), child: Icon(Icons.auto_awesome, color: Color(0xFFD3AF55), size: 34)), const SizedBox(height: 22),
    const Text('Your Best Possible Self\nis pinned to your home', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)), const SizedBox(height: 12), const Text('You can view it anytime and\nstay inspired.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF53615C), height: 1.45)), const SizedBox(height: 28),
    Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF3F7F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE7DC))), child: Text(_summary, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45))),
    const Spacer(), _primaryButton('Go to Home', () => Navigator.pop(context, true)),
  ]));

  Widget _primaryButton(String label, VoidCallback onPressed) => SizedBox(width: double.infinity, height: 52, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: onPressed, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))));
}

class _Area {
  const _Area(this.title, this.prompt, this.icon, this.color);
  final String title;
  final String prompt;
  final IconData icon;
  final Color color;
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: const Color(0xFF28463B)), const SizedBox(width: 16), Expanded(child: Text(label, style: const TextStyle(fontSize: 14)))]);
}
