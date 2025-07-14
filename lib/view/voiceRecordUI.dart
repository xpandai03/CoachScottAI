import 'package:flutter/material.dart';
import '../controllers/voiceRecordController.dart';

class VoiceRecordUI extends StatefulWidget {
  const VoiceRecordUI({super.key});

  @override
  State<VoiceRecordUI> createState() => _VoiceRecordUIState();
}

class _VoiceRecordUIState extends State<VoiceRecordUI> {
  late VoiceRecordController _controller;
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordDuration = Duration.zero;
  List<String> _recordings = [];
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _controller = VoiceRecordController(
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
        await _loadRecordings();
      },
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      },
    );
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final recordings = await _controller.getAllRecordings();
    setState(() {
      _recordings = recordings;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
      appBar: AppBar(title: const Text('Voice Recorder')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    _isRecording ? 'Recording...' : 'Ready to record',
                    style: TextStyle(
                      color: _isRecording ? Colors.red : Colors.black,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        heroTag: 'record',
                        backgroundColor:
                            _isRecording ? Colors.red : Colors.blue,
                        child: Icon(_isRecording ? Icons.stop : Icons.mic,
                            size: 36),
                        onPressed: () async {
                          if (_isRecording) {
                            await _controller.stopRecording();
                          } else {
                            await _controller.startRecording();
                            setState(() {
                              _isRecording = true;
                              _recordDuration = Duration.zero;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 32),
                      FloatingActionButton(
                        heroTag: 'play',
                        backgroundColor: Colors.green,
                        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 36),
                        onPressed: _currentRecordingPath == null
                            ? null
                            : () async {
                                setState(() => _isPlaying = true);
                                await _controller
                                    .playRecording(_currentRecordingPath!);
                                setState(() => _isPlaying = false);
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Previous Recordings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recordings.isEmpty
                  ? const Center(child: Text('No recordings yet.'))
                  : ListView.builder(
                      itemCount: _recordings.length,
                      itemBuilder: (context, index) {
                        final path = _recordings[index];
                        final fileName = path.split('/').last;
                        return ListTile(
                          title: Text(fileName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () async {
                                  setState(() => _isPlaying = true);
                                  await _controller.playRecording(path);
                                  setState(() => _isPlaying = false);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  await _controller.deleteRecording(path);
                                  await _loadRecordings();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
