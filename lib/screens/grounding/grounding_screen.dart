import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingStep {
  const _GroundingStep({
    required this.category,
    required this.verb,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String category;
  final String verb;
  final String title;
  final int count;
  final IconData icon;
  final Color color;
}

const _steps = [
  _GroundingStep(
    category: 'sight',
    verb: 'Look around',
    title: 'Name 5 things you can see',
    count: 5,
    icon: Icons.visibility_outlined,
    color: Color(0xFF5F705A),
  ),
  _GroundingStep(
    category: 'touch',
    verb: 'Notice',
    title: 'Name 4 things you can touch',
    count: 4,
    icon: Icons.pan_tool_outlined,
    color: Color(0xFF877C70),
  ),
  _GroundingStep(
    category: 'hear',
    verb: 'Listen carefully',
    title: 'Name 3 things you can hear',
    count: 3,
    icon: Icons.hearing_outlined,
    color: Color(0xFF89838E),
  ),
  _GroundingStep(
    category: 'smell',
    verb: 'Breathe in',
    title: 'Name 2 things you can smell',
    count: 2,
    icon: Icons.air,
    color: Color(0xFF67A17F),
  ),
  _GroundingStep(
    category: 'taste',
    verb: 'Finally',
    title: 'Name 1 thing you can taste',
    count: 1,
    icon: Icons.face_retouching_natural_outlined,
    color: Color(0xFF950052),
  ),
];

class _GroundingScreenState extends State<GroundingScreen> {
  int _stepIndex = -1;
  String? _sessionId;
  bool _isSaving = false;
  List<TextEditingController> _controllers = [];

  bool get _isIntro => _stepIndex == -1;
  bool get _isComplete => _stepIndex == _steps.length;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _begin() async {
    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthProvider>();
      final sessionId = await auth.api.startGroundingSession(auth.user!.id);
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _stepIndex = 0;
        _setControllers();
        _isSaving = false;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not start grounding session. Check your connection.');
    }
  }

  void _setControllers() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers = [
      for (var index = 0; index < _steps[_stepIndex].count; index++)
        TextEditingController(),
    ];
  }

  Future<void> _continue() async {
    final items = _controllers.map((controller) => controller.text.trim()).toList();
    if (items.any((item) => item.isEmpty)) {
      _showError('Add something for each row before continuing.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<AuthProvider>().api.addGroundingEntries(
            sessionId: _sessionId!,
            category: _steps[_stepIndex].category,
            items: items,
          );
      if (!mounted) return;
      if (_stepIndex == _steps.length - 1) {
        setState(() {
          _stepIndex = _steps.length;
          _isSaving = false;
        });
      } else {
        setState(() {
          _stepIndex++;
          _setControllers();
          _isSaving = false;
        });
      }
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not save your entries. Check your connection.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isIntro) return _buildIntro(context);
    if (_isComplete) return _buildComplete(context);
    return _buildStep(context, _steps[_stepIndex]);
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFB9E8DD), Color(0xFFE8F0C8)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: -60,
                    right: -60,
                    bottom: 0,
                    height: 250,
                    child: CustomPaint(painter: _LandscapePainter()),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ground Yourself',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(
                            width: 240,
                            child: Text(
                              "Let's connect with the present moment using your senses",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, height: 1.25),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 16),
                              SizedBox(width: 6),
                              Text('Takes about 2 minutes'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _begin,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Begin'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, _GroundingStep step) {
    final progress = (_stepIndex + 1) / _steps.length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE0E0E0),
                  color: step.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${_stepIndex + 1}/5', style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: step.color.withValues(alpha: 0.12),
                      child: Icon(step.icon, size: 42, color: step.color),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      step.verb,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 26),
                    ..._controllers.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 25,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: step.color.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('${entry.key + 1}'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: entry.value,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      hintText: 'Add an answer',
                                      filled: true,
                                      fillColor: const Color(0xFFF0EEF4),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(7),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: step.color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving ? null : _continue,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: Color(0xFFDCEBDD),
                  child: Icon(Icons.check_rounded, size: 48, color: Color(0xFF52755A)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'You are grounded',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Notice how the present moment feels. You can return to this practice whenever you need it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final first = Paint()..color = const Color(0xFF78B8C0);
    final second = Paint()..color = const Color(0xFF0D7186);
    final third = Paint()..color = const Color(0xFF07546B);
    final path = Path()
      ..moveTo(0, size.height * .58)
      ..lineTo(size.width * .32, size.height * .28)
      ..lineTo(size.width * .58, size.height * .65)
      ..lineTo(size.width, size.height * .44)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, first);
    final path2 = Path()
      ..moveTo(0, size.height * .68)
      ..lineTo(size.width * .2, size.height * .5)
      ..lineTo(size.width * .52, size.height * .76)
      ..lineTo(size.width, size.height * .6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, second);
    final path3 = Path()
      ..moveTo(0, size.height * .84)
      ..lineTo(size.width * .28, size.height * .7)
      ..lineTo(size.width * .6, size.height * .88)
      ..lineTo(size.width, size.height * .78)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path3, third);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
