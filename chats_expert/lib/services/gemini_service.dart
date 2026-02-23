import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class GeminiService {
  static const String apiKey = '';

  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<String> sendMessage({
    required String systemPrompt,
    required List<ChatMessage> conversationHistory,
    required String newUserMessage,
  }) async {
    try {
      final contents = _formatMessagesWithStrictSystem(
        systemPrompt,
        conversationHistory,
        newUserMessage,
      );

      print('📤 Sending to: $apiUrl');
      print('🔑 API Key: ${apiKey.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
        }),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {

          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return 'Error: Unexpected response format - ${response.body}';
        }
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        return 'Error 400: ${errorData['error']['message'] ?? 'Bad Request'}';
      } else if (response.statusCode == 403) {
        return 'Error 403: API key denied. Check https://aistudio.google.com/apikey';
      } else if (response.statusCode == 404) {
        return 'Error 404: Model not found';
      } else {
        return 'Error ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      print('❌ Exception: $e');
      return 'Network Error: $e';
    }
  }

  static List<Map<String, dynamic>> _formatMessagesWithStrictSystem(
      String systemPrompt,
      List<ChatMessage> history,
      String newMessage,
      ) {
    List<Map<String, dynamic>> contents = [];

    // System Prompt Pattern for Gemini
    contents.add({
      'role': 'user',
      'parts': [{'text': systemPrompt}],
    });
    contents.add({
      'role': 'model',
      'parts': [{'text': 'Understood. I will operate strictly within those parameters.'}],
    });

    for (var msg in history) {
      contents.add({
        'role': msg.role == 'user' ? 'user' : 'model',
        'parts': [{'text': msg.text}],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [{'text': '$newMessage\n\n(Remember to stay in character/domain.)'}],
    });

    return contents;
  }
}
