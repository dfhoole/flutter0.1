import 'package:http/http.dart' as http;

class UnsplashService {
  final http.Client _client = http.Client();

  /// Fetches a random image URL from Unsplash.
  /// [size] The desired size of the image in the format "widthxheight" (e.g., "1080x1920").
  /// Returns a Future<String> representing the image URL. Throws an exception if the request fails.
  Future<String> getRandomImage(String size) async {
    final url = Uri.parse('https://source.unsplash.com/random/$size');

    try {
      final response = await _client.get(url);

      if (response.statusCode == 200) {
        return response.request!.url.toString(); // Return the image URL
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}
