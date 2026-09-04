import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/journal_entry.dart';
import '../../providers/journal_provider.dart';
import '../../providers/theme_provider.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _moodTags = [
    'All',
    '🌱 Growth',
    '☀️ Grateful',
    '💭 Reflection',
    '🌊 Calm',
    '🌧️ Heavy',
    '⚡ Energized',
    '✨ Best Self',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JournalProvider>().fetchEntries();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (diff.inDays == 0 && dt.day == now.day) {
      return 'Today at $hour:$minute';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && dt.day != now.day)) {
      return 'Yesterday at $hour:$minute';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  void _openEntryEditor({JournalEntry? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JournalEditorSheet(existing: existing),
    );
  }

  void _showEntryDetails(JournalEntry entry) {
    final theme = Theme.of(context);
    final formattedDate = _formatDateTime(entry.createdAt);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFEFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (entry.moodTag.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3EA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD3E6D0)),
                    ),
                    child: Text(
                      entry.moodTag,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF38634B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF5E8C76)),
                  tooltip: 'Edit Entry',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openEntryEditor(existing: entry);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.black45),
                  tooltip: 'Delete Entry',
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    _confirmDelete(entry);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entry.title.isNotEmpty) ...[
              Text(
                entry.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF193222),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  entry.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.65,
                    color: Color(0xFF2C3E35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this journal entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<JournalProvider>().deleteEntry(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Entry deleted.' : 'Failed to delete entry.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final palette = context.watch<AppThemeProvider>().palette;
    final theme = Theme.of(context);
    final entries = journal.filteredEntries;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: theme.colorScheme.onSurface,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Journal & Reflections',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEntryEditor(),
        backgroundColor: const Color(0xFF5E8C76),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.edit_outlined),
        label: const Text(
          'New Entry',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Mood Tags Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search TextField
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: journal.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search notes, reflections...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  journal.setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tag Filter Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moodTags.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tag = _moodTags[index];
                        final isSelected = journal.selectedTag == tag;

                        return ChoiceChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (_) => journal.setSelectedTag(tag),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF4C5E55),
                          ),
                          selectedColor: const Color(0xFF5E8C76),
                          backgroundColor: Colors.white.withValues(alpha: 0.85),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF5E8C76)
                                  : const Color(0xFFE4ECE2),
                            ),
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Entries List
            Expanded(
              child: journal.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: journal.fetchEntries,
                      child: entries.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              child: _EmptyJournalCard(
                                hasFilter: journal.searchQuery.isNotEmpty ||
                                    journal.selectedTag != 'All',
                                onWriteTap: () => _openEntryEditor(),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
                              itemCount: entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return _JournalEntryCard(
                                  entry: entry,
                                  formattedDate: _formatDateTime(entry.createdAt),
                                  onTap: () => _showEntryDetails(entry),
                                  onDelete: () => _confirmDelete(entry),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({
    required this.entry,
    required this.formattedDate,
    required this.onTap,
    required this.onDelete,
  });

  final JournalEntry entry;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE6EFE4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (entry.moodTag.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.moodTag,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF43735B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF88968F),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Color(0xFFA5B2AC),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (entry.title.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A2B),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                entry.content.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF4C5E55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyJournalCard extends StatelessWidget {
  const _EmptyJournalCard({
    required this.hasFilter,
    required this.onWriteTap,
  });

  final bool hasFilter;
  final VoidCallback onWriteTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4ECE2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEBF4EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF5E8C76),
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilter ? 'No Matching Entries' : 'Your Mindful Journal is Empty',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A2B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try clearing the search or choosing a different tag filter.'
                : 'Writing down your thoughts helps untangle emotions and brings clarity. Tap below to capture your first reflection.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF6B7E74),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onWriteTap,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Write Your First Thought',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5E8C76),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalEditorSheet extends StatefulWidget {
  const _JournalEditorSheet({this.existing});

  final JournalEntry? existing;

  @override
  State<_JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<_JournalEditorSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedTag = '🌱 Growth';
  bool _isSaving = false;

  static const List<String> _availableTags = [
    '🌱 Growth',
    '☀️ Grateful',
    '💭 Reflection',
    '🌊 Calm',
    '🌧️ Heavy',
    '⚡ Energized',
    '✨ Best Self',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _titleController.text = widget.existing!.title;
      _contentController.text = widget.existing!.content;
      if (widget.existing!.moodTag.isNotEmpty) {
        _selectedTag = widget.existing!.moodTag;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your thought before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<JournalProvider>();
    bool success = false;

    if (widget.existing != null) {
      success = await provider.updateEntry(
        id: widget.existing!.id,
        title: _titleController.text.trim(),
        content: content,
        moodTag: _selectedTag,
      );
    } else {
      success = await provider.createEntry(
        title: _titleController.text.trim(),
        content: content,
        moodTag: _selectedTag,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existing != null
                ? 'Journal entry updated ✨'
                : 'Journal entry saved ✨',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save entry. Check backend connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFEFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset + 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                widget.existing != null ? 'Edit Thought' : 'New Journal Entry',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E3A2B),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mood Tag Chips
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableTags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final tag = _availableTags[index];
                final isSelected = _selectedTag == tag;

                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedTag = tag),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF4C5E55),
                  ),
                  selectedColor: const Color(0xFF5E8C76),
                  backgroundColor: const Color(0xFFF3F7F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF5E8C76)
                          : const Color(0xFFE0EAE0),
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Title field
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Title (optional)',
              hintStyle: TextStyle(
                fontSize: 15,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAF7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2ECE0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2ECE0)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Content field
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText:
                    "What's on your mind today? Write freely without judgment...",
                hintStyle: TextStyle(
                  fontSize: 14.5,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAF7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2ECE0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2ECE0)),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5E8C76),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Thought',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
