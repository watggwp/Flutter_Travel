import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../theme/app_colors.dart';
import 'place_detail_screen.dart';
import '../../l10n/app_translations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'Attraction';
  bool _isLoading = false;
  double? _userLat;
  double? _userLon;
  bool _usingFallback = false;
  List<dynamic> _places = [];
  String _errorMessage = '';

  late AnimationController _shimmerController;

  static const _categories = [
    {'id': 'Attraction', 'icon': Icons.location_on_rounded, 'color': Color(0xFF6C63FF)},
    {'id': 'Beach', 'icon': Icons.beach_access_rounded, 'color': Color(0xFF00C9A7)},
    {'id': 'Mountain', 'icon': Icons.terrain_rounded, 'color': Color(0xFF3B82F6)},
    {'id': 'Temple', 'icon': Icons.account_balance_rounded, 'color': Color(0xFFFF6584)},
    {'id': 'Restaurant', 'icon': Icons.restaurant_rounded, 'color': Color(0xFFFFB347)},
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _getCurrentLocation();
    if (_userLat != null) {
      await _fetchNearbyPlaces();
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _usingFallback = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useFallbackLocation();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
      _userLat = pos.latitude;
      _userLon = pos.longitude;
      setState(() {});
    } catch (e) {
      _useFallbackLocation();
    }
  }

  void _useFallbackLocation() {
    _userLat = 13.7563;
    _userLon = 100.5018;
    _usingFallback = true;
    setState(() {});
  }

  Future<void> _fetchNearbyPlaces() async {
    if (_userLat == null || _userLon == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _places = [];
    });

    String tags = '';
    switch (_selectedCategory) {
      case 'Mountain':
        tags = '["natural"="peak"]';
        break;
      case 'Beach':
        tags = '["natural"="beach"]';
        break;
      case 'Temple':
        tags = '["amenity"="place_of_worship"]["religion"="buddhist"]';
        break;
      case 'Restaurant':
        tags = '["amenity"="restaurant"]';
        break;
      case 'Attraction':
      default:
        tags = '["tourism"~"attraction|museum|viewpoint"]';
        break;
    }

    final double lat = _userLat!;
    final double lon = _userLon!;

    final query = '''
      [out:json][timeout:15];
      (
        node$tags(around:8000,$lat,$lon);
        way$tags(around:8000,$lat,$lon);
      );
      out center 15;
    ''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['elements'] != null) {
          List<dynamic> fetchedPlaces = data['elements']
              .where((e) => e['tags'] != null && e['tags']['name'] != null)
              .toList();

          for (var place in fetchedPlaces) {
            double pLat = place['lat'] ?? place['center']?['lat'] ?? 0.0;
            double pLon = place['lon'] ?? place['center']?['lon'] ?? 0.0;
            place['distance'] = (_userLat != null && pLat != 0.0)
                ? Geolocator.distanceBetween(
                    _userLat!, _userLon!, pLat, pLon)
                : 999999.0;
          }

          fetchedPlaces.sort((a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double));

          setState(() {
            _places = fetchedPlaces;
          });
        }
      } else {
        setState(() => _errorMessage = 'Failed to load places');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network error fetching places.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _fetchNearbyPlaces();
  }

  Color get _selectedCategoryColor {
    final cat = _categories.firstWhere(
      (c) => c['id'] == _selectedCategory,
      orElse: () => _categories.first,
    );
    return cat['color'] as Color;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppTranslations.currentLanguage,
      builder: (context, lang, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('discover'),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppTranslations.get('explore_sub'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Location badge
                  if (_usingFallback)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.location_on_rounded,
                              size: 14, color: AppColors.secondary),
                          SizedBox(width: 4),
                          Text(
                            'Bangkok',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.cardShadow,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: AppTranslations.get('search_hint'),
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: AppColors.primary),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Categories
              Text(
                AppTranslations.get('category_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories
                      .map((cat) => _buildCategoryItem(
                            cat['id'] as String,
                            AppTranslations.get(
                                'cat_${(cat['id'] as String).toLowerCase()}'),
                            cat['icon'] as IconData,
                            cat['color'] as Color,
                          ))
                      .toList(),
                ),
              ),

              const SizedBox(height: 28),

              // Places list header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${AppTranslations.get("nearby")} ${AppTranslations.get("cat_${_selectedCategory.toLowerCase()}")}${_usingFallback ? " (Bangkok)" : ""}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(_selectedCategoryColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPlacesContent(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlacesContent() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _initData,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppTranslations.get('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _places.isEmpty) {
      return SizedBox(
        height: 270,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          itemBuilder: (_, __) => _buildShimmerCard(),
        ),
      );
    }

    if (_places.isEmpty) {
      return SizedBox(
        height: 250,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded,
                    color: AppColors.textSecondary, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                'No $_selectedCategory found nearby.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 270,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final place = _places[index];
          final tags = place['tags'] ?? {};
          final name = tags['name:th'] ??
              tags['name:en'] ??
              tags['name'] ??
              'Unknown Place';

          double lat = place['lat'] ?? place['center']?['lat'] ?? 0.0;
          double lon = place['lon'] ?? place['center']?['lon'] ?? 0.0;
          double distMeters = place['distance'] ?? 0.0;
          String distStr = distMeters > 1000
              ? '${(distMeters / 1000).toStringAsFixed(1)} km'
              : '${distMeters.toStringAsFixed(0)} m';

          String baseUrl =
              kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
          String imgUrl = '$baseUrl/api/image?q=${Uri.encodeComponent(name)}';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => PlaceDetailScreen(
                    name: name,
                    imageUrl: imgUrl,
                    distanceMeters: distMeters,
                    lat: lat,
                    lon: lon,
                    category: _selectedCategory,
                  ),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
            child: _buildDestinationCard(name, distStr, imgUrl),
          );
        },
      ),
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        final shimmerGradient = LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1 + _shimmerController.value * 2, 0),
          end: Alignment(1 + _shimmerController.value * 2, 0),
        );
        return Container(
          width: 190,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: shimmerGradient,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        gradient: shimmerGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        gradient: shimmerGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(
      String id, String title, IconData icon, Color color) {
    final bool isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () => _onCategorySelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppColors.softShadow,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard(String title, String location, String imageUrl) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with gradient overlay
          Stack(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.inputBackground,
                      child: const Icon(Icons.image_not_supported_rounded,
                          size: 40, color: AppColors.textSecondary),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppColors.inputBackground,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                _selectedCategoryColor),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.cardOverlayGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                ),
              ),
              // Category badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedCategoryColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedCategory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 13, color: _selectedCategoryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.isNotEmpty
                            ? '$location ${AppTranslations.get("det_away")}'
                            : AppTranslations.get('nearby'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
