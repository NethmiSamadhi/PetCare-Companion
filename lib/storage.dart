import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class LocalStore {
  static const key = 'petcare_companion_v1';
  final SharedPreferences preferences;
  LocalStore(this.preferences);
  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());
  PetData load() {
    final raw = preferences.getString(key);
    return raw == null ? PetData() : PetData.decode(raw);
  }

  Future<void> save(PetData data) async {
    if (!await preferences.setString(key, data.encode())) {
      throw StateError('Could not save your changes.');
    }
  }
}
