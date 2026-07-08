import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_watermark_plus/video_watermark_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../providers/app_state_provider.dart';

// Local provider for ReviewScreen to avoid setState
class ReviewStateProvider with ChangeNotifier {
  String _selectedCategory = 'Agroforestry';
  String _notes = '';
  
  String get selectedCategory => _selectedCategory;
  String get notes => _notes;

  void setCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  void setNotes(String val) {
    _notes = val;
    notifyListeners();
  }

  void forceUpdate() {
    notifyListeners();
  }
}

Future<String> _processWatermark(Map<String, dynamic> params) async {
  final String imagePath = params['imagePath'];
  final String locationText = params['location'];
  final String dateText = params['date'];
  final bool isLandscape = params['isLandscape'] ?? false;
  
  final originalBytes = File(imagePath).readAsBytesSync();
  img.Image? originalImage = img.decodeImage(originalBytes);
  
  if (originalImage == null) return imagePath;

  if (isLandscape && originalImage.width < originalImage.height) {
    originalImage = img.copyRotate(originalImage, angle: -90);
  } else if (!isLandscape && originalImage.width > originalImage.height) {
    originalImage = img.copyRotate(originalImage, angle: 90);
  }

  const int maxWidth = 1280;
  if (originalImage.width > maxWidth) {
    final int newHeight = (originalImage.height * maxWidth / originalImage.width).round();
    originalImage = img.copyResize(originalImage, width: maxWidth, height: newHeight, interpolation: img.Interpolation.linear);
  }

  final font = img.arial24;
  final String formattedLoc = "Location: $locationText";
  final String formattedDate = "Time: $dateText";
  final String formattedAlt = "Altitude: ${params['altitude']}";
  final String? notesText = params['notes'];

  int linesCount = notesText != null && notesText.isNotEmpty ? 5 : 4;
  int boxHeight = linesCount * 28 + 20;
  int boxY = originalImage.height - boxHeight - 16;
  
  // Draw semi-transparent black background
  img.fillRect(originalImage, x1: 0, y1: boxY, x2: originalImage.width, y2: originalImage.height, color: img.ColorRgba8(0, 0, 0, 150));

  final int x = 16;
  int y = boxY + 10;
  
  img.drawString(originalImage, formattedLoc, font: font, x: x, y: y, color: img.ColorRgb8(255, 255, 255));
  img.drawString(originalImage, formattedDate, font: font, x: x, y: y + 28, color: img.ColorRgb8(255, 255, 255));
  img.drawString(originalImage, formattedAlt, font: font, x: x, y: y + 56, color: img.ColorRgb8(255, 255, 255));
  
  int nextY = y + 84;
  if (notesText != null && notesText.isNotEmpty) {
    img.drawString(originalImage, "Remarks: $notesText", font: font, x: x, y: nextY, color: img.ColorRgb8(255, 255, 255));
    nextY += 28;
  }
  img.drawString(originalImage, "SayTrees Verified", font: font, x: x, y: nextY, color: img.ColorRgb8(177, 240, 206));

  final watermarkedBytes = img.encodeJpg(originalImage, quality: 82);
  File(imagePath).writeAsBytesSync(watermarkedBytes);
  
  return imagePath;
}

Future<String> _processVideoWatermark(String videoPath, String locText, String dateText, String altText, String? notes, int videoWidth) async {
  final directory = await getTemporaryDirectory();
  final font = img.arial48;

  // We want the watermark to be exactly proportional to the video.
  // We use videoWidth to scale the watermark size appropriately.
  // Let's assume the watermark should take up 80% of the video width.
  double scaleFactor = videoWidth > 0 ? (videoWidth * 0.8) / 1200.0 : 1.0;
  if (scaleFactor > 1.5) scaleFactor = 1.5; // cap scaling
  if (scaleFactor < 0.5) scaleFactor = 0.5;
  
  // Generate a transparent PNG for the watermark overlay
  int width = 1200;
  int linesCount = notes != null && notes.isNotEmpty ? 5 : 4;
  int height = linesCount * 56 + 40; 
  final watermarkImg = img.Image(width: width, height: height);
  // Fill with semi-transparent black color (Alpha 150/255 = ~60% opacity)
  img.fill(watermarkImg, color: img.ColorRgba8(0, 0, 0, 150));

  int x = 20;
  int y = 20;
  img.drawString(watermarkImg, "Location: $locText", font: font, x: x, y: y, color: img.ColorRgb8(255, 255, 255));
  img.drawString(watermarkImg, "Time: $dateText", font: font, x: x, y: y + 56, color: img.ColorRgb8(255, 255, 255));
  img.drawString(watermarkImg, "Altitude: $altText", font: font, x: x, y: y + 112, color: img.ColorRgb8(255, 255, 255));
  
  int nextY = y + 168;
  if (notes != null && notes.isNotEmpty) {
    img.drawString(watermarkImg, "Remarks: $notes", font: font, x: x, y: nextY, color: img.ColorRgb8(255, 255, 255));
    nextY += 56;
  }
  img.drawString(watermarkImg, "SayTrees Verified", font: font, x: x, y: nextY, color: img.ColorRgb8(177, 240, 206));

  final wmBytes = img.encodePng(watermarkImg);
  final wmFile = File('${directory.path}/wm_${DateTime.now().millisecondsSinceEpoch}.png');
  await wmFile.writeAsBytes(wmBytes);

  Completer<String> completer = Completer();
  VideoWatermark videoWatermark = VideoWatermark(
    sourceVideoPath: videoPath,
    watermark: Watermark(
      image: WatermarkSource.file(wmFile.path),
      watermarkAlignment: WatermarkAlignment.bottomLeft,
      opacity: 1.0,
      watermarkSize: WatermarkSize(width * scaleFactor, height * scaleFactor),
    ),
    onSave: (path) {
      if (path != null) completer.complete(path);
      else completer.completeError("Video processing failed");
    },
  );

  videoWatermark.generateVideo();
  return completer.future;
}

