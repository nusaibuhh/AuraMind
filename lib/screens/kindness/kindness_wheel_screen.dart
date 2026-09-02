import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class KindnessWheelScreen extends StatefulWidget {
  const KindnessWheelScreen({super.key});

  @override
  State<KindnessWheelScreen> createState() => _KindnessWheelScreenState();
}

class _KindnessAct {
  const _KindnessAct(this.key, this.label, this.task, this.points);

  final String key;
  final String label;
  final String task;
  final int points;
}

class _KindnessWheelScreenState extends State<KindnessWheelScreen>
    with SingleTickerProviderStateMixin {
  static const _acts = <_KindnessAct>[
    _KindnessAct('thank_you', 'Thank you', 'Send someone a sincere thank-you message', 5),
    _KindnessAct('compliment', 'Compliment', 'Compliment a colleague or classmate', 4),
    _KindnessAct('help', 'Offer help', 'Offer to help someone with one small task', 7),
    _KindnessAct('check_in', 'Check in', 'Check in on a friend who may need support', 6),
    _KindnessAct('queue', 'Let go first', 'Let someone go ahead of you in a queue', 3),
    _KindnessAct('share', 'Share help', 'Share useful notes or resources with someone', 5),
    _KindnessAct('appreciate', 'Appreciate', 'Thank a person who often helps you', 5),
    _KindnessAct('listen', 'Listen', 'Give someone your full attention for five minutes', 8),
    _KindnessAct('encourage', 'Encourage', 'Leave an encouraging note for someone', 6),
    _KindnessAct('chore', 'Small chore', 'Do one small chore to make another person’s day easier', 7),
    _KindnessAct('resource', 'Recommend', 'Recommend a helpful resource to someone', 4),
    _KindnessAct('ask_listen', 'Ask & listen', 'Ask someone how they are doing and listen', 8),
  ];

  late final AnimationController _controller;
  final Random _random = Random();
  int _selected = 0;
  double _wheelRotation = 0;
  bool _spinning = false;
  bool _loading = true;
  bool _saving = false;
  String? _completionId;
  int _streak = 0;
  int _points = 0;
  int _completedTasks = 0;
  List<Map<String, dynamic>> _history = const [];

  _KindnessAct get _act => _acts[_selected];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummary());
  }

  Future<void> _loadSummary() async {
    final auth = context.read<AuthProvider>();
    // On a cold web reload, SharedPreferences restores the token asynchronously.
    // Wait briefly for AuthProvider so the Kindness Wheel does not issue an
    // unauthenticated request before a valid saved session is restored.
    for (var i = 0; i < 30 && !auth.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Please sign in to save kindness progress in the AuraMind database.');
      return;
    }
    try {
      final data = await auth.api.getKindnessSummary();
      if (!mounted) return;
      setState(() {
        _applySummary(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load kindness progress: ${e.toString()}');
    }
  }

  void _applySummary(Map<String, dynamic> data) {
    _streak = (data['streak'] as num?)?.toInt() ?? 0;
    _points = (data['points'] as num?)?.toInt() ?? 0;
    _completedTasks = (data['completed_tasks'] as num?)?.toInt() ?? 0;
    _history = (data['history'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _spin() async {
    if (_spinning || _saving) return;
    final next = _random.nextInt(_acts.length);
    final slice = 2 * pi / _acts.length;
    final desired = -(next * slice + slice / 2);
    var delta = desired - _wheelRotation;
    while (delta < 0) {
      delta += 2 * pi;
    }
    final target = _wheelRotation + (5 + _random.nextInt(3)) * 2 * pi + delta;

    setState(() {
      _spinning = true;
      _completionId = null;
    });

    final animation = Tween<double>(begin: _wheelRotation, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    void listener() {
      if (mounted) setState(() => _wheelRotation = animation.value);
    }

    animation.addListener(listener);
    _controller.reset();
    await _controller.forward();
    animation.removeListener(listener);

    if (!mounted) return;
    setState(() {
      _wheelRotation = target;
      _selected = next;
      _spinning = false;
    });
  }

  Future<void> _toggleCompleted(bool value) async {
    if (_saving || _spinning) return;
    setState(() => _saving = true);
    try {
      final api = context.read<AuthProvider>().api;
      Map<String, dynamic> data;
      if (value) {
        data = await api.completeKindnessTask(
          taskKey: _act.key,
          taskText: _act.task,
          points: _act.points,
        );
        _completionId = data['completion_id'] as String?;
        _message('+${_act.points} points added. Great work!');
      } else {
        final id = _completionId;
        if (id == null) return;
        data = await api.undoKindnessTask(id);
        _completionId = null;
      }
      if (!mounted) return;
      setState(() => _applySummary(data));
    } catch (e) {
      // Keep the backend's useful error text visible during development. This
      // also makes authentication/database problems distinguishable from a
      // normal network failure.
      final detail = e.toString().replaceFirst('Exception: ', '');
      _message('Could not update the task: $detail');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Deliberate Acts of Kindness'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  children: [
                    Card(
                      elevation: 0,
                      color: primary.withValues(alpha: 0.10),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.favorite_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Spin the wheel. The task written on the wheel under the pointer becomes your next kindness challenge. You can spin and complete as many acts as you want in one day.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _statChip(Icons.local_fire_department_rounded, '$_streak day streak'),
                        _statChip(Icons.stars_rounded, '$_points points'),
                        _statChip(Icons.check_circle_rounded, '$_completedTasks tasks / 7 days'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 360,
                      height: 360,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: _wheelRotation,
                            child: CustomPaint(
                              size: const Size(330, 330),
                              painter: _WheelPainter(
                                acts: _acts,
                                primary: primary,
                              ),
                            ),
                          ),
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12),
                              ],
                            ),
                            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 34),
                          ),
                          Positioned(
                            top: 0,
                            child: Icon(Icons.arrow_drop_down_rounded, color: primary, size: 52),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Selected task', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(
                      _act.task,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      avatar: const Icon(Icons.stars_rounded, size: 18),
                      label: Text('${_act.points} points when completed'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _spinning || _saving ? null : _spin,
                        icon: _spinning
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.casino_rounded),
                        label: Text(_spinning ? 'Spinning...' : 'Spin the Wheel'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 0,
                      child: SwitchListTile.adaptive(
                        value: _completionId != null,
                        onChanged: _spinning || _saving ? null : _toggleCompleted,
                        secondary: Icon(
                          _completionId != null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: _completionId != null ? primary : Colors.grey,
                        ),
                        title: Text(
                          _completionId != null ? 'Completed — points recorded!' : 'Mark this selected act complete',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(_completionId != null
                            ? 'This completion is saved in the database.'
                            : 'Every completion is stored for seven days and contributes to your streak.'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tasks on the wheel', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    ..._acts.map((act) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${act.points}')),
                            title: Text(act.task),
                            trailing: const Icon(Icons.stars_rounded),
                          ),
                        )),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Recent completions (last 7 days)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 8),
                      ..._history.take(10).map((item) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(item['task_text'] as String? ?? 'Kindness task'),
                              subtitle: Text(item['completed_date'] as String? ?? ''),
                              trailing: Text('+${item['points'] ?? 0}'),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statChip(IconData icon, String text) => Chip(
        avatar: Icon(icon, size: 18),
        label: Text(text),
      );
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.acts, required this.primary});

  final List<_KindnessAct> acts;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final slice = 2 * pi / acts.length;
    final fill = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < acts.length; i++) {
      fill.color = i.isEven ? primary.withValues(alpha: 0.88) : Colors.white;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + i * slice,
        slice,
        true,
        fill,
      );

      final angle = -pi / 2 + i * slice + slice / 2;
      final labelRadius = radius * 0.70;
      final point = Offset(
        center.dx + cos(angle) * labelRadius,
        center.dy + sin(angle) * labelRadius,
      );
      canvas.save();
      canvas.translate(point.dx, point.dy);
      var rotation = angle + pi / 2;
      if (rotation > pi / 2 && rotation < 3 * pi / 2) rotation += pi;
      canvas.rotate(rotation);
      final painter = TextPainter(
        text: TextSpan(
          text: acts[i].label,
          style: TextStyle(
            color: i.isEven ? Colors.white : Colors.black87,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.44);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = primary;
    canvas.drawCircle(center, radius, border);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.acts != acts;
}
