import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/post_service.dart';
import '../../widgets/location_map_sheet.dart';
import '../profile/user_profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  final _postService = PostService();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final posts = await _postService.getFeed();
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    final more = await _postService.getFeed(offset: _posts.length);
    if (mounted && more.isNotEmpty) {
      setState(() => _posts.addAll(more));
    }
  }

  Future<void> _toggleLike(int index) async {
    final post = _posts[index];
    final nowLiked = await _postService.toggleLike(post['id'] as int);
    if (mounted) {
      setState(() {
        _posts[index]['likedByMe'] = nowLiked;
        _posts[index]['likeCount'] = (post['likeCount'] as int) + (nowLiked ? 1 : -1);
      });
    }
  }

  void _openComments(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => CommentsSheet(
        postId: post['id'] as int,
        onComment: () {
          if (mounted) setState(() {
            post['commentCount'] = (post['commentCount'] as int) + 1;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadFeed,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 3,
        itemBuilder: (_, __) => _ShimmerPostCard(),
      );
    }

    if (_hasError && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 12),
            const Text('Failed to load feed',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
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
              child: const Icon(Icons.explore_outlined,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No posts yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Be the first to post a photo!',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: _posts.length + 1,
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                )
              : const SizedBox(height: 16);
        }
        return _PostCard(
          post: _posts[index],
          onLike: () => _toggleLike(index),
          onComment: () => _openComments(_posts[index]),
          onUserTap: (userId, userName) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    UserProfileScreen(userId: userId, userName: userName),
              ),
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Post Card
// ──────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final void Function(int userId, String userName) onUserTap;

  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onUserTap,
  });

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
    Uint8List? userAvatar;
    Uint8List? postImg;

    try {
      if (post['profilePicture'] != null &&
          (post['profilePicture'] as String).isNotEmpty) {
        userAvatar = base64Decode(post['profilePicture']);
      }
    } catch (_) {}

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

    final bool liked = post['likedByMe'] == true;
    final int likeCount = post['likeCount'] as int? ?? 0;
    final int commentCount = post['commentCount'] as int? ?? 0;
    final String timeStr = _formatTime(post['createdAt'] as int? ?? 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  onTap: () => onUserTap(
                    post['userId'] as int,
                    post['fullName'] as String? ?? 'User',
                  ),
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
                    onTap: () => onUserTap(
                      post['userId'] as int,
                      post['fullName'] as String? ?? 'User',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['fullName'] as String? ?? 'User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if ((post['locationName'] as String? ?? '').isNotEmpty)
                          LocationChip(
                            locationName: post['locationName'],
                            lat: post['lat'] != null
                                ? (post['lat'] as num).toDouble()
                                : null,
                            lng: post['lng'] != null
                                ? (post['lng'] as num).toDouble()
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
                  onTap: onLike,
                ),
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.textSecondary,
                  count: commentCount,
                  onTap: onComment,
                ),
                const Spacer(),
                const Icon(Icons.share_outlined,
                    color: AppColors.textSecondary, size: 22),
              ],
            ),
          ),

          // Caption & Tags
          if ((post['caption'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${post['fullName']}  ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: post['caption'],
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
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Action button (like / comment)
// ──────────────────────────────────────────────────────────────
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

// ──────────────────────────────────────────────────────────────
// Comments Bottom Sheet
// ──────────────────────────────────────────────────────────────
class CommentsSheet extends StatefulWidget {
  final int postId;
  final VoidCallback onComment;

  const CommentsSheet({super.key, required this.postId, required this.onComment});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _postService = PostService();
  final _textCtrl = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments = await _postService.getComments(widget.postId);
    if (mounted) setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  Future<void> _sendComment() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);

    final comment = await _postService.addComment(widget.postId, text);
    if (mounted && comment != null) {
      setState(() {
        _comments.add(comment);
        _textCtrl.clear();
        _isSending = false;
      });
      widget.onComment();
    } else {
      setState(() => _isSending = false);
    }
  }

  String _formatTime(int? ts) {
    if (ts == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: const [
                Icon(Icons.chat_bubble_outline_rounded,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Comments',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 40, color: AppColors.textSecondary),
                            SizedBox(height: 8),
                            Text('No comments yet',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: ctrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          Uint8List? avatar;
                          try {
                            if (c['profilePicture'] != null &&
                                (c['profilePicture'] as String).isNotEmpty) {
                              avatar = base64Decode(c['profilePicture']);
                            }
                          } catch (_) {}

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.inputBackground,
                                  backgroundImage: avatar != null
                                      ? MemoryImage(avatar)
                                      : null,
                                  child: avatar == null
                                      ? const Icon(Icons.person_rounded,
                                          color: AppColors.primary, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.inputBackground,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c['fullName'] ?? 'User',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c['text'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(c['createdAt'] as int?),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, 10 + MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendComment,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.primaryShadow,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Shimmer placeholder
// ──────────────────────────────────────────────────────────────
class _ShimmerPostCard extends StatefulWidget {
  @override
  State<_ShimmerPostCard> createState() => _ShimmerPostCardState();
}

class _ShimmerPostCardState extends State<_ShimmerPostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final grad = LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200
          ],
          stops: const [0, 0.5, 1],
          begin: Alignment(-1 + _ctrl.value * 2, 0),
          end: Alignment(1 + _ctrl.value * 2, 0),
        );

        Widget shimmerBox({double h = 16, double? w, double r = 8}) =>
            Container(
              height: h,
              width: w,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: grad,
                borderRadius: BorderRadius.circular(r),
              ),
            );

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
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          gradient: grad, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shimmerBox(h: 14, w: 120),
                          shimmerBox(h: 10, w: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 280, decoration: BoxDecoration(gradient: grad)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shimmerBox(h: 14, w: double.infinity),
                    shimmerBox(h: 14, w: 200),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
