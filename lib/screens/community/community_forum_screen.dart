import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'community_comments_sheet.dart';

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({super.key});

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> {
  final List<CommunityPost> _posts = [];
  bool _loading = true;
  String? _error;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPosts());
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _api.getCommunityPosts();
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the community.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose() async {
    String draft = '';
    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share anonymously',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Your name, email and user ID are never shown publicly. '
                    'Email addresses and phone numbers written in your post '
                    'are removed before public display.',
                    style: TextStyle(color: Color(0xFF6F6974), height: 1.35),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (value) => draft = value,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: 'What would you like to share?',
                      filled: true,
                      fillColor: const Color(0xFFF7F4FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: const Text('Post anonymously'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final text = draft.trim();
    if (submit != true) return;
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before posting.')),
      );
      return;
    }

    try {
      await _api.createCommunityPost(text);
      await _loadPosts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anonymous post published.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _report(CommunityPost post) async {
    String reason = 'Harmful or triggering content';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Report this post?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The report will be stored for moderation review. '
                  'Your public identity remains anonymous.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Harmful or triggering content',
                      child: Text('Harmful or triggering content'),
                    ),
                    DropdownMenuItem(
                      value: 'Bullying or harassment',
                      child: Text('Bullying or harassment'),
                    ),
                    DropdownMenuItem(
                      value: 'Spam or unrelated content',
                      child: Text('Spam or unrelated content'),
                    ),
                    DropdownMenuItem(
                      value: 'Personal information exposed',
                      child: Text('Personal information exposed'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => reason = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      final result =
          await _api.reportCommunityPost(postId: post.id, reason: reason);
      if (!mounted) return;

      final message = result['already_reported'] == true
          ? 'You have already reported this post.'
          : 'Report submitted for review.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openComments(CommunityPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommunityCommentsSheet(
        api: _api,
        post: post,
      ),
    );

    if (mounted) {
      await _loadPosts();
    }
  }

  String _time(DateTime dt) {
    final d = DateTime.now().difference(dt.toLocal());
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6FB),
        title: const Text(
          'Community Forum',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Share'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 105),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0E7FB), Color(0xFFF8F4FD)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE4D5F4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_outlined, color: accent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A safer place to be heard',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Posts use pseudonymous identities. Your name, '
                          'email and user ID are not rendered publicly.',
                          style: TextStyle(
                            color: Color(0xFF6C6870),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 55),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadPosts,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_posts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 55),
                child: Column(
                  children: [
                    const Icon(
                      Icons.forum_outlined,
                      size: 54,
                      color: Color(0xFF9873C8),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No community posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Be the first to share anonymously.'),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _compose,
                      child: const Text('Share anonymously'),
                    ),
                  ],
                ),
              )
            else
              ..._posts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PostCard(
                    post: post,
                    timeLabel: _time(post.createdAt),
                    onReport: () => _report(post),
                    onComments: () => _openComments(post),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.timeLabel,
    required this.onReport,
    required this.onComments,
  });

  final CommunityPost post;
  final String timeLabel;
  final VoidCallback onReport;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF0E7FB),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF8557C7),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorAlias,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: Color(0xFF89838D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined, size: 17),
                label: const Text('Report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 11),
          TextButton.icon(
            onPressed: onComments,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(
              post.commentCount == 1
                  ? '1 comment'
                  : '${post.commentCount} comments',
            ),
          ),
        ],
      ),
    );
  }
}
