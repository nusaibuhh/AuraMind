import 'package:flutter/material.dart';



import '../models/theme_palette.dart';

import '../services/api_service.dart';



class AppThemeProvider extends ChangeNotifier {

  ThemePalette _palette = allThemePalettes[6];

  bool _hasCompletedCheckIn = false;

  bool _isLoading = false;



  ThemePalette get palette => _palette;

  bool get hasCompletedCheckIn => _hasCompletedCheckIn;

  bool get isLoading => _isLoading;



  ThemeData get themeData => _palette.toThemeData();



  Future<void> loadSavedTheme(ApiService api) async {

    _isLoading = true;

    notifyListeners();



    try {

      final saved = await api.fetchSelectedTheme();

      if (saved != null) {

        _palette = saved;

        _hasCompletedCheckIn = true;

      }

    } catch (_) {

      // No saved theme or backend unavailable — user goes through check-in.

    } finally {

      _isLoading = false;

      notifyListeners();

    }

  }



  Future<void> selectPalette(ThemePalette palette, ApiService api) async {

    await api.selectTheme(palette.id);

    _palette = palette;

    _hasCompletedCheckIn = true;

    notifyListeners();

  }



  void applyPaletteLocally(ThemePalette palette) {

    _palette = palette;

    _hasCompletedCheckIn = true;

    notifyListeners();

  }



  void resetCheckIn() {

    // Reset completion flag and restore default palette
    _hasCompletedCheckIn = false;
    _palette = allThemePalettes[6];
    notifyListeners();

  }

}


