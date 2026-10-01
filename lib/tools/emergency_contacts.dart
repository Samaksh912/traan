import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsPage extends StatefulWidget {
  final bool onboarding;
  const EmergencyContactsPage({super.key, this.onboarding = false});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  static const _prefsKey = 'emergency_contacts';

  List<Map<String, String>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? [];
      _contacts = raw
          .map((e) => Map<String, String>.from(jsonDecode(e) as Map))
          .toList();
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _prefsKey, _contacts.map((c) => jsonEncode(c)).toList());
    } catch (e) {
      debugPrint('Error saving contacts: $e');
    }
  }

  Future<void> _call(String number) async {
    try {
      final ok = await FlutterPhoneDirectCaller.callNumber(number);
      if (ok == true) return;
    } catch (e) {
      debugPrint('Direct call failed: $e');
    }
    // Fallback: open the dialer with the number filled in.
    try {
      await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (e) {
      debugPrint('Dialer fallback failed: $e');
    }
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    numberCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (saved == true) {
      setState(() {
        _contacts.add({
          'name': nameCtrl.text.trim(),
          'number': numberCtrl.text.trim(),
        });
      });
      await _save();
    }
    nameCtrl.dispose();
    numberCtrl.dispose();
  }

  Future<void> _delete(int index) async {
    setState(() => _contacts.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: widget.onboarding
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'The SOS button on the home screen calls the first contact in this list.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child:
                            Text(_contacts.isEmpty ? 'Skip for now' : 'Done'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No contacts yet.\nTap the button below to add someone you trust.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      itemBuilder: (context, i) {
                        final c = _contacts[i];
                        return Card(
                          elevation: 3,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade50,
                              child: Text(
                                c['name']!.isNotEmpty
                                    ? c['name']![0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: Colors.red.shade400),
                              ),
                            ),
                            title: Text(c['name']!),
                            subtitle: Text(c['number']!),
                            onTap: () => _call(c['number']!),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call,
                                      color: Colors.green),
                                  onPressed: () => _call(c['number']!),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(i),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
