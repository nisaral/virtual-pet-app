import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chrome.dart';
import 'controller.dart';
import 'models.dart';
import 'screens_home.dart';
import 'screens_play.dart';

class ValeApp extends StatelessWidget {
  const ValeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina Vale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ValeColors.cream,
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(seedColor: ValeColors.goldDeep, brightness: Brightness.light),
        splashFactory: NoSplash.splashFactory,
      ),
      home: const _Host(),
    );
  }
}

class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(valeProvider.notifier);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      controller.persist();
    } else if (state == AppLifecycleState.resumed) {
      controller.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(valeProvider);
    if (!state.booted) {
      return const Scaffold(
        backgroundColor: Color(0xFF79C4FF),
        body: Center(child: Text('Lumina Vale', style: ValeText.display)),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: KeyedSubtree(
        key: ValueKey(state.screen),
        child: switch (state.screen) {
          ValeScreen.title => const TitleScreen(),
          ValeScreen.naming => const NamingScreen(),
          ValeScreen.starter => const StarterScreen(),
          ValeScreen.den => const DenScreen(),
          ValeScreen.summary => const SummaryScreen(),
          ValeScreen.feed => const FeedScreen(),
          ValeScreen.groom => const GroomScreen(),
          ValeScreen.play => const PlayHub(),
          ValeScreen.pattern => const PatternScreen(),
          ValeScreen.ribbons => const RibbonScreen(),
          ValeScreen.spar => const SparScreen(),
          ValeScreen.outing => const OutingScreen(),
          ValeScreen.mind => const MindScreen(),
          ValeScreen.journal => const JournalScreen(),
          ValeScreen.evolve => const EvolveScreen(),
        },
      ),
    );
  }
}
