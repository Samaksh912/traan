class NewsModel {
  final String title;
  final String description;
  final String source;
  final String urlToImage;

  NewsModel({
    required this.title,
    required this.description,
    required this.source,
    required this.urlToImage,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? 'No Description',
      source: json['source']['name'] ?? 'Unknown Source',
      urlToImage: json['urlToImage'] ?? '',
    );
  }
}
