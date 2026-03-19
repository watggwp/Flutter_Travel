import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';

/// Bottom sheet that shows a mini-map for the location and lets user
/// open Google Maps or Apple Maps.
class LocationMapSheet extends StatelessWidget {
  final String locationName;
  final double lat;
  final double lng;

  const LocationMapSheet({
    super.key,
    required this.locationName,
    required this.lat,
    required this.lng,
  });

  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lng);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, ctrl) => Column(
        children: [
          // Handle + header
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationName.isNotEmpty
                                ? locationName
                                : 'Unknown Location',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.travel_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 52,
                      height: 52,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: AppColors.primaryShadow,
                            ),
                            child: const Icon(Icons.place_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(
                            width: 0,
                            height: 0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Open in Google Maps button
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _openGoogleMaps,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.primaryShadow,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Open in Google Maps',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper — call this from any widget
void showLocationMap(BuildContext context,
    {required String locationName,
    required double? lat,
    required double? lng}) {
  if (lat == null || lng == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No coordinates available for this location'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LocationMapSheet(
      locationName: locationName,
      lat: lat,
      lng: lng,
    ),
  );
}

// ─── Tappable location chip ───────────────────────────────────
class LocationChip extends StatelessWidget {
  final String locationName;
  final double? lat;
  final double? lng;

  const LocationChip({
    super.key,
    required this.locationName,
    this.lat,
    this.lng,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCoords = lat != null && lng != null;
    return GestureDetector(
      onTap: hasCoords
          ? () => showLocationMap(context,
              locationName: locationName, lat: lat, lng: lng)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasCoords
                ? Icons.location_on_rounded
                : Icons.location_off_outlined,
            size: 12,
            color: hasCoords ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              locationName,
              style: TextStyle(
                fontSize: 11,
                color: hasCoords
                    ? AppColors.primary
                    : AppColors.textSecondary,
                decoration:
                    hasCoords ? TextDecoration.underline : TextDecoration.none,
                decorationColor: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasCoords) ...[
            const SizedBox(width: 2),
            const Icon(Icons.open_in_new_rounded,
                size: 10, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}

// Keep for use in profile / detail screens — base64 decode helper
Uint8List? tryDecodeBase64(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}
