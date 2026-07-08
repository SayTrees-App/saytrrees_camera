import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  CapturedImage? _selectedImage;

  // Default center (India)
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);

  Set<Marker> _buildMarkers(List<CapturedImage> images) {
    final markers = <Marker>{};

    for (final image in images) {
      // Use stored numeric values — no string parsing needed
      final double? lat = image.lat;
      final double? lng = image.lng;
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(image.localId),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: image.category,
            snippet: image.dateTime,
          ),
          onTap: () {
            setState(() => _selectedImage = image);
          },
        ),
      );
    }
    return markers;
  }

  // Keep as utility for fit-bounds (uses image.lat/lng directly)
  LatLng? _imageLatLng(CapturedImage image) {
    if (image.lat == null || image.lng == null) return null;
    return LatLng(image.lat!, image.lng!);
  }

  void _fitMapToMarkers(List<CapturedImage> images) {
    if (_mapController == null || images.isEmpty) return;

    final coords = images
        .map((img) => _imageLatLng(img))
        .whereType<LatLng>()
        .toList();

    if (coords.isEmpty) {
      // No geo-tagged captures yet — go to current location if available
      return;
    }

    if (coords.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(coords.first, 15),
      );
      return;
    }

    double minLat = coords.map((c) => c.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = coords.map((c) => c.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = coords.map((c) => c.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = coords.map((c) => c.longitude).reduce((a, b) => a > b ? a : b);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        80,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final images = appState.capturedImages;
    final markers = _buildMarkers(images);

    // Current live location marker
    if (appState.latitude != null && appState.longitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(appState.latitude!, appState.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
          zIndex: 10,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF041710),
      appBar: AppBar(
        backgroundColor: const Color(0xFF041710),
        elevation: 0,
        title: const Text(
          'Capture Map',
          style: TextStyle(
            color: Color(0xFF95D4B3),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.fit_screen, color: Color(0xFF95D4B3)),
              tooltip: 'Fit all markers',
              onPressed: () => _fitMapToMarkers(images),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _applyDarkMapStyle(controller);
              // Auto-fit after map loads
              Future.delayed(const Duration(milliseconds: 300), () {
                _fitMapToMarkers(images);
              });
            },
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 5,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),

          // Stats bar at top
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildStatsBar(appState, images),
          ),

          // Selected image card at bottom
          if (_selectedImage != null)
            Positioned(
              bottom: 20,
              left: 12,
              right: 12,
              child: _buildImageCard(_selectedImage!),
            ),

          // Zoom controls (custom, matching dark theme)
          Positioned(
            right: 12,
            bottom: _selectedImage != null ? 180 : 60,
            child: Column(
              children: [
                _buildMapButton(Icons.add, () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                }),
                const SizedBox(height: 8),
                _buildMapButton(Icons.remove, () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                }),
                const SizedBox(height: 8),
                _buildMapButton(Icons.my_location, () {
                  if (appState.latitude != null && appState.longitude != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(appState.latitude!, appState.longitude!),
                        14,
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(AppStateProvider appState, List<CapturedImage> images) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10231C).withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404943).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: const Color(0xFF95D4B3), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appState.currentLocation,
              style: const TextStyle(
                color: Color(0xFFD1E8DC),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${images.length} Captures',
              style: const TextStyle(
                color: Color(0xFFA8E7C5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(CapturedImage image) {
    final hasValidImage = image.path.isNotEmpty && File(image.path).existsSync();

    return GestureDetector(
      onTap: () => setState(() => _selectedImage = null),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF10231C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D6A4F)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: hasValidImage
                    ? Image.file(File(image.path), fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFF1A2E26),
                        child: const Icon(Icons.image_not_supported,
                            color: Color(0xFF8A938C)),
                      ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        image.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Color(0xFFA8E7C5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      image.dateTime,
                      style: const TextStyle(
                        color: Color(0xFFD1E8DC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Color(0xFFBFC9C1)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            image.location,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFBFC9C1),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (image.altitude != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.terrain,
                              size: 12, color: Color(0xFFBFC9C1)),
                          const SizedBox(width: 4),
                          Text(
                            'Alt: ${image.altitude!.toStringAsFixed(1)} m',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFBFC9C1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Close
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8A938C), size: 18),
                onPressed: () => setState(() => _selectedImage = null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF10231C),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF404943)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF95D4B3), size: 18),
      ),
    );
  }

  Future<void> _applyDarkMapStyle(GoogleMapController controller) async {
    const style = '''[
      {"elementType":"geometry","stylers":[{"color":"#0a1f18"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#7a9e8f"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#0a1f18"}]},
      {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1a3a2e"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1e3d30"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#142e23"}]},
      {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2d6a4f"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#041710"}]},
      {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d7a60"}]}
    ]''';
    await controller.setMapStyle(style);
  }
}
