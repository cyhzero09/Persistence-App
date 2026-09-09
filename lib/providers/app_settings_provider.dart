import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final int themeColor;
  final double fontSize;
  final ThemeMode brightness;
  final String language; // 'en' | 'zh' | 'zh_TW'
  final bool languageChosen;
  final bool initialized;
  final String backgroundImage; // base64，空 = 无背景图
  final double backgroundOpacity; // 0-1
  final Uint8List? backgroundBytes; // 非持久化，解码缓存避免重复解码

  const AppSettings({
    this.themeColor = 0xFF009688,
    this.fontSize = 1.0,
    this.brightness = ThemeMode.system,
    this.language = 'en',
    this.languageChosen = false,
    this.initialized = false,
    this.backgroundImage = '',
    this.backgroundOpacity = 0.2,
    this.backgroundBytes,
  });

  AppSettings copyWith({
    int? themeColor,
    double? fontSize,
    ThemeMode? brightness,
    String? language,
    bool? languageChosen,
    bool? initialized,
    String? backgroundImage,
    double? backgroundOpacity,
    Uint8List? backgroundBytes,
  }) => AppSettings(
    themeColor: themeColor ?? this.themeColor,
    fontSize: fontSize ?? this.fontSize,
    brightness: brightness ?? this.brightness,
    language: language ?? this.language,
    languageChosen: languageChosen ?? this.languageChosen,
    initialized: initialized ?? this.initialized,
    backgroundImage: backgroundImage ?? this.backgroundImage,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    backgroundBytes: backgroundBytes ?? this.backgroundBytes,
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
    final imageB64 = prefs.getString('backgroundImage') ?? '';
    state = AppSettings(
      themeColor: prefs.getInt('themeColor') ?? 0xFF009688,
      fontSize: prefs.getDouble('fontSize') ?? 1.0,
      brightness: brightnessFromPref(prefs.getString('brightness')),
      language: prefs.getString('language') ?? 'en',
      languageChosen: prefs.getBool('languageChosen') ?? false,
      initialized: true,
      backgroundImage: imageB64,
      backgroundOpacity: prefs.getDouble('backgroundOpacity') ?? 0.2,
      backgroundBytes: _decodeBackground(imageB64),
    );
  }

  Uint8List? _decodeBackground(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
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

  Future<void> setLanguage(String code) async {
    state = state.copyWith(language: code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
  }

  Future<void> markLanguageChosen() async {
    state = state.copyWith(languageChosen: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('languageChosen', true);
  }

  /// 设置背景图（base64）。返回 false 表示写入失败（如 Web 端 localStorage 配额超限）。
  Future<bool> setBackgroundImage(String base64, {Uint8List? bytes}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (base64.isEmpty) {
        await prefs.remove('backgroundImage');
      } else {
        await prefs.setString('backgroundImage', base64);
      }
    } catch (_) {
      return false;
    }
    if (base64.isEmpty) {
      // copyWith 的 ?? 模式无法置空，清除时直接重建
      state = AppSettings(
        themeColor: state.themeColor,
        fontSize: state.fontSize,
        brightness: state.brightness,
        language: state.language,
        languageChosen: state.languageChosen,
        initialized: state.initialized,
        backgroundOpacity: state.backgroundOpacity,
      );
    } else {
      state = state.copyWith(backgroundImage: base64, backgroundBytes: bytes);
    }
    return true;
  }

  Future<void> setBackgroundOpacity(double opacity) async {
    state = state.copyWith(backgroundOpacity: opacity);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('backgroundOpacity', opacity);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
