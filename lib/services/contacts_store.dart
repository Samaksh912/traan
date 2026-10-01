import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsStore {
  static const _contactsKey = 'emergency_contacts';
  static const _promptShownKey = 'contacts_prompt_shown';

  static Future<List<Map<String, String>>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_contactsKey) ?? [];
      return raw
          .map((e) => Map<String, String>.from(jsonDecode(e) as Map))
          .toList();
    } catch (e) {
      debugPrint('ContactsStore.load error: $e');
      return [];
    }
  }

  /// The first contact in the list is the primary one.
  static Future<Map<String, String>?> primary() async {
    final list = await load();
    return list.isEmpty ? null : list.first;
  }

  /// True only the first time the app is opened, and only if no contact exists.
  static Future<bool> shouldPromptFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_promptShownKey) ?? false) return false;
      await prefs.setBool(_promptShownKey, true);
      final list = await load();
      return list.isEmpty;
    } catch (e) {
      debugPrint('ContactsStore.shouldPromptFirstTime error: $e');
      return false;
    }
  }
}
