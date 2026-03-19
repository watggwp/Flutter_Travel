import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/post_service.dart';
import '../../widgets/location_map_sheet.dart';
import '../profile/user_profile_screen.dart';
import 'explore_screen.dart'; // To reuse CommentsSheet

class PostDetailScreen extends StatefulWidget {
  final int postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _postService = PostService();
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final post = await _postService.getPost(widget.postId);
    if (mounted) {
      if (post != null) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final nowLiked = await _postService.toggleLike(_post!['id'] as int);
    if (mounted) {
      setState(() {
        _post!['likedByMe'] = nowLiked;
        _post!['likeCount'] =
            (_post!['likeCount'] as int) + (nowLiked ? 1 : -1);
      });
    }
  }

  void _openComments() {
    if (_post == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => CommentsSheet(
        postId: _post!['id'] as int,
        onComment: () {
          if (mounted) {
            setState(() {
              _post!['commentCount'] = (_post!['commentCount'] as int) + 1;
            });
          }
        },
      ),
    );
  }

  String _formatTime(int createdAt) {
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_hasError || _post == null) {
      return const Center(
        child: Text('Post not found',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      );
    }

    Uint8List? userAvatar;
    Uint8List? postImg;

    try {
      if (_post!['profilePicture'] != null &&
          (_post!['profilePicture'] as String).isNotEmpty) {
        userAvatar = base64Decode(_post!['profilePicture']);
      }
    } catch (_) {}

    try {
      if (_post!['imageBase64'] != null) {
        postImg = base64Decode(_post!['imageBase64']);
      }
    } catch (_) {}

    final List<String> tags = [];
    try {
      final rawTags = _post!['tags'];
      if (rawTags is String && rawTags.isNotEmpty) {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) tags.addAll(decoded.cast<String>());
      }
    } catch (_) {}

    final bool liked = _post!['likedByMe'] == true;
    final int likeCount = _post!['likeCount'] as int? ?? 0;
    final int commentCount = _post!['commentCount'] as int? ?? 0;
    final String timeStr = _formatTime(_post!['createdAt'] as int? ?? 0);

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            userId: _post!['userId'] as int,
                            userName: _post!['fullName'] as String? ?? 'User',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            userAvatar != null ? MemoryImage(userAvatar) : null,
                        child: userAvatar == null
                            ? const Icon(Icons.person_rounded,
                                color: AppColors.primary, size: 20)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: _post!['userId'] as int,
                              userName: _post!['fullName'] as String? ?? 'User',
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _post!['fullName'] as String? ?? 'User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if ((_post!['locationName'] as String? ?? '')
                              .isNotEmpty)
                            LocationChip(
                              locationName: _post!['locationName'],
                              lat: _post!['lat'] != null
                                  ? (_post!['lat'] as num).toDouble()
                                  : null,
                              lng: _post!['lng'] != null
                                  ? (_post!['lng'] as num).toDouble()
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
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
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),

            // Actions row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  _ActionButton(
                    icon: liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: liked ? AppColors.accent : AppColors.textSecondary,
                    count: likeCount,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.textSecondary,
                    count: commentCount,
                    onTap: _openComments,
                  ),
                  const Spacer(),
                  const Icon(Icons.share_outlined,
                      color: AppColors.textSecondary, size: 22),
                ],
              ),
            ),

            // Caption & Tags
            if ((_post!['caption'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_post!['fullName']}  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: _post!['caption'],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
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
                      .map((t) => Text(
                            '#$t',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// Reuse action button
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _scale,
            builder: (_, child) =>
                Transform.scale(scale: _scale.value, child: child),
            child: Icon(widget.icon, color: widget.color, size: 24),
          ),
          const SizedBox(width: 4),
          Text(
            widget.count.toString(),
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 14),
          ),
        ],
      ),
    );
  }
}
