import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: AppStyles.displayFont.copyWith(fontSize: 20, color: context.fg),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppStyles.containerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              '1. Data Collection',
              'We collect information you provide directly to us when you create an account, such as your name, email address, and workout preferences. We also store your workout logs, check-in history, and performance metrics to help you track your fitness journey.',
            ),
            _buildSection(
              context,
              '2. How We Use Data',
              'Your data is used to provide the core features of the app: generating your digital pass, logging your progress, and managing gym entries. We do not sell your personal data to third parties.',
            ),
            _buildSection(
              context,
              '3. Data Storage',
              'We use secure cloud infrastructure (Supabase) to store and protect your information. Your authentication is handled securely via encrypted protocols.',
            ),
            _buildSection(
              context,
              '4. Your Rights',
              'You have the right to access, update, or delete your data at any time. You can use the "Delete Account" feature in the app settings to permanently remove all your data from our systems.',
            ),
            _buildSection(
              context,
              '5. Updates',
              'We may update this policy from time to time. We will notify you of any significant changes by posting the new policy within the app.',
            ),
            const SizedBox(height: 40),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Last updated: April 2026',
                  style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppStyles.displayFont.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppStyles.bodyFont.copyWith(
              fontSize: 14,
              height: 1.6,
              color: context.fg.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
