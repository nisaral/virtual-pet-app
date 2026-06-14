import 'package:flutter/material.dart';
import 'features/pet/presentation/pages/pet_home_page.dart';
import 'features/chat/presentation/pages/chat_page.dart';
import 'features/memories/presentation/pages/memory_journal_page.dart';

class VirtualPetApp extends StatelessWidget {
  const VirtualPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whale & Co. - Virtual Pet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Cute, soft feel
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    PetHomePage(),
    ChatPage(),
    MemoryJournalPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pets),
            selectedIcon: Icon(Icons.pets),
            label: 'Pet',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Talk',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Memories',
          ),
        ],
      ),
    );
  }
}
