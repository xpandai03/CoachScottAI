import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenAIServiceHandler {
  OpenAIServiceHandler._internal() {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    OpenAI.apiKey = apiKey;
  }

  static final OpenAIServiceHandler _instance =
      OpenAIServiceHandler._internal();
  factory OpenAIServiceHandler() => _instance;
  static OpenAIServiceHandler get instance => _instance;

  static const String assistantId = "asst_06sj5OxUN9smMeSa1N1oiCU2";
  static const String baseUrl = "https://api.openai.com/v1";
  String? _currentThreadId;

  Future<String> createNewThread() async {
    final apiKey = dotenv.env['OPENAI_KEY'] ?? '';
    if (apiKey.isEmpty) return '';

    final threadResponse = await http.post(
      Uri.parse('$baseUrl/threads'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'assistants=v2',
      },
    );

    if (threadResponse.statusCode == 201 || threadResponse.statusCode == 200) {
      final threadId = json.decode(threadResponse.body)['id'];
      _currentThreadId = threadId;
      return threadId;
    }
    return '';
  }

  void resetThread() {
    _currentThreadId = null;
  }

  String get threadId => _currentThreadId ?? '';

  Future<String> sendMessage(String prompt) async {
    print("hhh: $prompt");
    try {
      final apiKey = dotenv.env['OPENAI_KEY'] ?? '';
      if (apiKey.isEmpty) return "Error: OpenAI API key not found";

      if (_currentThreadId == null) {
        await createNewThread();
      }

      // 2. Add user message
      final messageResponse = await http.post(
        Uri.parse('$baseUrl/threads/${this.threadId}/messages'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'OpenAI-Beta': 'assistants=v2',
        },
        body: json.encode({
          'role': 'user',
          'content': prompt,
        }),
      );

      if (messageResponse.statusCode != 201 &&
          messageResponse.statusCode != 200) {
        return "Error adding message: ${messageResponse.statusCode} - ${messageResponse.body}";
      }

      // 3. Create a run
      final runResponse = await http.post(
        Uri.parse('$baseUrl/threads/${this.threadId}/runs'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'OpenAI-Beta': 'assistants=v2',
        },
        body: json.encode({
          'assistant_id': assistantId,
        }),
      );

      if (runResponse.statusCode != 201 && runResponse.statusCode != 200) {
        return "Error creating run: ${runResponse.statusCode} - ${runResponse.body} - ${threadId}";
      }

      final runId = json.decode(runResponse.body)['id'];

      // 4. Poll for run completion
      String runStatus = 'queued';
      while (runStatus == 'queued' || runStatus == 'in_progress') {
        await Future.delayed(Duration(seconds: 1));
        final statusResponse = await http.get(
          Uri.parse('$baseUrl/threads/${this.threadId}/runs/$runId'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'OpenAI-Beta': 'assistants=v2',
          },
        );

        if (statusResponse.statusCode == 200) {
          runStatus = json.decode(statusResponse.body)['status'];
        } else {
          return "Error checking run status: ${statusResponse.statusCode}";
        }
      }

      // 5. If successful, read assistant reply
      if (runStatus == 'completed') {
        final messagesResponse = await http.get(
          Uri.parse('$baseUrl/threads/${this.threadId}/messages'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'OpenAI-Beta': 'assistants=v2',
          },
        );

        if (messagesResponse.statusCode == 200) {
          final messages = json.decode(messagesResponse.body)['data'] as List;

          // Find the assistant message with the latest 'created_at' timestamp
          final assistantMessages =
              messages.where((msg) => msg['role'] == 'assistant').toList();

          if (assistantMessages.isNotEmpty) {
            assistantMessages.sort((a, b) =>
                (b['created_at'] as int).compareTo(a['created_at'] as int));
            final latest = assistantMessages.first;
            final contents = latest['content'] as List;
            for (final item in contents) {
              if (item['type'] == 'text') {
                return item['text']['value'] ?? "No text found";
              }
            }
          }
        }

        return "No assistant message found.";
      } else {
        return "Run failed with status: $runStatus";
      }
    } catch (e) {
      return "Exception: ${e.toString()}";
    }
  }

  Future<List<Map<String, dynamic>>> fetchThreadMessages() async {
    final apiKey = dotenv.env['OPENAI_KEY'] ?? '';
    if (apiKey.isEmpty) return [];

    final messagesResponse = await http.get(
      Uri.parse('$baseUrl/threads/${this.threadId}/messages'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'OpenAI-Beta': 'assistants=v2',
      },
    );

    if (messagesResponse.statusCode == 200) {
      final messages = json.decode(messagesResponse.body)['data'] as List;
      return messages.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
