/// GEMINI: DO NOT change any hardcoded values in this file. 
/// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
/// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';

class AdminPassesScreen extends StatefulWidget {
  const AdminPassesScreen({super.key});

  @override
  State<AdminPassesScreen> createState() => _AdminPassesScreenState();
}

class _AdminPassesScreenState extends State<AdminPassesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _passes = [];

  @override
  void initState() {
    super.initState();
    _fetchPasses();
  }

  Future<void> _fetchPasses() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('gym_passes')
          .select()
          .order('duration_days', ascending: true);

      if (mounted) {
        setState(() {
          _passes = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching passes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePassStatus(String id, bool currentStatus) async {
    try {
      await supabase
          .from('gym_passes')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      _fetchPasses();
    } catch (e) {
      debugPrint('Error toggling pass status: $e');
    }
  }

  void _showPassForm([Map<String, dynamic>? existingPass]) {
    final nameController = TextEditingController(text: existingPass?['name']);
    final durationController = TextEditingController(text: existingPass?['duration_days']?.toString());
    final priceController = TextEditingController(text: existingPass?['price']?.toString());
    
    // We will store features as a single multiline string, one per line, for simple editing
    List<dynamic> featuresList = existingPass?['features'] ?? [];
    String featuresText = featuresList.map((f) => f.toString()).join('\n');
    final featuresController = TextEditingController(text: featuresText);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.card,
          title: Text(existingPass == null ? 'Add New Pass' : 'Edit Pass'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name (e.g., 1 Month)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                ),
                SizedBox(height: context.h(12)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Days (e.g., 30)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                      ),
                    ),
                    SizedBox(width: context.w(12)),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.h(12)),
                TextField(
                  controller: featuresController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: "Features (One per line)",
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: context.mutedFg)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || durationController.text.isEmpty || priceController.text.isEmpty) return;

                final featuresArray = featuresController.text
                    .split('\n')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final passData = {
                  'name': nameController.text.trim(),
                  'duration_days': int.tryParse(durationController.text) ?? 30,
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'features': featuresArray,
                };

                try {
                  if (existingPass == null) {
                    await supabase.from('gym_passes').insert(passData);
                  } else {
                    await supabase.from('gym_passes').update(passData).eq('id', existingPass['id']);
                  }
                  if (mounted) Navigator.pop(context);
                  _fetchPasses();
                } catch (e) {
                  debugPrint('Error saving pass: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: context.h(80.0)),
        child: FloatingActionButton.extended(
          onPressed: () => _showPassForm(),
          backgroundColor: AppColors.energy,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _passes.isEmpty
              ? Center(
                  child: Text(
                    'No passes configured.',
                    style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(context.w(AppStyles.containerPadding), context.h(16), context.w(AppStyles.containerPadding), context.h(120)),
                  itemCount: _passes.length,
                  itemBuilder: (context, index) {
                    final pass = _passes[index];
                    final isActive = pass['is_active'] as bool;
                    final features = pass['features'] as List<dynamic>? ?? [];

                    return Container(
                      margin: EdgeInsets.only(bottom: context.h(16)),
                      padding: EdgeInsets.all(context.r(16)),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
                        border: Border.all(color: context.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: context.r(10),
                            offset: Offset(0, context.h(4)),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  pass['name'],
                                  style: AppStyles.displayFont.copyWith(
                                    fontSize: context.sp(20),
                                    fontWeight: FontWeight.bold,
                                    color: context.fg,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Switch(
                                    value: isActive,
                                    onChanged: (val) => _togglePassStatus(pass['id'], isActive),
                                    activeColor: AppColors.brand,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppColors.brand, size: context.r(20)),
                                    onPressed: () => _showPassForm(pass),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '₹${pass['price']}',
                                style: AppStyles.displayFont.copyWith(
                                  fontSize: context.sp(24),
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.energy,
                                ),
                              ),
                              SizedBox(width: context.w(8)),
                              Text(
                                '/ ${pass['duration_days']} days',
                                style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                              ),
                            ],
                          ),
                          SizedBox(height: context.h(12)),
                          const Divider(),
                          SizedBox(height: context.h(8)),
                          Text(
                            'INCLUDES:',
                            style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(10)),
                          ),
                          SizedBox(height: context.h(8)),
                          ...features.map((f) => Padding(
                            padding: EdgeInsets.only(bottom: context.h(4)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.check_circle, color: AppColors.brand, size: context.r(14)),
                                SizedBox(width: context.w(8)),
                                Expanded(
                                  child: Text(
                                    f.toString(),
                                    style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.fg),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
