import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../auth/login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen(
      {super.key,
      this.initialEmail,
      this.initialPassword,
      this.initialStudentId});

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
          _email.text.trim(), _password.text, _studentId.text.trim());
      final data = await _api.dashboard();
      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _data = data;
      });
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _practitioner(String id, String status) async {
    try {
      await _api.practitionerAction(id, status);
      await _refresh();
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteReportedPost(String postId) async {
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
        title: const Text('Add psychiatrist'),
        content: SingleChildScrollView(
          child: Column(children: [
            for (var i = 0; i < fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: fields[i],
                  keyboardType:
                      i == 1 ? TextInputType.emailAddress : TextInputType.text,
                  decoration: InputDecoration(
                      labelText: const [
                    'Name',
                    'Email',
                    'OTP / temporary password',
                    'License number',
                  ][i]),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != true) {
      for (final field in fields) field.dispose();
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
      for (final field in fields) field.dispose();
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
              child: const Text('Cancel')),
          FilledButton(
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
        title: Text('Update $key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Value'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await _api.updateSetting(key, value);
      await _refresh();
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
          title: Text('Moderation: $category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Policy enabled'),
                value: newEnabled,
                onChanged: (v) => setDialogState(() => newEnabled = v),
              ),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Confidence threshold (0–1)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final threshold = double.tryParse(controller.text);
                if (threshold == null || threshold < 0 || threshold > 1) return;
                Navigator.pop(ctx, (enabled: newEnabled, threshold: threshold));
              },
              child: const Text('Save'),
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
    } catch (e) {
      _show(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('AuraMind Admin Panel'),
        actions: [
          IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'),
          IconButton(
            onPressed: () async {
              await _api.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Safety-review boundary: the community is anonymous to regular users. This protected panel reveals the identity of authors only for reported content so an authorized administrator can investigate credible harm and moderation reports.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle('System activity'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: counts.entries
                  .map((e) => Chip(
                        avatar: const Icon(Icons.analytics_outlined, size: 18),
                        label:
                            Text('${e.key.replaceAll('_', ' ')}: ${e.value}'),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            _sectionTitle('AI moderation queue'),
            if (moderation.isEmpty)
              const Card(
                  child: ListTile(title: Text('No pending moderation items.')))
            else
              ...moderation.map((item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${item['category']} · ${(item['confidence'] as num).toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(item['content'] as String),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                  onPressed: () =>
                                      _moderation(item['id'], 'approved'),
                                  child: const Text('Approve')),
                              FilledButton(
                                  onPressed: () =>
                                      _moderation(item['id'], 'hidden'),
                                  child: const Text('Hide')),
                              OutlinedButton(
                                  onPressed: () =>
                                      _moderation(item['id'], 'rejected'),
                                  child: const Text('Reject')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 20),
            _sectionTitle('SafeSpace reports'),
            if (reports.isEmpty)
              const Card(
                  child:
                      ListTile(title: Text('No community reports recorded.')))
            else
              ...reports.take(20).map((report) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(report['reason'] as String),
                      subtitle: Text(
                          '${report['post_content']}\nPost ${report['post_id']}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Delete post',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _deleteReportedPost(report['post_id'] as String),
                      ),
                    ),
                  )),
            const SizedBox(height: 20),
            _sectionTitle('Deleted post reports and reasons'),
            if (deletedPosts.isEmpty)
              const Card(
                  child: ListTile(
                      title: Text('No automatically deleted posts yet.')))
            else
              ...deletedPosts.map((item) => Card(
                      child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(item['reason'] as String),
                    subtitle:
                        Text('Post ${item['post_id']} · ${item['created_at']}'),
                  ))),
            const SizedBox(height: 20),
            _sectionTitle('Reported comments — safety review'),
            if (commentReports.isEmpty)
              const Card(
                  child:
                      ListTile(title: Text('No reported comments recorded.')))
            else
              ...commentReports.take(50).map((report) {
                final commenter = Map<String, dynamic>.from(
                    report['commenter'] as Map? ?? {});
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report: ${report['reason'] ?? 'Comment report'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(report['comment']?.toString() ??
                            'Comment content unavailable'),
                        const SizedBox(height: 12),
                        Text(
                            'Comment author: ${commenter['name'] ?? 'Unknown user'}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            'Email: ${commenter['email'] ?? 'No email available'}'),
                        Text(
                            'User ID: ${commenter['user_id'] ?? 'Unavailable'}',
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _deleteReportedComment(report),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete comment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
            _sectionTitle('Pending practitioner certifications'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _showAddPractitioner,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add psychiatrist'),
              ),
            ),
            if (practitioners.isEmpty)
              const Card(
                  child: ListTile(title: Text('No pending registrations.')))
            else
              ...practitioners.map((item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(item['qualifications'] as String),
                          Text(item['specialty'] as String),
                          Text('Registration: ${item['registration_number']}'),
                          Text('${item['contact_no']} · ${item['chamber']}'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                  onPressed: () =>
                                      _practitioner(item['id'], 'approved'),
                                  child: const Text('Approve & publish')),
                              OutlinedButton(
                                  onPressed: () =>
                                      _practitioner(item['id'], 'rejected'),
                                  child: const Text('Reject')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 20),
            _sectionTitle('Moderation policies'),
            ...policies.map((p) => Card(
                  child: ListTile(
                    title: Text(p['category'] as String),
                    subtitle: Text(
                        'Threshold: ${(p['threshold'] as num).toStringAsFixed(2)}'),
                    trailing: Switch(
                      value: p['enabled'] as bool,
                      onChanged: (_) => _updatePolicy(p),
                    ),
                    onTap: () => _updatePolicy(p),
                  ),
                )),
            const SizedBox(height: 20),
            _sectionTitle('Reward & subscription parameters'),
            ...settings.map((s) => Card(
                  child: ListTile(
                    title: Text((s['key'] as String).replaceAll('_', ' ')),
                    subtitle: Text(s['value'] as String),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _updateSetting(
                        s['key'] as String, s['value'] as String),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      );

  Widget _buildLogin() {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrator Access')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 64),
                    const SizedBox(height: 16),
                    const Text('Protected Admin Panel',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                        'Administrator credentials are checked by the FastAPI backend.'),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Admin email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Admin password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _studentId,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Student ID'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lock_open_rounded),
                        label: Text(_loading
                            ? 'Signing in...'
                            : 'Sign in as administrator'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Use admin@test.com, admin123#, and one of the approved student IDs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
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
