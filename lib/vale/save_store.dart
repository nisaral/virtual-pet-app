import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'care_sim.dart';

class SaveStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}lumina_vale_save.json');
  }

  Future<ValeSave?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      return ValeSave.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ValeSave save) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(save.toJson()));
  }

  Future<void> erase() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
