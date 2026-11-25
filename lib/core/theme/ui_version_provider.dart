import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which UI the app shows: the redesigned one (v2, default) or the original one (v1).
///
/// The switch is in Cá nhân → Cài đặt ứng dụng → "Giao diện mới", and is remembered on the device.
/// Rollback for everyone: set [kDefaultNewUi] to false (or remove the v2 theme / screens).
const bool kDefaultNewUi = true;

class UiVersionProvider extends ChangeNotifier {
  static const _key = 'ui-version';

  bool _newUi = kDefaultNewUi;
  bool get isNewUi => _newUi;

  UiVersionProvider() {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      if (v != null) {
        _newUi = v == 'v2';
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setNewUi(bool value) async {
    if (_newUi == value) return;
    _newUi = value;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, value ? 'v2' : 'v1');
    } catch (_) {}
  }
}
