import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionTrackingService {
  static const String _versionKey = 'last_known_version';

  Future<bool> checkAndShowUpdateSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    
    final lastKnownVersion = prefs.getString(_versionKey);

    if (lastKnownVersion != null && lastKnownVersion != currentVersion) {
      // Version has changed!
      await prefs.setString(_versionKey, currentVersion);
      return true;
    }

    // First time ever or no change
    if (lastKnownVersion == null) {
      await prefs.setString(_versionKey, currentVersion);
    }
    
    return false;
  }
}

final versionTrackingService = VersionTrackingService();
