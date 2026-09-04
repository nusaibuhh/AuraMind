import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../auth/login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({
    super.key,
    this.initialEmail,
    this.initialPassword,
    this.initialStudentId,
  });

  final String? initialEmail;
  final String? initialPassword;
  final String? initialStudentId;

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _api = AdminApiService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentId = TextEditingController();
  bool _loggedIn = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
    _password.text = widget.initialPassword ?? '';
    _studentId.text = widget.initialStudentId ?? '';
    if (widget.initialEmail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _login());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _studentId.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter administrator email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.login(
        _email.text.trim(),
        _password.text,
        _studentId.text.trim(),
      );
      final data = await _api.dashboard();
      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _data = data;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.dashboard();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _moderation(String id, String status) async {
    try {
      await _api.moderationAction(id, status);
      await _refresh();
      _show('Content marked as $status.');
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _practitioner(String id, String status) async {
    try {
      await _api.practitionerAction(id, status);
      await _refresh();
      _show('Practitioner registration $status.');
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteReportedPost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reported Post?'),
        content: const Text(
            'This action will permanently delete this post from the community.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteReportedPost(postId);
      _show('Reported post deleted.');
      await _refresh();
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showAddPractitioner() async {
    final fields = List.generate(4, (_) => TextEditingController());
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded),
            SizedBox(width: 10),
            Text('Add Psychiatrist'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: fields[i],
                    keyboardType: i == 1
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: const [
                        'Full Name',
                        'Email Address',
                        'OTP / Temporary Password',
                        'License / Registration Number',
                      ][i],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Add & Publish'),
          ),
        ],
      ),
    );
    if (result != true) {
      for (final field in fields) {
        field.dispose();
      }
      return;
    }
    try {
      await _api.createPractitioner({
        'name': fields[0].text.trim(),
        'email': fields[1].text.trim(),
        'otp': fields[2].text.trim(),
        'license_number': fields[3].text.trim(),
      });
      _show('Psychiatrist added and published.');
      await _refresh();
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      for (final field in fields) {
        field.dispose();
      }
    }
  }

  Future<void> _deleteReportedComment(Map<String, dynamic> report) async {
    final commenter =
        Map<String, dynamic>.from(report['commenter'] as Map? ?? {});
    final name = commenter['name']?.toString() ?? 'this user';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reported comment?'),
        content: Text(
            'Delete the reported comment authored by $name? This action removes the comment from the community and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete comment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteReportedComment(report['comment_id'] as String);
      if (mounted) _show('Reported comment deleted.');
      await _refresh();
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _updateSetting(String key, String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${key.replaceAll('_', ' ')}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Parameter value',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await _api.updateSetting(key, value);
      await _refresh();
      _show('Setting updated.');
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _updatePolicy(Map<String, dynamic> policy) async {
    final category = policy['category'] as String;
    final enabled = policy['enabled'] as bool;
    final controller = TextEditingController(
      text: ((policy['threshold'] as num?)?.toDouble() ?? 0.7).toString(),
    );
    bool newEnabled = enabled;
    final result = await showDialog<({bool enabled, double threshold})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Policy: ${category.toUpperCase()}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Policy Active'),
                value: newEnabled,
                onChanged: (v) => setDialogState(() => newEnabled = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Confidence threshold (0.00 – 1.00)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final threshold = double.tryParse(controller.text);
                if (threshold == null || threshold < 0 || threshold > 1) return;
                Navigator.pop(ctx, (enabled: newEnabled, threshold: threshold));
              },
              child: const Text('Save Policy'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await _api.updatePolicy(category, result.enabled, result.threshold);
      await _refresh();
      _show('Policy updated.');
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) return _buildLogin();

    final data = _data ?? {};
    final counts = Map<String, dynamic>.from(data['counts'] ?? {});
    final moderation = List<Map<String, dynamic>>.from(
      (data['moderation_queue'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final practitioners = List<Map<String, dynamic>>.from(
      (data['practitioner_queue'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final reports = List<Map<String, dynamic>>.from(
      (data['reports'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final deletedPosts = List<Map<String, dynamic>>.from(
      (data['deleted_posts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final commentReports = List<Map<String, dynamic>>.from(
      (data['comment_reports'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final policies = List<Map<String, dynamic>>.from(
      (data['moderation_policies'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );
    final settings = List<Map<String, dynamic>>.from(
      (data['system_settings'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e)),
    );

    final totalPendingModeration =
        moderation.length + reports.length + commentReports.length;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 26),
              const SizedBox(width: 8),
              const Text(
                'Admin Console',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SECURE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh data',
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(
                icon: Icon(Icons.dashboard_rounded),
                text: 'Overview',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: totalPendingModeration > 0,
                  label: Text('$totalPendingModeration'),
                  child: const Icon(Icons.shield_outlined),
                ),
                text: 'Moderation',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: practitioners.isNotEmpty,
                  label: Text('${practitioners.length}'),
                  child: const Icon(Icons.medical_services_outlined),
                ),
                text: 'Psychiatrists',
              ),
              const Tab(
                icon: Icon(Icons.tune_rounded),
                text: 'Policies & Settings',
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: TabBarView(
            children: [
              _buildOverviewTab(counts),
              _buildModerationTab(
                moderation: moderation,
                reports: reports,
                commentReports: commentReports,
                deletedPosts: deletedPosts,
              ),
              _buildPractitionersTab(practitioners),
              _buildPoliciesTab(policies: policies, settings: settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> counts) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.blue.shade100),
          ),
          color: Colors.blue.shade50.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security_rounded, color: Colors.blue.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety-Review Protocol Active',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Community members remain anonymous to regular users. This protected console reveals user identifiers solely for reported content so administrators can intervene against credible harm.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey.shade800,
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
        const SizedBox(height: 20),
        _sectionHeader('System Metrics', Icons.analytics_rounded),
        const SizedBox(height: 10),
        if (counts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No system metrics loaded.'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                children: counts.entries.map((e) {
                  return _metricCard(
                    e.key.replaceAll('_', ' '),
                    e.value.toString(),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _metricCard(String label, String value) {
    IconData icon;
    Color color;

    final lower = label.toLowerCase();
    if (lower.contains('user')) {
      icon = Icons.people_alt_rounded;
      color = Colors.indigo;
    } else if (lower.contains('post')) {
      icon = Icons.forum_rounded;
      color = Colors.teal;
    } else if (lower.contains('checkin') || lower.contains('mood')) {
      icon = Icons.sentiment_satisfied_alt_rounded;
      color = Colors.orange;
    } else if (lower.contains('booking') || lower.contains('consult')) {
      icon = Icons.calendar_month_rounded;
      color = Colors.purple;
    } else if (lower.contains('report')) {
      icon = Icons.flag_rounded;
      color = Colors.red;
    } else {
      icon = Icons.bar_chart_rounded;
      color = Colors.blueGrey;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
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

  Widget _buildModerationTab({
    required List<Map<String, dynamic>> moderation,
    required List<Map<String, dynamic>> reports,
    required List<Map<String, dynamic>> commentReports,
    required List<Map<String, dynamic>> deletedPosts,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(
          'AI Flagged Content (${moderation.length})',
          Icons.smart_toy_outlined,
        ),
        const SizedBox(height: 8),
        if (moderation.isEmpty)
          _emptyState('No AI flagged items requiring review')
        else
          ...moderation.map((item) {
            final confidence =
                ((item['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text((item['category'] ?? 'Flagged').toString().toUpperCase()),
                          backgroundColor: Colors.red.shade50,
                          side: BorderSide(color: Colors.red.shade200),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${confidence.toStringAsFixed(1)}% confidence',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        item['content'] as String? ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _moderation(item['id'], 'approved'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Approve'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _moderation(item['id'], 'hidden'),
                          icon: const Icon(Icons.visibility_off_outlined, size: 16),
                          label: const Text('Hide'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _moderation(item['id'], 'rejected'),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
        _sectionHeader(
          'Community Reported Posts (${reports.length})',
          Icons.flag_outlined,
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          _emptyState('No community post reports recorded')
        else
          ...reports.take(20).map((report) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.shade100,
                    child: Icon(Icons.flag_rounded, color: Colors.amber.shade900),
                  ),
                  title: Text(
                    report['reason'] as String? ?? 'Community report',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${report['post_content'] ?? ''}\nPost ID: ${report['post_id']}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete post',
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade700),
                    onPressed: () =>
                        _deleteReportedPost(report['post_id'] as String),
                  ),
                ),
              )),
        const SizedBox(height: 24),
        _sectionHeader(
          'Reported Comments — Safety Review (${commentReports.length})',
          Icons.comment_outlined,
        ),
        const SizedBox(height: 8),
        if (commentReports.isEmpty)
          _emptyState('No reported comments recorded')
        else
          ...commentReports.take(50).map((report) {
            final commenter =
                Map<String, dynamic>.from(report['commenter'] as Map? ?? {});
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem_outlined,
                            color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Report: ${report['reason'] ?? 'Comment violation'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report['comment']?.toString() ??
                          'Comment content unavailable',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identified Author: ${commenter['name'] ?? 'Anonymous user'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Email: ${commenter['email'] ?? 'No email'} · User ID: ${commenter['user_id'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteReportedComment(report),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete Comment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
        _sectionHeader(
          'Auto-Deleted Post Logs (${deletedPosts.length})',
          Icons.history_rounded,
        ),
        const SizedBox(height: 8),
        if (deletedPosts.isEmpty)
          _emptyState('No auto-deleted posts on record')
        else
          ...deletedPosts.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: Text(item['reason'] as String? ?? 'Deleted'),
                  subtitle: Text(
                    'Post ${item['post_id']} · ${item['created_at']}',
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildPractitionersTab(List<Map<String, dynamic>> practitioners) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(
              'Practitioners (${practitioners.length} pending)',
              Icons.medical_services_outlined,
            ),
            FilledButton.icon(
              onPressed: _showAddPractitioner,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add Psychiatrist'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (practitioners.isEmpty)
          _emptyState('No pending registrations awaiting verification')
        else
          ...practitioners.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade50,
                            child: Icon(Icons.person_outline_rounded,
                                color: Colors.teal.shade800),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item['qualifications'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: const Text('Pending Review'),
                            backgroundColor: Colors.orange.shade50,
                            side: BorderSide(color: Colors.orange.shade200),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Specialty: ${item['specialty']}'),
                            const SizedBox(height: 2),
                            Text('Registration No: ${item['registration_number']}'),
                            const SizedBox(height: 2),
                            Text('Contact: ${item['contact_no']}'),
                            const SizedBox(height: 2),
                            Text('Chamber: ${item['chamber']}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _practitioner(item['id'], 'rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () =>
                                _practitioner(item['id'], 'approved'),
                            icon: const Icon(Icons.verified_rounded, size: 18),
                            label: const Text('Approve & Publish'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildPoliciesTab({
    required List<Map<String, dynamic>> policies,
    required List<Map<String, dynamic>> settings,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('AI Moderation Policies', Icons.tune_rounded),
        const SizedBox(height: 10),
        if (policies.isEmpty)
          _emptyState('No moderation policies defined')
        else
          ...policies.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p['enabled'] == true
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    child: Icon(
                      p['enabled'] == true
                          ? Icons.shield_rounded
                          : Icons.shield_outlined,
                      color: p['enabled'] == true
                          ? Colors.green.shade800
                          : Colors.grey.shade600,
                    ),
                  ),
                  title: Text(
                    (p['category'] as String? ?? '').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Threshold: ${((p['threshold'] as num?)?.toDouble() ?? 0.7).toStringAsFixed(2)}',
                  ),
                  trailing: Switch(
                    value: p['enabled'] as bool? ?? false,
                    onChanged: (_) => _updatePolicy(p),
                  ),
                  onTap: () => _updatePolicy(p),
                ),
              )),
        const SizedBox(height: 24),
        _sectionHeader('System Parameters', Icons.settings_suggest_rounded),
        const SizedBox(height: 10),
        if (settings.isEmpty)
          _emptyState('No system settings defined')
        else
          ...settings.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.settings_outlined),
                  ),
                  title: Text(
                    (s['key'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(s['value'] as String? ?? ''),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _updateSetting(
                    s['key'] as String,
                    s['value'] as String,
                  ),
                ),
              )),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _emptyState(String text) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: Colors.grey.shade400, size: 36),
              const SizedBox(height: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrator Access')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Admin Console',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter authorized administrator credentials',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Admin Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Admin Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _studentId,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Student / Verification ID',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open_rounded, size: 20),
                        label: Text(
                          _loading ? 'Authenticating...' : 'Access Console',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
