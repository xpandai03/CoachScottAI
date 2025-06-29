import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIServiceHandler {
  // Singleton instance
  OpenAIServiceHandler._internal() {
    // Initialize OpenAI with your API key here
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    // print('API Key loaded: ${apiKey.isNotEmpty ? 'Yes' : 'No'}');
    // print('API Key length: ${apiKey.length}');
    OpenAI.apiKey = apiKey;
  }
  static final OpenAIServiceHandler _instance =
      OpenAIServiceHandler._internal();
  factory OpenAIServiceHandler() => _instance;

  // Getter for the singleton instance
  static OpenAIServiceHandler get instance => _instance;

  /// Sends a message prompt to GPT-3.5 Turbo and returns the assistant's reply as a Future<String>.
  Future<String> sendMessage(String prompt) async {
    try {
      final chatCompletion = await OpenAI.instance.chat.create(
        model: "gpt-3.5-turbo",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt)
            ],
          ),
        ],
      );

      // Extract the assistant's reply
      final message = chatCompletion.choices.first.message.content;
      return message?.first.text ?? "No response received";
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }
}
