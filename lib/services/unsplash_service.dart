import 'dart:convert';
import 'package:http/http.dart' as http;

class UnsplashService {
  static const String _baseUrl = 'https://api.unsplash.com';
  final String _accessKey;

  UnsplashService(this._accessKey);

  Future<List<Map<String, dynamic>>> getRandomPhotos({int count = 10}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/photos/random?count=$count'),
      headers: {
        'Authorization': 'Client-ID $_accessKey',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load photos');
    }
  }

  Future<List<Map<String, dynamic>>> searchPhotos(String query, {int page = 1, int perPage = 10}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/search/photos?query=$query&page=$page&per_page=$perPage'),
      headers: {
        'Authorization': 'Client-ID $_accessKey',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to search photos');
    }
  }

  Future<String> getRandomImageUrl() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/photos/random'),
      headers: {
        'Authorization': 'Client-ID $_accessKey',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['urls']['regular'];
    } else {
      throw Exception('Failed to load random image');
    }
  }

  Future<List<String>> getImageList({int perPage = 30, int page = 1, String? category}) async {
    final uri = category == null || category == '全部'
        ? Uri.parse('$_baseUrl/photos?per_page=$perPage&page=$page&w=200&h=200&fit=crop')
        : Uri.parse('$_baseUrl/search/photos?query=$category&per_page=$perPage&page=$page&w=200&h=200&fit=crop');
    
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Client-ID $_accessKey',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map<String>((photo) => photo['urls']['regular'] as String).toList();
    } else {
      throw Exception('Failed to load image list');
    }
  }
}
