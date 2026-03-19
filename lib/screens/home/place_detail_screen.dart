import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../l10n/app_translations.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String name;
  final String imageUrl;
  final double distanceMeters;
  final double lat;
  final double lon;
  final String category;

  const PlaceDetailScreen({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.distanceMeters,
    required this.lat,
    required this.lon,
    required this.category,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  String _description = '';
  bool _isLoadingDesc = true;

  @override
  void initState() {
    super.initState();
    _fetchDescription();
  }

  Future<void> _fetchDescription() async {
    try {
      final url = Uri.parse('https://th.wikipedia.org/w/api.php?action=query&prop=extracts&exintro&explaintext&format=json&titles=${Uri.encodeComponent(widget.name)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']['pages'] as Map<String, dynamic>;
        if (pages.keys.first != "-1") {
          final extract = pages[pages.keys.first]['extract'];
          if (extract != null && extract.toString().isNotEmpty) {
            setState(() {
              _description = extract;
              _isLoadingDesc = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Wiki error: $e");
    }
    
    // Fallback description if Wikipedia doesn't have an exact match for the Thai name
    setState(() {
      _description = 'นี่คือ ${widget.name} ซึ่งเป็นสถานที่ท่องเที่ยวในหมวดหมู่ ${widget.category} ที่น่าสนใจ '
          'ตั้งอยู่ท่ามกลางบรรยากาศที่ดี เหมาะแก่การมาพักผ่อนและทำกิจกรรมที่ยอดเยี่ยม '
          'ห่างจากคุณเพียง ${(widget.distanceMeters / 1000).toStringAsFixed(1)} กิโลเมตร ทำให้นี่คือตัวเลือกที่ดีมากสำหรับการเดินทางครับ!';
      _isLoadingDesc = false;
    });
  }

  void _openGoogleMaps() async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.lat},${widget.lon}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Google Maps')));
      }
    }
  }

  void _showMapPopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(widget.lat, widget.lon),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.travel_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(widget.lat, widget.lon),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('พิกัดแนวตั้ง/แนวนอน: ${widget.lat.toStringAsFixed(4)}, ${widget.lon.toStringAsFixed(4)}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppTranslations.get('det_close_map'), style: const TextStyle(color: AppColors.primary)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, err, stack) => const Icon(Icons.image, size: 100, color: Colors.grey),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${(widget.distanceMeters / 1000).toStringAsFixed(1)} km ${AppTranslations.get("det_away")}',
                        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.category,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(AppTranslations.get('det_about'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _isLoadingDesc 
                      ? const Center(child: CircularProgressIndicator()) 
                      : Text(
                          _description,
                          style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
                        ),
                  const SizedBox(height: 32),
                  Text(AppTranslations.get('det_map'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showMapPopup,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: IgnorePointer(
                          // IgnorePointer prevents scroll clashing with the outer scroll view. 
                          // A click will just propagate up to the GestureDetector to open the dialog Map.
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(widget.lat, widget.lon),
                              initialZoom: 14.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.travel_app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(widget.lat, widget.lon),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(AppTranslations.get('det_tap_map'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 40),
                  CustomButton(
                    text: AppTranslations.get('det_nav_btn'),
                    onPressed: _openGoogleMaps,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
