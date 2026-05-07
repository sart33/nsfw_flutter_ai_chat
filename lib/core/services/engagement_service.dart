import 'package:shared_preferences/shared_preferences.dart';
import '../factory/database_helper.dart';

class EngagementService {
  EngagementService._();
  static final instance = EngagementService._();

  static const _prefKey = 'is_real_user';
  static const _threshold = 2;

  Future<bool> isRealUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return true;

    final count = await DatabaseHelper.instance.countRealCharacterMessages();
    if (count >= _threshold) {
      await prefs.setBool(_prefKey, true);
      return true;
    }
    return false;
  }
}