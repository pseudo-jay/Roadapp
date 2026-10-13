import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'driving_monitor.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._driving);

  final DrivingMonitor _driving;
  SharedPreferences? _prefs;

  bool _voicePrompts = true;
  bool _onboarded = false;
  ThemeMode _themeMode = ThemeMode.system;

  bool get voicePrompts => _voicePrompts;
  bool get onboarded => _onboarded;
  ThemeMode get themeMode => _themeMode;
  DrivingOverride get drivingOverride => _driving.overrideMode;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    _voicePrompts = p.getBool('voicePrompts') ?? true;
    _onboarded = p.getBool('onboarded') ?? false;
    _themeMode = ThemeMode.values[p.getInt('themeMode') ?? 0];
    _driving.setOverride(
      DrivingOverride.values[p.getInt('drivingOverride') ?? 0],
    );
    notifyListeners();
  }

  void setVoicePrompts(bool v) {
    _voicePrompts = v;
    _prefs?.setBool('voicePrompts', v);
    notifyListeners();
  }

  void setOnboarded() {
    _onboarded = true;
    _prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    _themeMode = m;
    _prefs?.setInt('themeMode', m.index);
    notifyListeners();
  }

  void setDrivingOverride(DrivingOverride o) {
    _driving.setOverride(o);
    _prefs?.setInt('drivingOverride', o.index);
    notifyListeners();
  }
}
