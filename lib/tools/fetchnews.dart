import 'dart:convert';
import 'package:http/http.dart' as http;

import '../pages/newsmodel.dart';

class NewsService {
  static const String _apiKey = '56ae4dd52d004239869b3b20a673c7f9';
  static const String _baseUrl = 'https://newsapi.org/v2/top-headlines';

  Future<List<NewsModel>> fetchCrimeNews() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://newsapi.org/v2/everything?q=kidnapping OR "sexual assault" OR molestation OR "human trafficking" OR "domestic violence" OR rape&language=en&sortBy=publishedAt&apiKey=$_apiKey'
        ),
      );


      if (response.statusCode == 200) {
        print('Response: ${response.body}'); // Log the response
        final Map<String, dynamic> data = jsonDecode(response.body); // Decode the response as a Map
        final List<dynamic> articles = data['articles']; // Extract the articles list

        // Map the list of articles to a list of NewsModel objects
        return articles.map((item) => NewsModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load crime news');
      }
    } catch (e) {
      print('Error: $e'); // Log the error
      rethrow; // Re-throw the error to be handled in the UI
    }
  }
}
