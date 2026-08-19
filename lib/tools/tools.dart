import 'dart:async';
import 'package:flutter/material.dart';
import '../pages/defensetools.dart';
import '../pages/emergencynumbers.dart';
import '../pages/newsmodel.dart';
import '../pages/safetytips.dart';
import '../pages/selfdefense.dart';
import '../widgets/cards.dart';
import '../widgets/toolscard.dart';
import 'fetchnews.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  late Future<List<NewsModel>> crimeNews;
  late PageController _pageController;
  int _currentIndex = 0;
  int _newsCount = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    crimeNews = NewsService().fetchCrimeNews();
    _pageController = PageController();

    crimeNews.then((newsList) {
      if (!mounted) return;
      setState(() {
        _newsCount = newsList.length;
      });
      _startAutoScroll();
    }).catchError((_) {
      // No auto-scroll if the news fetch failed; error is shown by FutureBuilder.
    });
  }

  void _startAutoScroll() {
    if (_newsCount <= 1) return; // nothing to scroll between

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_pageController.hasClients) return;

      _currentIndex = (_currentIndex + 1) % _newsCount;

      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(  // Ensure the whole screen can be scrolled
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: FutureBuilder<List<NewsModel>>(
                future: crimeNews, // Now this is properly initialized
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (snapshot.hasData) {
                    final newsList = snapshot.data!;
                    if (newsList.isEmpty) {
                      return const Center(child: Text('No crime-related news available.'));
                    }
                    return SizedBox(
                      height: 300,  // Set fixed height for the swipeable area
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: newsList.length,
                        itemBuilder: (context, index) {
                          final news = newsList[index];
                          return GestureDetector(
                            onTap: () {
                              // Action when the card is tapped (e.g., navigate to another page)
                              debugPrint("Card tapped: ${news.title}");
                            },
                            child: Card(
                              margin: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (news.urlToImage.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Image.network(
                                        news.urlToImage,
                                        height: 80,
                                        width: 480,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          // Provide a fallback image if the network image fails to load
                                          return Image.asset(
                                            'assets/images/default_image.png',
                                            height: 200,
                                            width: 200,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          news.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          news.description,
                                          style: const TextStyle(
                                              fontSize: 14, color: Colors.grey),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  } else {
                    return const Center(child: Text('No crime-related news available.'));
                  }
                },
              ),
            ),
            // Four static cards below the news section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ToolsCard(title: "Safety Tips", imageUrl: "assets/images/tips.png", page: SafetyTipsPage()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ToolsCard(title: "Defense Tools", imageUrl: "assets/images/tool.png", page: DefenseToolsPage()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child:ToolsCard(title: "Self Defense", imageUrl: "assets/images/self1.png", page: SelfDefensePage()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ToolsCard(title: "Emergency", imageUrl: "assets/images/alert.png", page: EmergencyContactsPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}