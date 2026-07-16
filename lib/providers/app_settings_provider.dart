import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final int themeColor;
  final double fontSize;
  final ThemeMode brightness;

  const AppSettings({
    this.themeColor = 0xFF009688,
    this.fontSize = 1.0,
    this.brightness = ThemeMode.system,
  });

  AppSettings copyWith({int? themeColor, double? fontSize, ThemeMode? brightness}) => AppSettings(
    themeColor: themeColor ?? this.themeColor,
    fontSize: fontSize ?? this.fontSize,
    brightness: brightness ?? this.brightness,
  );
}

String brightnessToPref(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

ThemeMode brightnessFromPref(String? val) => switch (val) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      themeColor: prefs.getInt('themeColor') ?? 0xFF009688,
      fontSize: prefs.getDouble('fontSize') ?? 1.0,
      brightness: brightnessFromPref(prefs.getString('brightness')),
    );
  }

  Future<void> setThemeColor(int color) async {
    state = state.copyWith(themeColor: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
  }

  Future<void> setBrightness(ThemeMode mode) async {
    state = state.copyWith(brightness: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('brightness', brightnessToPref(mode));
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
