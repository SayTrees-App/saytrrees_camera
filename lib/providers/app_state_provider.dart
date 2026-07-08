import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CapturedImage {
  final String localId;
  final String path;
  final String category;
  final String location; // human-readable string
  final String dateTime;
  final String? notes;
  final double? lat;   // exact GPS latitude
  final double? lng;   // exact GPS longitude
  final double? altitude;
  final bool synced;
  final bool isVideo;
  final String? thumbnailPath;

  CapturedImage({
    required this.localId,
    required this.path,
    required this.category,
    required this.location,
    required this.dateTime,
    this.notes,
    this.lat,
    this.lng,
    this.altitude,
    this.synced = false,
    this.isVideo = false,
    this.thumbnailPath,
  });

  CapturedImage copyWith({bool? synced, bool? isVideo}) {
    return CapturedImage(
      localId: localId,
      path: path,
      category: category,
      location: location,
      dateTime: dateTime,
      notes: notes,
      lat: lat,
      lng: lng,
      altitude: altitude,
      synced: synced ?? this.synced,
      isVideo: isVideo ?? this.isVideo,
      thumbnailPath: thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'path': path,
        'category': category,
        'location': location,
        'dateTime': dateTime,
        'notes': notes,
        'lat': lat,
        'lng': lng,
        'altitude': altitude,
        'synced': synced,
        'isVideo': isVideo,
        'thumbnailPath': thumbnailPath,
      };

  factory CapturedImage.fromJson(Map<String, dynamic> json) {
    return CapturedImage(
      localId: json['localId'] ?? json['dateTime'] ?? DateTime.now().toIso8601String(),
      path: json['path'],
      category: json['category'],
      location: json['location'],
      dateTime: json['dateTime'],
      notes: json['notes'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      synced: json['synced'] ?? false,
      isVideo: json['isVideo'] ?? false,
      thumbnailPath: json['thumbnailPath'],
    );
  }
}


class AppStateProvider with ChangeNotifier {
  String _selectedCategory = 'ALL';
  String _currentLocation = 'Fetching location...';
  double? _latitude;
  double? _longitude;
  double? _altitude;
  List<CapturedImage> _capturedImages = [];
  bool _isDarkMode = true;
  String _currentView = 'Grid'; // 'Grid', 'List', 'Map'
  bool _isSaving = false;

  String get selectedCategory => _selectedCategory;
  String get currentLocation => _currentLocation;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get altitude => _altitude;
  List<CapturedImage> get capturedImages => _capturedImages;
  List<CapturedImage> get unsyncedImages => _capturedImages.where((img) => !img.synced).toList();
  bool get isDarkMode => _isDarkMode;
  String get currentView => _currentView;
  bool get isSaving => _isSaving;

  AppStateProvider() {
    _loadImages();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setCurrentView(String view) {
    _currentView = view;
    notifyListeners();
  }

  void setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  void updateLocation(double lat, double lng, {double? altitude}) {
    _latitude = lat;
    _longitude = lng;
    _altitude = altitude;
    String latDir = lat >= 0 ? 'N' : 'S';
    String lngDir = lng >= 0 ? 'E' : 'W';
    _currentLocation = 'Lat: ${lat.abs().toStringAsFixed(4)}° $latDir | Long: ${lng.abs().toStringAsFixed(4)}° $lngDir';
    notifyListeners();
  }

  void setLocationError(String error) {
    _currentLocation = error;
    notifyListeners();
  }

  Future<void> _loadImages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? imagesStr = prefs.getString('captured_images');
    if (imagesStr != null) {
      final List<dynamic> decoded = jsonDecode(imagesStr);
      _capturedImages = decoded.map((e) => CapturedImage.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> addCapturedImage(CapturedImage image) async {
    _capturedImages.insert(0, image); // Add to beginning (newest first)
    notifyListeners();
    await _saveImages();
  }

  /// Mark a captured image as synced to Firestore
  Future<void> markSynced(String localId) async {
    final index = _capturedImages.indexWhere((img) => img.localId == localId);
    if (index != -1) {
      _capturedImages[index] = _capturedImages[index].copyWith(synced: true);
      notifyListeners();
      await _saveImages();
    }
  }

  Future<void> _saveImages() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_capturedImages.map((e) => e.toJson()).toList());
    await prefs.setString('captured_images', encoded);
  }
}
