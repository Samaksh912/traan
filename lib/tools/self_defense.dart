import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class _Lesson {
  final IconData icon;
  final String title;
  final String body;
  final Uri url;
  const _Lesson(this.icon, this.title, this.body, this.url);
}

class SelfDefensePage extends StatelessWidget {
  const SelfDefensePage({super.key});

  static final List<_Lesson> _lessons = [
    _Lesson(
      Icons.sports_martial_arts,
      'Basic self defense moves',
      'Start with the fundamentals: stance, distance and simple strikes.',
      Uri.parse('https://youtu.be/KVpxP3ZZtAc'),
    ),
    _Lesson(
      Icons.pan_tool,
      'Escape a wrist grab',
      'How to break free when someone grabs your wrist.',
      Uri.parse('https://youtu.be/sY-P5GBwggU'),
    ),
    _Lesson(
      Icons.front_hand,
      'Palm-heel strike',
      'A strong, beginner-friendly strike that is safe for your hand.',
      Uri.parse('https://youtu.be/YtWGobxLV88'),
    ),
    _Lesson(
      Icons.accessibility_new,
      'Escape a bear hug or choke hold',
      'Techniques for getting out of a hold from the front or behind.',
      Uri.parse('https://youtu.be/PryZvCJ8ca4'),
    ),
    _Lesson(
      Icons.directions_walk,
      'Staying safe when walking alone',
      'Awareness habits that help you avoid risky situations.',
      Uri.parse('https://youtube.com/shorts/Omc0-i0HHQM'),
    ),
  ];

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (e) {
      debugPrint('Could not open $uri: $e');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Self Defense'),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _lessons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final l = _lessons[i];
              return Card(
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(l.icon, color: Colors.red.shade400, size: 28),
                  title: Text(
                    l.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.body),
                  ),
                  trailing: const Icon(Icons.play_circle_fill,
                      color: Colors.red, size: 32),
                  onTap: () => _open(context, l.url),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
