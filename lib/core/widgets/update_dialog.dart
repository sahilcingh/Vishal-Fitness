import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo updateInfo) async {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.isForced,
        child: UpdateDialog(updateInfo: updateInfo),
      ),
    );
  }

  Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(updateInfo.updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.system_update, color: AppColors.energy),
          const SizedBox(width: 12),
          Text(
            'Update Available',
            style: AppStyles.displayFont.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A new version (${updateInfo.latestVersion}) is available. Please update for the best experience.',
            style: AppStyles.bodyFont.copyWith(fontSize: 14),
          ),
          if (updateInfo.isForced)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'This update is required to continue using the app.',
                style: AppStyles.bodyFont.copyWith(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (!updateInfo.isForced)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: TextStyle(color: context.mutedFg)),
          ),
        ElevatedButton(
          onPressed: _launchUpdateUrl,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.energy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Update Now'),
        ),
      ],
    );
  }
}
