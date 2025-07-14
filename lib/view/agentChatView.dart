import 'package:flutter/material.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'dart:io';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import '../controllers/OpenAIServiceHandler.dart';
import '../controllers/ElevenlabsAIServiceHandler.dart';
import '../controllers/voiceRecordController.dart';

class AgentChatView extends StatefulWidget {
  const AgentChatView({super.key});
  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  final List<String> quickActions = [
    "How do I improve my horse's canter?",
    "Tips for rider confidence?",
    "Fixing a buddy-sour horse?",
    "Daily groundwork routines?",
    "Overcoming fear of riding",
    "How to bond with my horse?",
  ];

  List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool hasStartedChat = false;
  bool isLoading = false;

  // TTS related variables
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlayingTTS = false;
  int? playingMessageIndex;

  // Voice recording
  late VoiceRecordController _voiceController;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _configureAudioSession();
    _initVoiceController();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _voiceController.dispose();
    super.dispose();
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
        });
        _handleSpeechToText(filePath);
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

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
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
        child: hasStartedChat ? chatView() : starterView(),
      ),
    );
  }

  Widget starterView() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.all(25),
            child: Text(
              "COACH SCOTT",
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w100,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    blur: 8,
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "What do you want to know?",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.white,
                    size: _isRecording ? 28 : 24,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _isRecording
                        ? Colors.white.withOpacity(0.3)
                        : Colors.transparent,
                    shape: CircleBorder(),
                  ),
                  onPressed: () {
                    if (_isRecording) {
                      _voiceController.stopRecording();
                    } else {
                      _voiceController.startRecording();
                      setState(() {
                        _isRecording = true;
                        _recordDuration = Duration.zero;
                      });
                    }
                  },
                  tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sendStarterMessage,
                ),
              ],
            ),
          ),
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
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
          const SizedBox(height: 36),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 12),
              children: quickActions
                  .map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: GlassContainer(
                          blur: 6,
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          child: ListTile(
                            title: Text(e,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white)),
                            onTap: () => handleQuickAction(e),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      );

  Widget chatView() {
    final bottomPadding =
        Platform.isIOS ? MediaQuery.of(context).padding.bottom + 60 : 16;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding.toDouble()),
      child: Column(
        children: [
          const SizedBox(height: 30),
          GlassContainer(
            blur: 8,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text("Coach Scott",
                  style: TextStyle(fontSize: 22, color: Colors.white)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final msg = messages[messages.length - 1 - index];
                final actualIndex = messages.length - 1 - index;
                final isCurrentlyPlaying =
                    playingMessageIndex == actualIndex && isPlayingTTS;

                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!msg.isUser)
                        IconButton(
                          icon: Icon(
                            isCurrentlyPlaying ? Icons.stop : Icons.volume_up,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => isCurrentlyPlaying
                              ? _stopTTS()
                              : _playTTS(msg.text, actualIndex),
                        ),
                      Flexible(
                        child: GlassContainer(
                          blur: 5,
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Text(msg.text,
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(
                left: 20.0,
              ),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    blur: 5,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        controller: _controller,
                        decoration:
                            const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.white,
                    size: _isRecording ? 28 : 24,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _isRecording
                        ? Colors.white.withOpacity(0.3)
                        : Colors.transparent,
                    shape: CircleBorder(),
                  ),
                  onPressed: () {
                    if (_isRecording) {
                      _voiceController.stopRecording();
                    } else {
                      _voiceController.startRecording();
                      setState(() {
                        _isRecording = true;
                        _recordDuration = Duration.zero;
                      });
                    }
                  },
                  tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sendChatMessage,
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

  Future<void> _handleSpeechToText(String filePath) async {
    setState(() {
      isLoading = true;
    });

    final text =
        await ElevenlabsAIServiceHandler.instance.speechToText(filePath);

    if (text != null && text.isNotEmpty) {
      _controller.text = text;

      if (!hasStartedChat) {
        sendStarterMessage();
      } else {
        sendChatMessage();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription completed!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription failed. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void sendStarterMessage() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(trimmed, true);

    setState(() {
      messages.add(userMsg);
      hasStartedChat = true;
      isLoading = true;
    });

    _controller.clear();

    await OpenAIServiceHandler.instance.sendMessage(userMsg.text);

    final threadMessages =
        await OpenAIServiceHandler.instance.fetchThreadMessages();
    setState(() {
      messages = threadMessages.reversed
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .map((msg) {
        final isUser = msg['role'] == 'user';
        final contentList = msg['content'] as List;
        final text = contentList.isNotEmpty && contentList[0]['type'] == 'text'
            ? contentList[0]['text']['value'] ?? ''
            : '';
        return ChatMessage(text, isUser);
      }).toList();
      isLoading = false;
    });
  }

  void sendChatMessage() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      messages.add(ChatMessage(trimmed, true));
      isLoading = true;
    });

    _controller.clear();

    await OpenAIServiceHandler.instance.sendMessage(trimmed);

    final threadMessages =
        await OpenAIServiceHandler.instance.fetchThreadMessages();
    setState(() {
      messages = threadMessages.reversed
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .map((msg) {
        final isUser = msg['role'] == 'user';
        final contentList = msg['content'] as List;
        final text = contentList.isNotEmpty && contentList[0]['type'] == 'text'
            ? contentList[0]['text']['value'] ?? ''
            : '';
        return ChatMessage(text, isUser);
      }).toList();
      isLoading = false;
    });
  }

  void handleQuickAction(String text) {
    _controller.text = text;
    sendStarterMessage();
  }

  // TTS Methods
  Future<void> _playTTS(String text, int idx) async {
    setState(() {
      isPlayingTTS = true;
      playingMessageIndex = idx;
    });

    try {
      final audioBytes =
          await ElevenlabsAIServiceHandler.instance.textToSpeech(text);
      if (audioBytes != null) {
        await _audioPlayer.setAudioSource(MyCustomSource(audioBytes));
        await _audioPlayer.play();

        // Listen for completion
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            setState(() {
              isPlayingTTS = false;
              playingMessageIndex = null;
            });
          }
        });
      } else {
        setState(() {
          isPlayingTTS = false;
          playingMessageIndex = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate speech'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isPlayingTTS = false;
        playingMessageIndex = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing speech: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopTTS() async {
    await _audioPlayer.stop();
    setState(() {
      isPlayingTTS = false;
      playingMessageIndex = null;
    });
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

// Custom Audio Source for playing audio bytes
class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
