/// GEMINI: DO NOT change any hardcoded values in this file. 
/// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
/// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'package:intl/intl.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _announcements = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredAnnouncements {
    if (_searchQuery.isEmpty) return _announcements;
    return _announcements.where((a) {
      final title = (a['title'] as String? ?? '').toLowerCase();
      final message = (a['message'] as String? ?? '').toLowerCase();
      return title.contains(_searchQuery) || message.contains(_searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _announcements = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAnnouncementStatus(String id, bool currentStatus) async {
    try {
      await supabase
          .from('announcements')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      _fetchAnnouncements();
    } catch (e) {
      debugPrint('Error toggling status: $e');
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await supabase.from('announcements').delete().eq('id', id);
      _fetchAnnouncements();
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
    }
  }

  void _showAddAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.card,
          title: const Text('New Announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.r(AppStyles.radiusSm)),
                  ),
                ),
              ),
              SizedBox(height: context.h(16)),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.r(AppStyles.radiusSm)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: context.mutedFg)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) return;
                
                try {
                  await supabase.from('announcements').insert({
                    'title': titleController.text.trim(),
                    'message': messageController.text.trim(),
                    'created_by': supabase.auth.currentUser!.id,
                  });
                  if (mounted) Navigator.pop(context);
                  _fetchAnnouncements();
                } catch (e) {
                  debugPrint('Error adding announcement: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('Post', style: TextStyle(color: Colors.white)),
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
          heroTag: 'fab_announcements',
          onPressed: _showAddAnnouncementDialog,
          backgroundColor: AppColors.sun,
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text('New Post', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(context.w(AppStyles.containerPadding), context.h(12), context.w(AppStyles.containerPadding), context.h(8)),
                  child: TextField(
                    controller: _searchController,
                    style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), color: context.fg),
                    decoration: InputDecoration(
                      hintText: 'Search announcements...',
                      hintStyle: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
                      prefixIcon: Icon(Icons.search, color: context.mutedFg, size: context.r(18)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: context.mutedFg, size: context.r(18)),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: context.card,
                      contentPadding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(12)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(12)), borderSide: BorderSide(color: context.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(12)), borderSide: BorderSide(color: context.border.withValues(alpha: 0.6))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(12)), borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredAnnouncements.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty ? 'No announcements yet.' : 'No results for "$_searchQuery".',
                            style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(context.w(AppStyles.containerPadding), context.h(4), context.w(AppStyles.containerPadding), context.h(120)),
                          itemCount: _filteredAnnouncements.length,
                          itemBuilder: (context, index) {
                            final item = _filteredAnnouncements[index];
                    final date = DateTime.parse(item['created_at']);
                    final isActive = item['is_active'] as bool;

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
                                  Switch(
                                    value: isActive,
                                    onChanged: (val) => _toggleAnnouncementStatus(item['id'], isActive),
                                    activeColor: AppColors.brand,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: AppColors.energy, size: context.r(20)),
                                    onPressed: () => _deleteAnnouncement(item['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('MMM d, yyyy h:mm a').format(date),
                            style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(10)),
                          ),
                          SizedBox(height: context.h(12)),
                          Text(
                            item['message'],
                            style: AppStyles.bodyFont.copyWith(color: context.fg, height: 1.4),
                          ),
                          if (!isActive) ...[
                            SizedBox(height: context.h(12)),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(4)),
                              decoration: BoxDecoration(
                                color: context.mutedFg.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(context.r(4)),
                              ),
                              child: Text(
                                'HIDDEN FROM MEMBERS',
                                style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(10)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
