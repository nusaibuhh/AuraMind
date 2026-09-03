import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_palette.dart';
import '../models/question.dart';

import '../services/api_service.dart';

class AppThemeProvider extends ChangeNotifier {
  ThemePalette _palette = allThemePalettes[6];

  bool _hasCompletedCheckIn = false;

  bool _isLoading = false;
  MentalHealthCategory _wellbeingCategory = MentalHealthCategory.normal;

  ThemePalette get palette => _palette;

  bool get hasCompletedCheckIn => _hasCompletedCheckIn;

  bool get isLoading => _isLoading;
  MentalHealthCategory get wellbeingCategory => _wellbeingCategory;

  ThemeData get themeData => _palette.toThemeData();

  Future<void> loadSavedTheme(ApiService api) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      ThemePalette? saved;
      try {
        saved = await api.fetchSelectedTheme();
      } catch (_) {}

      // If backend returned a saved theme, preserve it locally
      if (saved != null) {
        _palette = saved;
        if (userId != null) {
          await prefs.setString('selected_theme_id_$userId', saved.id);
        }
      } else if (userId != null) {
        // Fallback to locally saved theme
        final localThemeId = prefs.getString('selected_theme_id_$userId');
        if (localThemeId != null) {
          try {
            _palette = allThemePalettes.firstWhere((p) => p.id == localThemeId);
            saved = _palette;
          } catch (_) {}
        }
      }

      if (saved != null) {
        try {
          _hasCompletedCheckIn = await api.hasRecentCheckin();
          if (_hasCompletedCheckIn && userId != null) {
            await prefs.setString(
                'last_checkin_at_$userId', DateTime.now().toIso8601String());
          }
        } catch (_) {
          // Fallback to local check-in timestamp
          if (userId != null) {
            final raw = prefs.getString('last_checkin_at_$userId');
            if (raw != null) {
              final last = DateTime.tryParse(raw);
              if (last != null) {
                final diff = DateTime.now().difference(last);
                _hasCompletedCheckIn = diff.inHours < 24 && !diff.isNegative;
              } else {
                _hasCompletedCheckIn = false;
              }
            } else {
              _hasCompletedCheckIn = false;
            }
          } else {
            _hasCompletedCheckIn = false;
          }
        }
      } else {
        _hasCompletedCheckIn = false;
      }
    } catch (_) {
      // Error in theme resolution
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPalette(ThemePalette palette, ApiService api,
      {MentalHealthCategory? wellbeingCategory}) async {
    await api.selectTheme(palette.id);

    _palette = palette;
    _hasCompletedCheckIn = true;
    _wellbeingCategory = wellbeingCategory ?? palette.category;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      await prefs.setString('selected_theme_id_$userId', palette.id);
      await prefs.setString(
          'last_checkin_at_$userId', DateTime.now().toIso8601String());
    }

    notifyListeners();
  }

  void applyPaletteLocally(ThemePalette palette) {
    _palette = palette;
    _hasCompletedCheckIn = true;
    notifyListeners();
  }

  Future<void> changeTheme(ThemePalette palette, ApiService api) async {
    await api.selectTheme(palette.id);
    _palette = palette;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      await prefs.setString('selected_theme_id_$userId', palette.id);
    }

    notifyListeners();
  }

  void resetCheckIn() {
    // Reset completion flag but keep the chosen theme intact
    _hasCompletedCheckIn = false;
    _wellbeingCategory = MentalHealthCategory.normal;
    notifyListeners();
  }
}
