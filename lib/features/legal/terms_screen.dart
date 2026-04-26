import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
              '1. Acceptance of Terms',
              'By creating an account and using the Vishal Fitness app, you agree to comply with and be bound by these Terms of Service. If you do not agree, please do not use the application.',
            ),
            _buildSection(
              context,
              '2. Gym Entry & Pass',
              'Your digital pass is personal to you and cannot be shared. Misuse of the QR code for unauthorized entry may result in account suspension.',
            ),
            _buildSection(
              context,
              '3. Health & Safety',
              'Fitness activities involve inherent risks. By using this app to log workouts or book classes, you acknowledge that you are in good health and have consulted with a medical professional if necessary. Vishal Fitness is not responsible for injuries sustained during training.',
            ),
            _buildSection(
              context,
              '4. Account Security',
              'You are responsible for maintaining the confidentiality of your account. You agree to notify us immediately of any unauthorized use of your account.',
            ),
            _buildSection(
              context,
              '5. Termination',
              'We reserve the right to terminate or suspend access to our service immediately, without prior notice, for any reason whatsoever, including breach of terms.',
            ),
            const SizedBox(height: 40),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '© 2026 Vishal Fitness · Made by Qyroxis',
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
              color: AppColors.energy,
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
