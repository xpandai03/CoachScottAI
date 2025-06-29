import 'package:flutter/material.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'dart:io';

import '../controllers/OpenAIServiceHandler.dart';

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
    "How to bond with my horse?",
    "How to bond with my horse?",
    "How to bond with my horse?",
    "How to bond with my horse?",
    "How to bond with my horse?",
    "How to bond with my horse?",
  ];

  List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool hasStartedChat = false;

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
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sendStarterMessage,
                ),
              ],
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
    final bottomPadding = Platform.isIOS
        ? MediaQuery.of(context).padding.bottom + 60 // adjust as needed
        : 16; // minimal padding on Android
    // final bottomPadding = MediaQuery.of(context)R.padding.bottom +
    //     80; // 80 = estimated height of BottomNav

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
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.all(16),
              children: messages.reversed
                  .map((msg) => Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
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
                      ))
                  .toList(),
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
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sendChatMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void sendStarterMessage() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(trimmed, true);

    setState(() {
      messages.add(userMsg);
      hasStartedChat = true;
    });

    _controller.clear();

    // Simulate agent reply
    OpenAIServiceHandler.instance.sendMessage(userMsg.text).then((reply) {
      final agentMsg = ChatMessage(reply, false);
      setState(() {
        messages.add(agentMsg);
      });
    });
  }

  void sendChatMessage() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(trimmed, true);

    setState(() {
      messages.add(userMsg);
    });

    _controller.clear();

    // Simulate agent reply
    OpenAIServiceHandler.instance.sendMessage(userMsg.text).then((reply) {
      final agentMsg = ChatMessage(reply, false);
      setState(() {
        messages.add(agentMsg);
      });
    });
  }

  void handleQuickAction(String text) {
    _controller.text = text;
    sendStarterMessage();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}
