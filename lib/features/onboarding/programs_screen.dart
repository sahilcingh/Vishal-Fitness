import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import 'registration_details_screen.dart';

class ProgramsScreen extends StatefulWidget {
  final String? prefillName;
  final String? prefillPhone;
  final String? prefillEmail;
  final String? prefillPassword;

  const ProgramsScreen({
    super.key,
    this.prefillName,
    this.prefillPhone,
    this.prefillEmail,
    this.prefillPassword,
  });

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  int _selectedDurationIndex = 1; // Default to 3 months

  final List<String> _durations = ['1 Month', '3 Months', '6 Months', '12 Months'];
  
  final Map<String, dynamic> _passData = <String, dynamic>{
    'name': 'VISHAL FITNESS',
    'tagline': 'Premium Gym Experience in Unnao',
    'gradient': AppColors.gradientBrand,
    'prices': ['₹1,199', '₹2,999', '₹5,499', '₹8,999'],
    'oldPrices': ['₹1,500', '₹3,500', '₹6,500', '₹10,500'],
    'features': <Map<String, dynamic>>[
      {'text': 'Unlimited Gym Access', 'included': true},
      {'text': 'Cardio & Strength Equipment', 'included': true},
      {'text': 'Expert Guidance', 'included': true},
      {'text': 'Free Gym Set', 'included': false},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Stack(
        children: [
          // Background Layer with Image, Filter, and Blur
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/vishal/get_pass_bg.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    context.isDark
                        ? Colors.black.withOpacity(0.65)
                        : Colors.white.withOpacity(0.9),
                    context.isDark ? BlendMode.darken : BlendMode.lighten,
                  ),
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          // Content Layer
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildDurationSelector(context),
                Expanded(
                  child: _buildPassDetails(_passData),
                ),
                _buildStickyFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppStyles.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.card.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.border),
                  ),
                  child: Icon(Icons.arrow_back, size: 20, color: context.fg),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Your Pass',
                    style: AppStyles.displayFont.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: context.fg,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.containerPadding),
      child: Row(
        children: List.generate(_durations.length, (index) {
          final isSelected = _selectedDurationIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDurationIndex = index),
              child: Container(
                margin: EdgeInsets.only(
                  right: index == _durations.length - 1 ? 0 : 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected 
                    ? AppColors.brand.withOpacity(0.15) 
                    : context.card.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                  border: Border.all(
                    color: isSelected ? AppColors.brand : context.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _durations[index].replaceAll(' ', '\n'), // Stack text for narrow boxes
                      textAlign: TextAlign.center,
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                        color: isSelected ? AppColors.brand : context.fg.withOpacity(0.8),
                        height: 1.1,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPassDetails(Map<String, dynamic> data) {
    // Determine if Gym Set is included for the current selection (6 or 12 months)
    final bool includesGymSet = _selectedDurationIndex >= 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppStyles.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: data['gradient'] as LinearGradient,
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: (data['gradient'] as LinearGradient).colors[0].withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${data['name']}\nPASS',
                      style: AppStyles.displayFont.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                    if (_selectedDurationIndex == 3) // 12 Months
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'BEST VALUE',
                          style: AppStyles.eyebrow.copyWith(
                            color: Colors.white, 
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  data['tagline'],
                  style: AppStyles.bodyFont.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      data['prices'][_selectedDurationIndex],
                      style: AppStyles.displayFont.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      data['oldPrices'][_selectedDurationIndex],
                      style: AppStyles.bodyFont.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.lineThrough,
                        decorationThickness: 2,
                      ),
                    ),
                  ],
                ),
                if (includesGymSet) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.sun,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_giftcard, size: 16, color: Colors.black87),
                        const SizedBox(width: 8),
                        Text(
                          '+ FREE GYM SET INCLUDED',
                          style: AppStyles.eyebrow.copyWith(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'WHAT\'S INCLUDED',
            style: AppStyles.eyebrow.copyWith(
              color: context.fg,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          ... (data['features'] as List<Map<String, dynamic>>).map((feature) {
            bool isIncluded = feature['included'] as bool;
            
            // Dynamic check for gym set feature
            if (feature['text'] == 'Free Gym Set') {
              isIncluded = includesGymSet;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isIncluded ? AppColors.brand : context.muted.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncluded ? Icons.check : Icons.close,
                      size: 12,
                      color: isIncluded ? Colors.white : context.fg.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature['text'] as String,
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 14,
                        color: isIncluded ? context.fg : context.fg.withOpacity(0.4),
                        fontWeight: isIncluded ? FontWeight.w700 : FontWeight.w500,
                        decoration: isIncluded ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.all(AppStyles.containerPadding),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _passData['prices'][_selectedDurationIndex],
                  style: AppStyles.displayFont.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.fg,
                  ),
                ),
                Text(
                  'for ${_durations[_selectedDurationIndex].replaceAll('\n', ' ')}',
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.fg.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.gradientBrand,
                borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  final passName = _passData['name'] as String;
                  
                  int durationDays = 30;
                  if (_selectedDurationIndex == 1) { durationDays = 90; }
                  else if (_selectedDurationIndex == 2) { durationDays = 180; }
                  else if (_selectedDurationIndex == 3) { durationDays = 365; }

                  final priceString = _passData['prices'][_selectedDurationIndex]
                      .toString()
                      .replaceAll('₹', '')
                      .replaceAll(',', '');
                  final price = double.tryParse(priceString) ?? 0.0;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegistrationDetailsScreen(
                        durationDays: durationDays,
                        price: price,
                        passName: passName,
                        prefillName: widget.prefillName,
                        prefillPhone: widget.prefillPhone,
                        prefillEmail: widget.prefillEmail,
                        prefillPassword: widget.prefillPassword,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                  ),
                ),
                child: Text(
                  'Buy Pass Now',
                  style: AppStyles.bodyFont.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
