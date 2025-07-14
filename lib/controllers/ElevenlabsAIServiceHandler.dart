import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ElevenlabsAIServiceHandler {
  static final ElevenlabsAIServiceHandler _instance =
      ElevenlabsAIServiceHandler._internal();
  factory ElevenlabsAIServiceHandler() => _instance;
  ElevenlabsAIServiceHandler._internal();

  static ElevenlabsAIServiceHandler get instance => _instance;

  final String _voiceId =
      'GbyJnDVkBLrjvxSBZY0v'; // Rachel's voice, can be changed
  final String _baseUrl = 'https://api.elevenlabs.io/v1/text-to-speech/';

  Future<List<int>?> textToSpeech(String text) async {
    final apiKey = dotenv.env['EL_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;
    final url = '$_baseUrl$_voiceId';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'accept': 'audio/mpeg',
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "text": text,
        "model_id": "eleven_monolingual_v1",
        "voice_settings": {"stability": .15, "similarity_boost": .75}
      }),
    );
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      return null;
    }
  }

  Future<String?> downloadAudio(String text, String fileName) async {
    final apiKey = dotenv.env['EL_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      print('API key is empty');
      return null;
    }

    final url = '$_baseUrl$_voiceId';
    print('Downloading audio from: $url');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'accept': 'audio/mpeg',
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "text": text,
        "model_id": "eleven_monolingual_v1",
        "voice_settings": {"stability": .15, "similarity_boost": .75}
      }),
    );

    print('Response status: ${response.statusCode}');
    print('Response body length: ${response.bodyBytes.length}');

    if (response.statusCode == 200) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        print('App documents directory: ${directory.path}');

        final audioDir = Directory('${directory.path}/audio_downloads');
        print('Audio directory path: ${audioDir.path}');

        if (!await audioDir.exists()) {
          print('Creating audio directory...');
          await audioDir.create(recursive: true);
        }

        final file = File('${audioDir.path}/$fileName.mp3');
        print('Saving file to: ${file.path}');

        await file.writeAsBytes(response.bodyBytes);

        final fileExists = await file.exists();
        final fileSize = await file.length();
        print('File saved successfully: $fileExists, size: $fileSize bytes');

        return file.path;
      } catch (e) {
        print('Error saving audio file: $e');
        return null;
      }
    } else {
      print('API request failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    }
  }

  Future<List<String>> getDownloadedAudioFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      print('Looking for files in: ${directory.path}');

      final audioDir = Directory('${directory.path}/audio_downloads');
      print('Audio directory: ${audioDir.path}');

      if (!await audioDir.exists()) {
        print('Audio directory does not exist');
        return [];
      }

      final files = await audioDir.list().toList();
      print('Found ${files.length} files in directory');

      final audioFiles = files
          .where((file) => file is File && file.path.endsWith('.mp3'))
          .map((file) => file.path)
          .toList();

      print('Found ${audioFiles.length} audio files:');
      for (final file in audioFiles) {
        print('  - $file');
      }

      return audioFiles;
    } catch (e) {
      print('Error getting downloaded files: $e');
      return [];
    }
  }

  Future<bool> testFileSystem() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      print('Testing file system access...');
      print('Documents directory: ${directory.path}');

      final testDir = Directory('${directory.path}/test_dir');
      await testDir.create(recursive: true);

      final testFile = File('${testDir.path}/test.txt');
      await testFile.writeAsString('Test content');

      final exists = await testFile.exists();
      final content = await testFile.readAsString();

      print('Test file created: $exists');
      print('Test file content: $content');

      await testFile.delete();
      await testDir.delete();

      return true;
    } catch (e) {
      print('File system test failed: $e');
      return false;
    }
  }

  Future<String?> copyToDownloads(String filePath) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        print('Storage permission not granted');
        return null;
      }

      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        print('Source file does not exist: $filePath');
        return null;
      }

      // Get the Downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = Directory('/storage/emulated/0/Downloads');
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        print('Downloads directory not found');
        return null;
      }

      final fileName = filePath.split('/').last;
      final destinationFile = File('${downloadsDir.path}/$fileName');

      await sourceFile.copy(destinationFile.path);
      print('File copied to Downloads: ${destinationFile.path}');

      return destinationFile.path;
    } catch (e) {
      print('Error copying file to Downloads: $e');
      return null;
    }
  }

  // Speech to Text using ElevenLabs API
  Future<String?> speechToText(String filePath) async {
    print('[STT] Starting speech-to-text for file: $filePath');
    final apiKey = dotenv.env['EL_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      print('[STT] API key is empty');
      return null;
    }
    print('[STT] API key found, length: ${apiKey.length}');
    final url = 'https://api.elevenlabs.io/v1/speech-to-text';
    print('[STT] Using URL: $url');
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['xi-api-key'] = apiKey;
      request.headers['Accept'] = 'application/json';
      print('[STT] Adding file to request: $filePath');
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      // Optionally add model_id, language, diarize, detect_language
      request.fields['model_id'] = 'scribe_v1';
      print('[STT] Request fields: ${request.fields}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print('[STT] Response status: ${response.statusCode}');
      print('[STT] Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[STT] Parsed response data: $data');
        return data['text'] ?? '';
      } else {
        print(
            '[STT] Speech-to-text failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('[STT] Exception in speechToText: ${e.toString()}');
      return null;
    }
  }
}
