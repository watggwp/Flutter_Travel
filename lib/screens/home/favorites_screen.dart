import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/post_service.dart';
import '../../l10n/app_translations.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _postService = PostService();
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final posts = await _postService.getBookmarks();
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark(int index) async {
    final post = _posts[index];
    await _postService.toggleBookmark(post['id'] as int);
    if (mounted) {
      setState(() => _posts.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const Icon(Icons.bookmark_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              AppTranslations.get('drawer_fav'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_border_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              AppTranslations.get('fav_empty_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.get('fav_empty_sub'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        Uint8List? postImg;
        try {
          if (post['imageBase64'] != null) {
            postImg = base64Decode(post['imageBase64']);
          }
        } catch (_) {}

        final List<String> tags = [];
        try {
          final rawTags = post['tags'];
          if (rawTags is String && rawTags.isNotEmpty) {
            final decoded = jsonDecode(rawTags);
            if (decoded is List) tags.addAll(decoded.cast<String>());
          }
        } catch (_) {}

        final dt = DateTime.fromMillisecondsSinceEpoch((post['createdAt'] as int? ?? 0) * 1000);
        final diff = DateTime.now().difference(dt);
        String timeStr;
        if (diff.inMinutes < 1) {
          timeStr = 'just now';
        } else if (diff.inHours < 1) {
          timeStr = '${diff.inMinutes}m ago';
        } else if (diff.inDays < 1) {
          timeStr = '${diff.inHours}h ago';
        } else {
          timeStr = '${diff.inDays}d ago';
        }

        Uint8List? avatar;
        try {
          if (post['profilePicture'] != null && (post['profilePicture'] as String).isNotEmpty) {
            avatar = base64Decode(post['profilePicture']);
          }
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.inputBackground,
                      backgroundImage: avatar != null ? MemoryImage(avatar) : null,
                      child: avatar == null
                          ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['fullName'] as String? ?? 'User',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary),
                          ),
                          if ((post['locationName'] as String? ?? '').isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 11, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    post['locationName'],
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.primary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _toggleBookmark(index),
                      child: const Icon(Icons.bookmark_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                  ],
                ),
              ),
              // Image
              if (postImg != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Image.memory(
                    postImg,
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                ),
              // Caption & Tags
              if ((post['caption'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${post['fullName']}  ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 14),
                        ),
                        TextSpan(
                          text: post['caption'],
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Wrap(
                    spacing: 6,
                    children: tags
                        .map((t) => Text('#$t',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }
}
