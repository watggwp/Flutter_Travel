import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/post_service.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final String userName;
  const UserProfileScreen(
      {super.key, required this.userId, required this.userName});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _posts = [];
  bool _isLoading = true;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await PostService().getUserProfile(widget.userId);
    final posts = await PostService().getUserPosts(widget.userId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    setState(() => _followLoading = true);
    final nowFollowing = await PostService().toggleFollow(widget.userId);
    if (mounted) {
      setState(() {
        _profile!['isFollowing'] = nowFollowing;
        _profile!['followerCount'] = (_profile!['followerCount'] as int) +
            (nowFollowing ? 1 : -1);
        _followLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // SliverAppBar with gradient
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                          gradient: AppColors.purpleBlueGradient),
                      child: const Center(
                        child: Icon(Icons.person_rounded,
                            size: 80, color: Colors.white24),
                      ),
                    ),
                  ),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                ),

                SliverToBoxAdapter(
                  child: _buildProfileHeader(),
                ),

                // Grid of posts
                if (_posts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              size: 56, color: AppColors.textSecondary),
                          SizedBox(height: 12),
                          Text('No posts yet',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(2),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildGridTile(_posts[i]),
                        childCount: _posts.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    if (_profile == null) return const SizedBox.shrink();

    final bool isFollowing = _profile!['isFollowing'] == true;
    Uint8List? avatar;
    if (_profile!['profilePicture'] != null &&
        (_profile!['profilePicture'] as String).isNotEmpty) {
      try {
        avatar = base64Decode(_profile!['profilePicture']);
      } catch (_) {}
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: AppColors.primaryShadow,
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white),
              child: ClipOval(
                child: avatar != null
                    ? Image.memory(avatar, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.inputBackground,
                        child: const Icon(Icons.person_rounded,
                            size: 44, color: AppColors.primary),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            _profile!['fullName'] ?? widget.userName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          if (_profile!['bio'] != null && (_profile!['bio'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _profile!['bio'],
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(_profile!['postCount']?.toString() ?? '0', 'Posts'),
              Container(width: 1, height: 36, color: AppColors.inputBorder),
              _buildStat(
                  _profile!['followerCount']?.toString() ?? '0', 'Followers'),
              Container(width: 1, height: 36, color: AppColors.inputBorder),
              _buildStat(
                  _profile!['followingCount']?.toString() ?? '0', 'Following'),
            ],
          ),

          const SizedBox(height: 16),

          // Follow button
          SizedBox(
            width: double.infinity,
            child: _followLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.5),
                    ),
                  )
                : GestureDetector(
                    onTap: _toggleFollow,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isFollowing ? null : AppColors.primaryGradient,
                        color: isFollowing ? Colors.white : null,
                        borderRadius: BorderRadius.circular(16),
                        border: isFollowing
                            ? Border.all(
                                color: AppColors.primary, width: 1.5)
                            : null,
                        boxShadow:
                            isFollowing ? null : AppColors.primaryShadow,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFollowing
                                ? Icons.person_remove_rounded
                                : Icons.person_add_rounded,
                            color: isFollowing
                                ? AppColors.primary
                                : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFollowing ? 'Unfollow' : 'Follow',
                            style: TextStyle(
                              color: isFollowing
                                  ? AppColors.primary
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildGridTile(Map<String, dynamic> post) {
    Uint8List? img;
    try {
      img = base64Decode(post['imageBase64']);
    } catch (_) {}

    return Stack(
      fit: StackFit.expand,
      children: [
        img != null
            ? Image.memory(img, fit: BoxFit.cover)
            : Container(color: AppColors.inputBackground),
        Positioned(
          bottom: 6,
          left: 6,
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 3),
              Text(
                '${post['likeCount'] ?? 0}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
