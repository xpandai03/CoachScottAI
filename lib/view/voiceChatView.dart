import 'package:flutter/material.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'dart:io';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../controllers/ElevenlabsAIServiceHandler.dart';
import '../controllers/voiceRecordController.dart';
import '../controllers/OpenAIServiceHandler.dart';
import 'package:path_provider/path_provider.dart';

class VoiceChatView extends StatefulWidget {
  const VoiceChatView({super.key});
  @override
  State<VoiceChatView> createState() => _VoiceChatViewState();
}

class _VoiceChatViewState extends State<VoiceChatView> {
  List<ChatMessage> messages = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isLoading = false;

  // Voice recording
  late VoiceRecordController _voiceController;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  String? _currentRecordingPath;

  int? playingIndex;
  // Fix: Import 'dart:async' for StreamSubscription
  // Import 'dart:async' at the top of your file:
  // import 'dart:async';
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _initVoiceController();
  }

  Future<void> _initVoiceController() async {
    _voiceController = VoiceRecordController(
      onRecordTick: (duration) {
        setState(() {
          _recordDuration = duration;
        });
      },
      onRecordComplete: (filePath) async {
        setState(() {
          _isRecording = false;
          _currentRecordingPath = filePath;
        });
        if (filePath != null) {
          await _handleVoiceMessage(filePath);
        }
      },
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _voiceController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(102, 179, 255, 1),
              Color.fromRGBO(153, 102, 255, 1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: chatView(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget chatView() {
    final bottomPadding =
        Platform.isIOS ? MediaQuery.of(context).padding.bottom + 100 : 16;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding.toDouble()),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassContainer(
                blur: 8,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("Voice Chat",
                      style: TextStyle(fontSize: 22, color: Colors.white)),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.all(16),
              children: messages.reversed.toList().asMap().entries.map((entry) {
                final idx = messages.length - 1 - entry.key;
                final msg = entry.value;
                return VoiceMessageBubble(
                  isUser: msg.isUser,
                  duration: msg.duration,
                  audioPath: msg.audioPath,
                  isPlaying: playingIndex == idx,
                  onPlay: () {
                    if (playingIndex == idx) {
                      _audioPlayer.stop();
                    } else {
                      _playAudio(msg.audioPath, idx);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SpinKitThreeBounce(
                    color: Colors.white,
                    size: 24.0,
                  ),
                ],
              ),
            ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapDown: (_) => _startRecording(),
                  onTapUp: (_) => _stopRecording(),
                  onTapCancel: () => _stopRecording(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? Colors.red
                          : Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: _isRecording
                            ? Colors.red
                            : Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording ? Colors.white : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlassContainer(
                blur: 5,
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Recording... ${_formatDuration(_recordDuration)}',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startRecording() {
    if (!_isRecording) {
      _voiceController.startRecording();
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
    }
  }

  void _stopRecording() {
    if (_isRecording) {
      _voiceController.stopRecording();
    }
  }

  Future<void> _handleVoiceMessage(String filePath) async {
    setState(() {
      isLoading = true;
    });

    // Get the real duration
    final audioPlayer = AudioPlayer();
    await audioPlayer.setFilePath(filePath);
    final duration = audioPlayer.duration ?? Duration.zero;

    // Step 1: Convert speech to text
    final transcribedText =
        await ElevenlabsAIServiceHandler.instance.speechToText(filePath);
    if (mounted && transcribedText != null && transcribedText.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transcribed: $transcribedText'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    if (transcribedText == null || transcribedText.isEmpty) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not transcribe your message. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Step 2: Add user message to chat with real duration
    setState(() {
      messages.add(ChatMessage(
        isUser: true,
        audioPath: filePath,
        duration: duration,
      ));
    });

    // Step 3: Send to OpenAI and get response
    final response =
        await OpenAIServiceHandler.instance.sendMessage(transcribedText);

    if (mounted && response.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assistant Response: $response'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (response.isNotEmpty && !response.startsWith("Error")) {
      // Step 4: Get AI audio response
      final aiAudioBytes =
          await ElevenlabsAIServiceHandler.instance.textToSpeech(response);
      String? aiAudioPath;
      Duration aiDuration = Duration.zero;
      if (aiAudioBytes != null) {
        try {
          final dir = await getTemporaryDirectory();
          final file = File(
              '${dir.path}/ai_response_${DateTime.now().millisecondsSinceEpoch}.mp3');
          await file.writeAsBytes(aiAudioBytes);
          aiAudioPath = file.path;
          final aiPlayer = AudioPlayer();
          await aiPlayer.setFilePath(aiAudioPath);
          aiDuration = aiPlayer.duration ?? Duration.zero;
        } catch (e) {
          print('Error writing AI audio file: $e');
        }
      }
      setState(() {
        messages.add(ChatMessage(
          isUser: false,
          audioPath: aiAudioPath,
          duration: aiDuration,
        ));
      });
      // Optionally auto-play the AI response
      if (aiAudioPath != null) {
        await _playAudio(aiAudioPath, messages.length - 1);
      }
    } else {
      setState(() {
        messages.add(ChatMessage(
          isUser: false,
          audioPath: null,
          duration: Duration.zero,
        ));
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _playAudio(String? path, int index) async {
    if (path == null) return;
    try {
      await _audioPlayer.setFilePath(path);
      print('Play audio: $path');
      setState(() {
        playingIndex = index;
      });

      // Cancel previous subscription if any
      await _playerStateSubscription?.cancel();
      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            playingIndex = null;
          });
        }
      });

      await _audioPlayer.play();
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        playingIndex = null;
      });
    }
  }
}

class ChatMessage {
  final bool isUser;
  final String? audioPath;
  final Duration duration;

  ChatMessage({
    required this.isUser,
    required this.audioPath,
    required this.duration,
  });
}

class VoiceMessageBubble extends StatelessWidget {
  final bool isUser;
  final Duration duration;
  final String? audioPath;
  final VoidCallback? onPlay;
  final bool isPlaying;

  const VoiceMessageBubble({
    super.key,
    required this.isUser,
    required this.duration,
    required this.audioPath,
    this.onPlay,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? const Color(0xFFDCF8C6) : Colors.white;
    final textColor = isUser ? Colors.black : Colors.black87;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.green,
                size: 24,
              ),
              onPressed: onPlay,
            ),
            const SizedBox(width: 8),
            Container(
              width: 80,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