class ReviewScreen extends StatelessWidget {
  final String mediaPath; // Empty if using captureFuture
  final bool isLandscape;
  final bool isVideo;
  final Future<String>? captureFuture;

  const ReviewScreen({
    Key? key,
    required this.mediaPath,
    required this.isLandscape,
    this.isVideo = false,
    this.captureFuture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReviewStateProvider(),
      child: _ReviewScreenBody(
        mediaPath: mediaPath,
        isLandscape: isLandscape,
        isVideo: isVideo,
        captureFuture: captureFuture,
      ),
    );
  }
}

class _ReviewScreenBody extends StatefulWidget {
  final String mediaPath;
  final bool isLandscape;
  final bool isVideo;
  final Future<String>? captureFuture;

  const _ReviewScreenBody({
    Key? key,
    required this.mediaPath,
    required this.isLandscape,
    required this.isVideo,
    this.captureFuture,
  }) : super(key: key);

  @override
  __ReviewScreenBodyState createState() => __ReviewScreenBodyState();
}

class __ReviewScreenBodyState extends State<_ReviewScreenBody> {
  final TextEditingController _notesController = TextEditingController();
  VideoPlayerController? _videoPlayerController;
  String? _actualMediaPath;

  static const String _categoryKey = 'last_selected_category';

  final List<String> categories = [
    'Agroforestry',
    'Forestry',
    'Biogas',
    'Water Conservation',
    'Biochar',
    'Mangroves',
    'Bamboo'
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedCategory();
    _notesController.addListener(() {
      context.read<ReviewStateProvider>().setNotes(_notesController.text.trim());
    });
    
    if (widget.captureFuture != null) {
      widget.captureFuture!.then((path) {
        if (mounted) {
          setState(() {
            _actualMediaPath = path;
          });
          _initMedia();
        }
      }).catchError((e) {
        print("Error capturing media: $e");
        if (mounted) Navigator.pop(context);
      });
    } else {
      _actualMediaPath = widget.mediaPath;
      _initMedia();
    }
  }

  void _initMedia() {
    if (widget.isVideo && _actualMediaPath != null && _actualMediaPath!.isNotEmpty) {
      _videoPlayerController = VideoPlayerController.file(File(_actualMediaPath!))
        ..initialize().then((_) {
          _videoPlayerController!.setLooping(true);
          _videoPlayerController!.play();
          Future.microtask(() {
            if (mounted) context.read<ReviewStateProvider>().forceUpdate();
          });
        });
    }
  }

