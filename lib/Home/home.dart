import 'package:geolocator/geolocator.dart';
import 'package:boxicons/boxicons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:raksha/models/sos.dart';
import 'package:raksha/pages/profile.dart';
import 'package:raksha/utils/colors.dart';
import 'package:raksha/widgets/cards.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Shield Mode State ────────────────────────────────────────────────────────

class ShieldModeState extends ChangeNotifier {
  bool _shieldActive = false;
  bool _audioEnabled = true;
  bool _videoEnabled = true;
  bool _locationEnabled = true;

  bool get shieldActive => _shieldActive;
  bool get audioEnabled => _audioEnabled;
  bool get videoEnabled => _videoEnabled;
  bool get locationEnabled => _locationEnabled;

  void toggleShield() {
    _shieldActive = !_shieldActive;
    notifyListeners();
  }

  void toggleAudio() {
    _audioEnabled = !_audioEnabled;
    notifyListeners();
  }

  void toggleVideo() {
    _videoEnabled = !_videoEnabled;
    notifyListeners();
  }

  void toggleLocation() {
    _locationEnabled = !_locationEnabled;
    notifyListeners();
  }
}

// ─── Home Page ────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final ShieldModeState _shieldState = ShieldModeState();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shieldState.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shieldState.dispose();
    super.dispose();
  }

  void _openShieldModeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShieldModeSheet(shieldState: _shieldState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool shieldOn = _shieldState.shieldActive;

    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Subtle shield-active background pulse
            if (shieldOn)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.2,
                      colors: [
                        const Color(0xFF1565C0).withOpacity(0.07 * (_pulseAnimation.value - 1) * 12.5 + 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Top bar ──────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.person, color: Color(ColorsValue().h5)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Home",
                                  style: TextStyle(
                                    color: Color(ColorsValue().h5),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // ── Shield Mode Button ────────────────────────────
                        GestureDetector(
                          onTap: _openShieldModeSheet,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: shieldOn ? const Color(0xFF1565C0) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: shieldOn ? const Color(0xFF1565C0) : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              boxShadow: shieldOn
                                  ? [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withOpacity(0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                )
                              ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: shieldOn ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                                  builder: (context, child) => Transform.scale(
                                    scale: shieldOn ? _pulseAnimation.value : 1.0,
                                    child: Icon(
                                      Icons.shield,
                                      size: 18,
                                      color: shieldOn ? Colors.white : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  shieldOn ? "Shield ON" : "Shield",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: shieldOn ? Colors.white : Colors.grey.shade600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (shieldOn) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF69F0AE),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Shield active indicator banner ────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      child: shieldOn
                          ? Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF90CAF9), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield, color: Color(0xFF1565C0), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Shield Mode is active — ${_activeTrackersSummary()}",
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _openShieldModeSheet,
                              child: const Text(
                                "Edit",
                                style: TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 40),

                    // ── SOS Section ───────────────────────────────────────
                    Text(
                      "Emergency!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(0),
                      child: ClipOval(
                        child: InkWell(
                          splashColor: Colors.black54,
                          onTap: () async {
                            try {
                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (!serviceEnabled) return;

                              LocationPermission permission = await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied) {
                                permission = await Geolocator.requestPermission();
                                if (permission == LocationPermission.denied) return;
                              }
                              if (permission == LocationPermission.deniedForever) return;

                              Position position = await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                              );

                              String locationUrl =
                                  "https://maps.google.com/?q=${position.latitude},${position.longitude}";
                              String message = "Emergency! My current location: $locationUrl";
                              String phoneNumber = "919627320508";
                              String whatsappUrl =
                                  "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}";

                              final Uri uri = Uri.parse(whatsappUrl);
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (e) {
                              debugPrint("Error sharing location: $e");
                            }
                          },
                          child: Ink.image(
                            image: const AssetImage('assets/images/sos.png'),
                            height: 205,
                            width: 205,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Press the button to send SOS",
                      style: TextStyle(
                        color: Color(ColorsValue().h5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Help Line Cards ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => _callNumber("7058384971"),
                          child: HelpLineCards(
                            title: "Police 100",
                            assetImg: "assets/images/pol.png",
                            number: "100",
                          ),
                        ),
                        InkWell(
                          onTap: () => _callNumber("9307227317"),
                          child: HelpLineCards(
                            title: "Women Helpline",
                            assetImg: "assets/images/contact.png",
                            number: "100",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activeTrackersSummary() {
    final List<String> active = [];
    if (_shieldState.audioEnabled) active.add("Audio");
    if (_shieldState.videoEnabled) active.add("Video");
    if (_shieldState.locationEnabled) active.add("Location");
    if (active.isEmpty) return "no trackers selected";
    return "${active.join(', ')} tracking";
  }

  _callNumber(String number) async {
    await FlutterPhoneDirectCaller.callNumber(number);
  }
}

// ─── Shield Mode Bottom Sheet ─────────────────────────────────────────────────

class _ShieldModeSheet extends StatefulWidget {
  final ShieldModeState shieldState;
  const _ShieldModeSheet({required this.shieldState});

  @override
  State<_ShieldModeSheet> createState() => _ShieldModeSheetState();
}

class _ShieldModeSheetState extends State<_ShieldModeSheet> {
  late bool _shieldActive;
  late bool _audio;
  late bool _video;
  late bool _location;

  @override
  void initState() {
    super.initState();
    _shieldActive = widget.shieldState.shieldActive;
    _audio = widget.shieldState.audioEnabled;
    _video = widget.shieldState.videoEnabled;
    _location = widget.shieldState.locationEnabled;
  }

  void _applyAndClose() {
    // Sync state back to shared state object
    if (_shieldActive != widget.shieldState.shieldActive) widget.shieldState.toggleShield();
    if (_audio != widget.shieldState.audioEnabled) widget.shieldState.toggleAudio();
    if (_video != widget.shieldState.videoEnabled) widget.shieldState.toggleVideo();
    if (_location != widget.shieldState.locationEnabled) widget.shieldState.toggleLocation();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _shieldActive ? const Color(0xFF1565C0) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shield,
                  color: _shieldActive ? Colors.white : Colors.grey.shade500,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Shield Mode",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Live tracking & recording protection",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Master toggle
              Switch(
                value: _shieldActive,
                onChanged: (val) => setState(() => _shieldActive = val),
                activeColor: const Color(0xFF1565C0),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Tracker options
          AnimatedOpacity(
            opacity: _shieldActive ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300),
            child: AbsorbPointer(
              absorbing: !_shieldActive,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose what to track",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TrackerTile(
                    icon: Icons.mic_rounded,
                    iconColor: const Color(0xFFE53935),
                    iconBg: const Color(0xFFFFEBEE),
                    title: "Audio Recording",
                    subtitle: "Captures ambient sound discreetly",
                    value: _audio,
                    onChanged: (val) => setState(() => _audio = val),
                  ),
                  const SizedBox(height: 12),
                  _TrackerTile(
                    icon: Icons.videocam_rounded,
                    iconColor: const Color(0xFF7B1FA2),
                    iconBg: const Color(0xFFF3E5F5),
                    title: "Video Recording",
                    subtitle: "Records front or rear camera feed",
                    value: _video,
                    onChanged: (val) => setState(() => _video = val),
                  ),
                  const SizedBox(height: 12),
                  _TrackerTile(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFF2E7D32),
                    iconBg: const Color(0xFFE8F5E9),
                    title: "Live Location",
                    subtitle: "Shares real-time GPS coordinates",
                    value: _location,
                    onChanged: (val) => setState(() => _location = val),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Status chip row (dummy indicators)
          if (_shieldActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Data is stored locally and shared only with your trusted contacts.",
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _shieldActive ? "Activate Shield Mode" : "Save Preferences",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tracker Tile Widget ──────────────────────────────────────────────────────

class _TrackerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TrackerTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: value ? iconBg.withOpacity(0.5) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? iconColor.withOpacity(0.3) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: value ? iconBg : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: value ? iconColor : Colors.grey.shade400, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value ? Colors.black87 : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }
}