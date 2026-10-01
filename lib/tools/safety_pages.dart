import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Shared layout for the Safety Tips screen ────────────────────────────────
class _InfoItem {
  final IconData icon;
  final String title;
  final String body;
  const _InfoItem(this.icon, this.title, this.body);
}

class _InfoListPage extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;
  const _InfoListPage({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, color: Colors.red.shade400, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.body,
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
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

// ─── Safety Tips ─────────────────────────────────────────────────────────────
class SafetyTipsPage extends StatelessWidget {
  const SafetyTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoListPage(
      title: 'Safety Tips',
      items: [
        _InfoItem(Icons.visibility, 'Stay aware',
            'Keep your phone out of your hands and your headphones at low volume in unfamiliar or isolated areas.'),
        _InfoItem(Icons.share_location, 'Share your location',
            'Let a trusted person know your route and expected arrival time when travelling alone, especially at night.'),
        _InfoItem(Icons.directions_walk, 'Choose busy, well-lit routes',
            'Avoid shortcuts through empty streets, even if they save time.'),
        _InfoItem(Icons.local_taxi, 'Verify your ride',
            'Check the vehicle number and driver details before getting in, and share the trip details with someone.'),
        _InfoItem(Icons.psychology, 'Trust your instincts',
            'If a situation feels wrong, leave early. You do not owe anyone politeness at the cost of your safety.'),
        _InfoItem(Icons.battery_charging_full, 'Keep your phone ready',
            'Keep the battery charged and save emergency contacts so you can reach them quickly.'),
      ],
    );
  }
}

// ─── Defense Tools (with purchase links) ─────────────────────────────────────
class _Tool {
  final IconData icon;
  final String title;
  final String body;
  final String query; // what to search for in the shops
  const _Tool(this.icon, this.title, this.body, this.query);
}

class DefenseToolsPage extends StatelessWidget {
  const DefenseToolsPage({super.key});

  static const List<_Tool> _tools = [
    _Tool(
        Icons.campaign,
        'Personal safety alarm',
        'A loud keychain alarm draws attention and can startle an attacker. Keep it easy to reach, not buried in a bag.',
        'personal safety alarm keychain'),
    _Tool(
        Icons.notifications_active,
        'Whistle',
        'Cheap, light, and effective for attracting help. Wear it on a keychain or lanyard.',
        'emergency safety whistle'),
    _Tool(
        Icons.flashlight_on,
        'Rechargeable torch',
        'A bright torch helps you see your surroundings and can disorient someone if shone at their eyes.',
        'rechargeable led torch'),
    _Tool(
        Icons.spa,
        'Pepper spray',
        'Check the rules that apply in your area before carrying it. Learn how to use it and keep it accessible.',
        'pepper spray for women self defence'),
    _Tool(
        Icons.key,
        'Self-defense keychain',
        'A sturdy keychain tool you can hold in your hand while walking to your door or vehicle.',
        'self defence keychain for women'),
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
        title: const Text('Defense Tools'),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _tools.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final t = _tools[i];
              final amazon = Uri.https('www.amazon.in', '/s', {'k': t.query});
              final flipkart =
                  Uri.https('www.flipkart.com', '/search', {'q': t.query});
              return Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(t.icon, color: Colors.red.shade400, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.body,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _open(context, amazon),
                              icon: const Icon(Icons.shopping_cart_outlined,
                                  size: 18),
                              label: const Text('Amazon'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _open(context, flipkart),
                              icon: const Icon(Icons.shopping_bag_outlined,
                                  size: 18),
                              label: const Text('Flipkart'),
                            ),
                          ),
                        ],
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