  Future<void> _loadSavedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_categoryKey);
    if (saved != null && categories.contains(saved)) {
      if (mounted) context.read<ReviewStateProvider>().setCategory(saved);
    }
  }

  Future<void> _saveSelectedCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoryKey, category);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  void _saveToProject() {
    final appState = context.read<AppStateProvider>();
    final reviewState = context.read<ReviewStateProvider>();
    
    // 1. Grab all synchronous state needed for processing
    final String locText = appState.currentLocation;
    final String dateText = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final String category = reviewState.selectedCategory;
    final String? notes = reviewState.notes.isEmpty ? null : reviewState.notes;
    final double? lat = appState.latitude;
    final double? lng = appState.longitude;
    final double? altitude = appState.altitude;
    final String altText = altitude != null ? "${altitude.toStringAsFixed(1)} m" : "Unknown";
    
    if (_actualMediaPath == null || _actualMediaPath!.isEmpty) return; // Prevent saving before capture finishes

    // Stop playing video before intensive FFmpeg encoding to save GPU memory
    _videoPlayerController?.pause();
    
    final String mediaPath = _actualMediaPath!;
    final bool isVideo = widget.isVideo;
    int vWidth = 1080;
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      vWidth = _videoPlayerController!.value.size.width.toInt();
    }

    // 2. Show a snackbar and immediately pop the screen to prevent UI lag
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Processing capture in background...')),
    );
    Navigator.pop(context);

    // 3. Launch background process
    Future.microtask(() async {
      try {
        await _saveSelectedCategory(category);
        
        String finalPath = mediaPath;
        if (!isVideo) {
          finalPath = await compute(_processWatermark, {
            'imagePath': mediaPath,
            'location': locText,
            'date': dateText,
            'altitude': altText,
            'isLandscape': widget.isLandscape,
            'notes': notes,
          });
        } else {
          finalPath = await _processVideoWatermark(mediaPath, locText, dateText, altText, notes, vWidth);
        }

        final directory = await getApplicationDocumentsDirectory();
        final String extension = widget.isVideo ? '.mp4' : '.jpg';
        final String localFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
        final String localPath = '${directory.path}/$localFileName';
        await File(finalPath).copy(localPath);

        String? thumbPath;
        if (widget.isVideo) {
          final uint8list = await VideoThumbnail.thumbnailData(
            video: localPath,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 512,
            quality: 50,
          );
          if (uint8list != null) {
            final thumbFile = File('${directory.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await thumbFile.writeAsBytes(uint8list);
            thumbPath = thumbFile.path;
          }
        }

        final String localId = 'capture_${DateTime.now().millisecondsSinceEpoch}';
        final newImage = CapturedImage(
          localId: localId,
          path: localPath,
          category: category,
          location: locText,
          dateTime: dateText,
          notes: notes,
          lat: lat,
          lng: lng,
          altitude: altitude,
          synced: false,
          isVideo: widget.isVideo,
          thumbnailPath: thumbPath,
        );
        await appState.addCapturedImage(newImage);

        bool hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          hasAccess = await Gal.requestAccess(toAlbum: true);
        }
        if (hasAccess) {
          if (widget.isVideo) {
            await Gal.putVideo(localPath);
          } else {
            await Gal.putImage(localPath);
          }
        }

      } catch (e, stacktrace) {
        print('Error saving: $e\n$stacktrace');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final reviewState = context.watch<ReviewStateProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF041710),
      appBar: AppBar(
        backgroundColor: const Color(0xFF041710),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFFBFC9C1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Review Capture',
          style: TextStyle(
            color: const Color(0xFF95D4B3),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 350,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF404943).withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2D6A4F).withOpacity(0.2),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_actualMediaPath == null)
                            Center(child: CircularProgressIndicator(color: const Color(0xFF95D4B3)))
                          else if (widget.isVideo && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                            Stack(
                              fit: StackFit.expand,
                              children: [
                                AspectRatio(
                                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                                  child: VideoPlayer(_videoPlayerController!),
                                ),
                                Positioned(
                                  left: 16,
                                  bottom: 16,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Location: ${appState.currentLocation}',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                      ),
                                      if (reviewState.notes.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Remarks: ${reviewState.notes}',
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      const Text(
                                        'SayTrees Verified',
                                        style: TextStyle(color: Color(0xFFB1F0CE), fontSize: 14, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else if (!widget.isVideo)
                            Image.file(
                              File(_actualMediaPath!),
                              fit: BoxFit.cover,
                            ),
                          if (!widget.isVideo)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2E26).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF404943)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, color: const Color(0xFFF4BA9C)),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'LOCATION DATA',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                              color: const Color(0xFFBFC9C1),
                                            ),
                                          ),
                                          Text(
                                            appState.currentLocation,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFFD1E8DC),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.satellite_alt, color: const Color(0xFF95D4B3)),
                                  ],
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: const Color(0xFF253931))),
                      ),
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Project Category',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD1E8DC),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected = reviewState.selectedCategory == category;
                        return ChoiceChip(
                          label: Text(
                            category,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFF003824) : const Color(0xFFBFC9C1),
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (selected) {
                              context.read<ReviewStateProvider>().setCategory(category);
                            }
                          },
                          backgroundColor: Colors.transparent,
                          selectedColor: const Color(0xFF95D4B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : const Color(0xFF8A938C),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: const Color(0xFF253931))),
                      ),
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Remarks',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD1E8DC),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      style: TextStyle(color: const Color(0xFFD1E8DC)),
                      decoration: InputDecoration(
                        hintText: 'Enter environmental observations, species details, or anomalous data points...',
                        hintStyle: TextStyle(color: const Color(0xFFBFC9C1).withOpacity(0.5)),
                        filled: true,
                        fillColor: const Color(0xFF01110B),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: const Color(0xFF404943).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: const Color(0xFF95D4B3)),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.replay, color: const Color(0xFFB3CDB7)),
                            label: Text('Retake', style: TextStyle(color: const Color(0xFFB3CDB7))),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: const Color(0xFFB3CDB7)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _saveToProject,
                            icon: Icon(Icons.check_circle, color: const Color(0xFF003824)),
                            label: Text('Save to Project', style: TextStyle(color: const Color(0xFF003824), fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF95D4B3),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
