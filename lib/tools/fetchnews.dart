import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../pages/newsmodel.dart';

class NewsService {
  static String get _apiKey => dotenv.env['NEWS_API_KEY'] ?? '';

  Future<List<NewsModel>> fetchCrimeNews() async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'NEWS_API_KEY is missing. Add it to your .env file.');
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://newsapi.org/v2/everything?q=kidnapping OR "sexual assault" OR molestation OR "human trafficking" OR "domestic violence" OR rape&language=en&sortBy=publishedAt&apiKey=$_apiKey'
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> articles = data['articles'] ?? [];

        return articles.map((item) => NewsModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load crime news (status ${response.statusCode})');
      }
    } catch (e) {
      debugPrintError('Error fetching crime news: $e');
      rethrow;
    }
  }

  void debugPrintError(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }
}