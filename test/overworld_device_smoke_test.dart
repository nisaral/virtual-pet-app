import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:virtual_pet_app/vale/controller.dart';
import 'package:virtual_pet_app/vale/care_sim.dart';
import 'package:virtual_pet_app/vale/models.dart';
import 'package:virtual_pet_app/vale/save_store.dart';
import 'package:virtual_pet_app/vale/screens_home.dart';
import 'package:virtual_pet_app/vale/stage3d.dart';
import 'package:virtual_pet_app/vale/vale_app.dart';
import 'package:virtual_pet_app/world/overworld_renderer.dart';

class _DocsPath extends PathProviderPlatform {
  _DocsPath(this.documents);
  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}

void main() {
  test('a phone camera culls the tile loop to the viewport', () {
    const frame = OverworldFrame(
      phase: DayPhase.day,
      anim: 0,
      camX: 800,
      camY: 1400,
      zoom: 1,
      pet: ActorDraw(x: 800, y: 1400, z: 0, face: Face.down, kind: 'sprout', anim: 0, asleep: false, label: ''),
      actors: [],
      pickups: [],
      thought: '',
      lantern: false,
      ball: null,
      ballZ: 0,
      berriesLeft: {},
    );
    final window = visibleTiles(frame, const Size(390, 844));
    expect(window.count, lessThan(400));
    expect(window.count, greaterThan(0));
    expect(window.maxX - window.minX, lessThan(mapTiles));
  });

  test('forage, friends, praise, and new ground reach level 5', () {
    const forage = 24;
    const friend = 22;
    const praise = 16;
    const newZone = 12;
    final xp = 5 * forage + 2 * friend + 4 * praise + 8 * newZone;
    expect(levelForXp(xp), greaterThanOrEqualTo(5));
  });

  testWidgets('portrait glen keeps the console chrome from overlapping', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final temp = Directory.systemTemp.createTempSync('vale-phone');
    addTearDown(() {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      } catch (_) {}
    });
    PathProviderPlatform.instance = _DocsPath(temp.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    final save = ValeSave.fresh(keeper: 'Nia', kinName: 'Miso', species: SpeciesId.pipkin).copy(seenIntro: true);
    File('${temp.path}${Platform.pathSeparator}lumina_vale_save.json').writeAsStringSync(jsonEncode(save.toJson()));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        valeProvider.overrideWith((ref) {
          final controller = ValeController(SaveStore());
          controller.debugEnterGlen(save);
          ref.onDispose(controller.disposeTimer);
          return controller;
        }),
      ],
      child: const ValeApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(overflows(errors), isEmpty);
    expect(tester.takeException(), isNull);

    final status = tester.getRect(find.byKey(const Key('status-card')));
    final radar = tester.getRect(find.byKey(const Key('radar')));
    final tool = tester.getRect(find.byKey(const Key('tool-chip')));
    final praise = tester.getRect(find.byKey(const Key('praise')));
    final redirect = tester.getRect(find.byKey(const Key('redirect')));
    final pad = tester.getRect(find.byKey(const Key('pad')));
    final buttonA = tester.getRect(find.byKey(const Key('btn-a')));
    final buttonB = tester.getRect(find.byKey(const Key('btn-b')));
    final dock = tester.getRect(find.byKey(const Key('dock')));

    final chrome = {
      'status': status,
      'radar': radar,
      'tool': tool,
      'praise': praise,
      'redirect': redirect,
      'pad': pad,
      'A': buttonA,
      'B': buttonB,
      'dock': dock,
    };
    final names = chrome.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final a = names[i];
        final b = names[j];
        if ((a == 'pad' && (b == 'A' || b == 'B')) || (b == 'pad' && (a == 'A' || a == 'B'))) continue;
        expect(chrome[a]!.overlaps(chrome[b]!), isFalse, reason: '$a overlaps $b');
      }
    }

    final glen = DenScreen.glenKey.currentState!;
    final xpBefore = glen.ref.read(valeProvider).save!.kin.xp;

    glen.travel(kBed.dx, kBed.dy);
    await tester.tap(find.byKey(const Key('btn-a')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Leave'), findsOneWidget);

    glen.travel(kArena.dx, kArena.dy);
    await tester.tap(find.byKey(const Key('btn-a')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(glen.ref.read(valeProvider).save!.ledger.tools, contains('ball'));

    glen.travel(480, 560);
    await tester.tap(find.byKey(const Key('btn-a')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(glen.ref.read(valeProvider).save!.ledger.foraged, greaterThan(0));
    expect(glen.ref.read(valeProvider).save!.kin.xp, greaterThan(xpBefore));

    await tester.tap(find.byKey(const Key('bag')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Berries'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Loot'), findsOneWidget);
    await tester.tap(find.text('Tools'));
    await tester.pump();
    await tester.tap(find.text('Loot'));
    await tester.pump();
    expect(overflows(errors), isEmpty);
    Navigator.of(tester.element(find.text('Pack'))).pop();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const Key('radar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Walk here'), findsWidgets);
    await tester.tap(find.text('Walk here').first);
    await tester.pump(const Duration(milliseconds: 40));
    expect(glen.px, closeTo(700, 40));
    expect(glen.py, closeTo(1500, 40));
    expect(overflows(errors), isEmpty);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 40)));
}

List<FlutterErrorDetails> overflows(List<FlutterErrorDetails> errors) {
  return errors.where((details) {
    final text = details.exceptionAsString();
    return text.contains('RenderFlex') || text.contains('overflowed');
  }).toList();
}
