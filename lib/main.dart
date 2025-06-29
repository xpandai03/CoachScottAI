import 'package:flutter/material.dart';
import 'package:flutter_openai/view/agentChatView.dart';
import 'package:flutter_openai/view/previewCanvasView.dart';
import 'package:flutter_openai/view/settingsView.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  print(
      'Environment loaded. API Key available: ${dotenv.env['OPENAI_API_KEY']?.isNotEmpty ?? false}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiquidGlassApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 31, 10, 67)),
        useMaterial3: true,
      ),
      home: const MainTabView(),
    );
  }
}

class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    const AgentChatView(),
    const Center(child: Text('Voice Chat View')),
    const PreviewCanvasView(),
    const SettingsView(),
    // const Center(child: Text('Agent Chat View')),
    // const Center(child: Text('Preview Canvas View')),
    // const Center(child: Text('Settings View')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
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
            ),
            SafeArea(
                child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.of(context).size.height -
                      kBottomNavigationBarHeight -
                      32,
                ),
                child: pages[selectedIndex],
              ),
            )),

            //Glassmorphic Bottom Navigation Bar
            SafeArea(
                child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: GlassContainer(
                    height: 60,
                    width: double.infinity,
                    blur: 15,
                    color: Colors.white.withOpacity(0.2),
                    // borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                    child: ClipRRect(
                      // borderRadius: BorderRadius.circular(28),
                      child: BottomNavigationBar(
                        type: BottomNavigationBarType.fixed,
                        currentIndex: selectedIndex,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        selectedItemColor: Colors.blueAccent,
                        unselectedItemColor: Colors.white70,
                        showSelectedLabels: true,
                        showUnselectedLabels: true,
                        onTap: (index) => setState(() => selectedIndex = index),
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.message),
                            label: "Chat",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.voice_chat),
                            label: "Voice",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.view_carousel),
                            label: "Lessons",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.settings),
                            label: "Settings",
                          ),
                        ],
                      ),
                    )),
              ),
            ))
          ],
        ));
  }
}
