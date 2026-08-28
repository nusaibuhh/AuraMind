import 'package:flutter/foundation.dart';
import '../models/journal_entry.dart';
import '../services/api_service.dart';

class JournalProvider extends ChangeNotifier {
  JournalProvider(this._api);

  final ApiService _api;

  List<JournalEntry> _entries = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedTag = 'All';

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedTag => _selectedTag;

  List<JournalEntry> get filteredEntries {
    return _entries.where((entry) {
      final matchesTag = _selectedTag == 'All' ||
          entry.moodTag.toLowerCase() == _selectedTag.toLowerCase();
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          entry.title.toLowerCase().contains(q) ||
          entry.content.toLowerCase().contains(q) ||
          entry.moodTag.toLowerCase().contains(q);
      return matchesTag && matchesSearch;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  Future<void> fetchEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _api.getJournalEntries();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createEntry({
    String? title,
    required String content,
    String? moodTag,
  }) async {
    try {
      final newEntry = await _api.createJournalEntry(
        title: title,
        content: content,
        moodTag: moodTag,
      );
      _entries.insert(0, newEntry);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEntry({
    required String id,
    String? title,
    required String content,
    String? moodTag,
  }) async {
    try {
      final updated = await _api.updateJournalEntry(
        id: id,
        title: title,
        content: content,
        moodTag: moodTag,
      );
      final idx = _entries.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _entries[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEntry(String id) async {
    try {
      await _api.deleteJournalEntry(id);
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
