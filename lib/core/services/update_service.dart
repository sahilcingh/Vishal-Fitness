import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  final _supabase = Supabase.instance.client;

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);
      debugPrint('Current App Version: $currentVersion');

      final response = await _supabase
          .from('app_config')
          .select('key, value')
          .inFilter('key', ['latest_version', 'update_url', 'min_version']);

      debugPrint('Supabase Response: $response');

      if (response == null || (response as List).isEmpty) {
        debugPrint('No config found in Supabase table "app_config"');
        return null;
      }

      final config = {for (var item in response) item['key']: item['value']};

      final latestVersionStr = config['latest_version'];
      final updateUrl = config['update_url'];
      final minVersionStr = config['min_version'];

      if (latestVersionStr == null || updateUrl == null) {
        debugPrint('Missing latest_version or update_url in Supabase');
        return null;
      }

      final latestVersion = Version.parse(latestVersionStr);
      final minVersion = minVersionStr != null ? Version.parse(minVersionStr) : null;

      debugPrint('Latest Version from DB: $latestVersion');

      if (latestVersion > currentVersion) {
        debugPrint('Update found! Showing dialog...');
        return UpdateInfo(
          latestVersion: latestVersionStr,
          updateUrl: updateUrl,
          isForced: minVersion != null && currentVersion < minVersion,
        );
      } else {
        debugPrint('App is up to date.');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }
}

class UpdateInfo {
  final String latestVersion;
  final String updateUrl;
  final bool isForced;

  UpdateInfo({
    required this.latestVersion,
    required this.updateUrl,
    required this.isForced,
  });
}

final updateService = UpdateService();
