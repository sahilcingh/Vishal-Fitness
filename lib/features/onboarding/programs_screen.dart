import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../main.dart';
import 'registration_details_screen.dart';
import 'package:intl/intl.dart';

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
  int _selectedPassIndex = 0;
  List<Map<String, dynamic>> _activePasses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPasses();
  }

  Future<void> _fetchPasses() async {
    try {
      final response = await supabase
          .from('gym_passes')
          .select()
          .eq('is_active', true)
          .order('duration_days', ascending: true);

      if (mounted) {
        setState(() {
          _activePasses = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching active passes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                : _activePasses.isEmpty
                    ? _buildEmptyState(context)
                    : Column(
                        children: [
                          _buildHeader(context),
                          _buildDurationSelector(context),
                          Expanded(
                            child: _buildPassDetails(_activePasses[_selectedPassIndex]),
                          ),
                          _buildStickyFooter(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Center(
            child: Text(
              'No passes currently available.',
              style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
            ),
          ),
        ),
      ],
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
        children: List.generate(_activePasses.length, (index) {
          final isSelected = _selectedPassIndex == index;
          final pass = _activePasses[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPassIndex = index),
              child: Container(
                margin: EdgeInsets.only(
                  right: index == _activePasses.length - 1 ? 0 : 8,
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
                      pass['name'].toString().replaceAll(' ', '\n'), // Stack text for narrow boxes
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

  Widget _buildPassDetails(Map<String, dynamic> pass) {
    final List<dynamic> features = pass['features'] ?? [];
    final NumberFormat formatter = NumberFormat('#,##0');
    final String price = formatter.format(pass['price']);
    final bool isBestValue = _selectedPassIndex == _activePasses.length - 1 && _activePasses.length > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppStyles.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.gradientBrand,
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withOpacity(0.3),
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
                      'VISHAL FITNESS\n${pass['name'].toString().toUpperCase()}',
                      style: AppStyles.displayFont.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                    ),
                    if (isBestValue)
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
                  'Premium Gym Experience in Unnao',
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
                      '₹$price',
                      style: AppStyles.displayFont.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '/ ${pass['duration_days']} days',
                      style: AppStyles.bodyFont.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
          ... features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature.toString(),
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 14,
                        color: context.fg,
                        fontWeight: FontWeight.w700,
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
    final pass = _activePasses[_selectedPassIndex];
    final NumberFormat formatter = NumberFormat('#,##0');
    final String priceText = formatter.format(pass['price']);

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
                  '₹$priceText',
                  style: AppStyles.displayFont.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.fg,
                  ),
                ),
                Text(
                  'for ${pass['name']}',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegistrationDetailsScreen(
                        durationDays: pass['duration_days'],
                        price: (pass['price'] as num).toDouble(),
                        passName: pass['name'],
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
