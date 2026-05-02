/// GEMINI: DO NOT change any hardcoded values in this file. 
/// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
/// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'package:intl/intl.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _classes = [];

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('classes')
          .select()
          .order('start_time', ascending: true);

      if (mounted) {
        setState(() {
          _classes = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteClass(String id) async {
    try {
      await supabase.from('classes').delete().eq('id', id);
      _fetchClasses();
    } catch (e) {
      debugPrint('Error deleting class: $e');
    }
  }

  void _showClassForm([Map<String, dynamic>? existingClass]) {
    final titleController = TextEditingController(text: existingClass?['title']);
    final instructorController = TextEditingController(text: existingClass?['instructor_name']);
    final categoryController = TextEditingController(text: existingClass?['category'] ?? 'HIIT');
    final durationController = TextEditingController(text: existingClass?['duration_min']?.toString() ?? '45');
    final capacityController = TextEditingController(text: existingClass?['capacity']?.toString() ?? '20');
    
    String selectedIntensity = existingClass?['intensity'] ?? 'medium';
    DateTime selectedDate = existingClass != null ? DateTime.parse(existingClass['start_time']) : DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.card,
              title: Text(existingClass == null ? 'Add New Class' : 'Edit Class'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                    ),
                    SizedBox(height: context.h(12)),
                    TextField(
                      controller: instructorController,
                      decoration: InputDecoration(labelText: 'Instructor', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                    ),
                    SizedBox(height: context.h(12)),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(labelText: 'Category (e.g., HIIT, YOGA)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                    ),
                    SizedBox(height: context.h(12)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Duration (min)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                          ),
                        ),
                        SizedBox(width: context.w(12)),
                        Expanded(
                          child: TextField(
                            controller: capacityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Capacity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.h(12)),
                    DropdownButtonFormField<String>(
                      value: selectedIntensity,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Intensity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(8)))),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedIntensity = val);
                      },
                    ),
                    SizedBox(height: context.h(12)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                          child: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                          child: Text(selectedTime.format(context)),
                        ),
                      ],
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
                    if (titleController.text.isEmpty || instructorController.text.isEmpty) return;
                    
                    final finalDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final classData = {
                      'title': titleController.text.trim(),
                      'instructor_name': instructorController.text.trim(),
                      'category': categoryController.text.trim().toUpperCase(),
                      'duration_min': int.tryParse(durationController.text) ?? 45,
                      'capacity': int.tryParse(capacityController.text) ?? 20,
                      'intensity': selectedIntensity,
                      'start_time': finalDateTime.toIso8601String(),
                    };

                    try {
                      if (existingClass == null) {
                        await supabase.from('classes').insert(classData);
                      } else {
                        await supabase.from('classes').update(classData).eq('id', existingClass['id']);
                      }
                      if (mounted) Navigator.pop(context);
                      _fetchClasses();
                    } catch (e) {
                      debugPrint('Error saving class: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
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
          onPressed: () => _showClassForm(),
          backgroundColor: AppColors.aqua,
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text('Add Class', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _classes.isEmpty
              ? Center(
                  child: Text(
                    'No classes scheduled.',
                    style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(context.w(AppStyles.containerPadding), context.h(16), context.w(AppStyles.containerPadding), context.h(120)),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final item = _classes[index];
                    final startTime = DateTime.parse(item['start_time']);

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
                                  item['title'],
                                  style: AppStyles.displayFont.copyWith(
                                    fontSize: context.sp(18),
                                    fontWeight: FontWeight.bold,
                                    color: context.fg,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppColors.brand, size: context.r(20)),
                                    onPressed: () => _showClassForm(item),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: AppColors.energy, size: context.r(20)),
                                    onPressed: () => _deleteClass(item['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            'Instructor: ${item['instructor_name']}',
                            style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                          ),
                          SizedBox(height: context.h(12)),
                          Row(
                            children: [
                              _buildChip(context, item['category'], AppColors.aqua),
                              SizedBox(width: context.w(8)),
                              _buildChip(context, '${item['duration_min']} min', context.mutedFg),
                              SizedBox(width: context.w(8)),
                              _buildChip(context, item['intensity'].toString().toUpperCase(), AppColors.pulse),
                            ],
                          ),
                          SizedBox(height: context.h(12)),
                          const Divider(),
                          SizedBox(height: context.h(8)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: context.r(14), color: context.mutedFg),
                                  SizedBox(width: context.w(4)),
                                  Text(
                                    DateFormat('MMM d • h:mm a').format(startTime),
                                    style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.people, size: context.r(14), color: context.mutedFg),
                                  SizedBox(width: context.w(4)),
                                  Text(
                                    'Cap: ${item['capacity']}',
                                    style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(4)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(context.r(6)),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppStyles.eyebrow.copyWith(color: color, fontSize: context.sp(9)),
      ),
    );
  }
}
