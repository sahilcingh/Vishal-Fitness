// GEMINI: DO NOT change any hardcoded values in this file.
// Always use responsive utilities (context.w, context.h, context.sp, context.r)
// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'admin_member_ledger_screen.dart';

/// Searchable member directory. Mirrors members-directory.tsx / the
/// website's /admin/members page - tap a member to see their full Ledger.
class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({super.key});

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name, phone, photo_url, created_at')
          .neq('role', 'admin')
          .order('full_name', ascending: true);
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _membershipNo(String userId) =>
      'MBR-${userId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((m) {
      final name = (m['full_name'] as String? ?? '').toLowerCase();
      final phone = (m['phone'] as String? ?? '').toLowerCase();
      final mbr = _membershipNo(m['id'] as String).toLowerCase();
      return name.contains(_searchQuery) || phone.contains(_searchQuery) || mbr.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _fetchMembers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: context.w(AppStyles.containerPadding)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.h(16)),
                    _buildHeader(),
                    SizedBox(height: context.h(20)),
                    _buildSearchBar(),
                    SizedBox(height: context.h(16)),
                    _buildList(),
                    SizedBox(height: context.h(120)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEMBER DIRECTORY',
          style: AppStyles.eyebrow.copyWith(color: AppColors.brand, letterSpacing: 2),
        ),
        SizedBox(height: context.h(4)),
        Text(
          'Ledger',
          style: AppStyles.displayFont.copyWith(
            fontSize: context.sp(32),
            fontWeight: FontWeight.bold,
            color: context.fg,
          ),
        ),
        SizedBox(height: context.h(4)),
        Text(
          'Search any member to see their full history - membership, payments, visits, and changes.',
          style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12.5), color: context.mutedFg),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), color: context.fg),
      decoration: InputDecoration(
        hintText: 'Search by name, phone or MBR...',
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
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(12)), borderSide: BorderSide(color: context.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(12)),
            borderSide: BorderSide(color: context.border.withValues(alpha: 0.6))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(12)),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.r(32)),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.person_search_outlined, color: context.mutedFg, size: context.r(36)),
            SizedBox(height: context.h(12)),
            Text(
              _searchQuery.isNotEmpty ? 'No members match "$_searchQuery".' : 'No members yet.',
              style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: context.h(8)),
      itemBuilder: (_, i) => _buildMemberCard(items[i]),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m) {
    final userId = m['id'] as String;
    final name = m['full_name'] as String? ?? 'Member';
    final phone = m['phone'] as String? ?? '—';
    final photoUrl = m['photo_url'] as String?;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminMemberLedgerScreen(userId: userId)),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(14)),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: context.r(40),
              height: context.r(40),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: photoUrl != null
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        initials,
                        style: AppStyles.displayFont.copyWith(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: context.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w700, fontSize: context.sp(14), color: context.fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.h(3)),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: context.w(6), vertical: context.h(2)),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(context.r(4)),
                        ),
                        child: Text(
                          _membershipNo(userId),
                          style: TextStyle(
                              fontSize: context.sp(9), fontWeight: FontWeight.bold, color: AppColors.brand),
                        ),
                      ),
                      SizedBox(width: context.w(6)),
                      Flexible(
                        child: Text(
                          phone,
                          style: AppStyles.bodyFont.copyWith(fontSize: context.sp(11), color: context.mutedFg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.mutedFg, size: context.r(20)),
          ],
        ),
      ),
    );
  }
}
