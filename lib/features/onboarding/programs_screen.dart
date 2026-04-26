import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDurationIndex = 0; // Default to 3 months

  final List<String> _durations = ['3 Months', '6 Months', '12 Months'];
  
  final Map<String, dynamic> _eliteData = <String, dynamic>{
    'name': 'ELITE',
    'tagline': 'Unlimited Access to Everything',
    'gradient': AppColors.gradientSunrise,
    'prices': ['₹14,990', '₹22,990', '₹34,990'],
    'oldPrices': ['₹19,990', '₹32,990', '₹54,990'],
    'features': <Map<String, dynamic>>[
      {'text': 'Unlimited Gym Access', 'included': true},
      {'text': 'Unlimited ELITE/PRO Classes', 'included': true},
      {'text': 'At-home Workout Library', 'included': true},
      {'text': 'Priority Booking & Concierge', 'included': true},
      {'text': 'Free Workout Kit on Join', 'included': true},
      {'text': '2 Guest Passes per Month', 'included': true},
    ],
  };

  final Map<String, dynamic> _proData = <String, dynamic>{
    'name': 'PRO',
    'tagline': 'Premium Gym & Essential Classes',
    'gradient': AppColors.gradientBrand,
    'prices': ['₹9,990', '₹15,990', '₹24,990'],
    'oldPrices': ['₹14,990', '₹24,990', '₹39,990'],
    'features': <Map<String, dynamic>>[
      {'text': 'Unlimited Gym Access', 'included': true},
      {'text': '2 Pro Classes per Week', 'included': true},
      {'text': 'At-home Workout Library', 'included': true},
      {'text': 'ELITE Classes Access', 'included': false},
      {'text': 'Priority Booking', 'included': false},
      {'text': 'Guest Passes', 'included': false},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                        : Colors.white.withOpacity(0.9), // Increased to 0.9 for almost solid background in light mode
                    context.isDark ? BlendMode.darken : BlendMode.lighten,
                  ),
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Increased blur for better text isolation
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
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPassDetails(_proData),
                      _buildPassDetails(_eliteData),
                    ],
                  ),
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
          Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.card.withOpacity(0.8),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: context.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: context.fg,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: context.primaryFg,
              unselectedLabelColor: context.fg.withOpacity(0.7), // Increased opacity for unselected tabs
              labelStyle: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'PRO'),
                Tab(text: 'ELITE'),
              ],
            ),
          ),
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
                    : context.card.withOpacity(0.8), // Increased card opacity for better surface
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
                      _durations[index],
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                        color: isSelected ? AppColors.brand : context.fg.withOpacity(0.8), // Darker text for unselected
                      ),
                      maxLines: 1,
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
                      '${data['name']} PASS',
                      style: AppStyles.displayFont.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900, // Maximized weight
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (_selectedDurationIndex == 2)
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
                const SizedBox(height: 8),
                Text(
                  data['tagline'],
                  style: AppStyles.bodyFont.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w700, // Increased from w500
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
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'WHAT\'S INCLUDED',
            style: AppStyles.eyebrow.copyWith(
              color: context.fg,
              fontWeight: FontWeight.w900, // Heaviest weight for section title
            ),
          ),
          const SizedBox(height: 16),
          ... (data['features'] as List<Map<String, dynamic>>).map((feature) {
            final isIncluded = feature['included'] as bool;
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
                        fontWeight: isIncluded ? FontWeight.w700 : FontWeight.w500, // Bolder for both states
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
    final currentData = _tabController.index == 0 ? _proData : _eliteData;
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
                  currentData['prices'][_selectedDurationIndex],
                  style: AppStyles.displayFont.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.fg,
                  ),
                ),
                Text(
                  'for ${_durations[_selectedDurationIndex]}',
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800, // Heavily bolded subtitle
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
                onPressed: () {},
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
