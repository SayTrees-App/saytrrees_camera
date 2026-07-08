import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/app_state_provider.dart';
import '../main.dart'; // To access the global `cameras` list
import 'review_screen.dart'; // New Review Screen

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _isRecordingVideo = false;
  bool _isVideoMode = false;
  DateTime? _lastCaptureTime;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _initCamera(cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true, // Enabled for video
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }
    
    await _controller!.setFlashMode(nextMode);
    setState(() {
      _flashMode = nextMode;
    });
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on;
    }
  }

  void _flipCamera() {
    if (cameras.length < 2) return;
    
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    _initCamera(cameras[_selectedCameraIndex]);
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    final now = DateTime.now();
    if (_isProcessing || (_lastCaptureTime != null && now.difference(_lastCaptureTime!).inMilliseconds < 1000)) {
      return; // Debounce rapid taps (wait 1 second)
    }
    
    if (_controller!.value.isTakingPicture || _controller!.value.isRecordingVideo) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _lastCaptureTime = now;
    });
    
    try {
      final Future<XFile> captureFuture = _controller!.takePicture();
      final orientation = MediaQuery.of(context).orientation;
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewScreen(
              mediaPath: "",
              captureFuture: captureFuture.then((file) => file.path),
              isLandscape: orientation == Orientation.landscape,
              isVideo: false,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error capturing picture.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo || _isProcessing) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecordingVideo = true;
      });
    } catch (e) {
      print('Error starting video recording: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final Future<XFile> captureFuture = _controller!.stopVideoRecording();
      final orientation = MediaQuery.of(context).orientation;
      
      setState(() {
        _isRecordingVideo = false;
        _isProcessing = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewScreen(
              mediaPath: "",
              captureFuture: captureFuture.then((file) => file.path),
              isLandscape: orientation == Orientation.landscape,
              isVideo: true,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error stopping video recording: $e');
      setState(() {
        _isRecordingVideo = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _openPhotoLibrary() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        print('Image selected: ${image.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected image: ${image.name}')),
        );
      }
    } catch (e) {
      print('Error opening photo library: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (context, orientation) {
          bool isPortrait = orientation == Orientation.portrait;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Viewfinder Background
              if (_controller != null && _controller!.value.isInitialized)
                CameraPreview(_controller!)
              else
                Container(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              
              // Overlay Level Indicator (Simulated)
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 192,
                        height: 1,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      Container(
                        width: 1,
                        height: 192,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        child: Container(
                          width: 8,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.8),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // Top Action Bar
              SafeArea(
                child: Align(
                  alignment: isPortrait ? Alignment.topCenter : Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isPortrait ? 20 : 8, 
                      vertical: isPortrait ? 8 : 20
                    ),
                    child: isPortrait 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildGlassButton(Icons.person, () {}),
                            _buildGlassButton(_getFlashIcon(), _toggleFlash),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildGlassButton(Icons.person, () {}),
                            _buildGlassButton(_getFlashIcon(), _toggleFlash),
                          ],
                        )
                  ),
                ),
              ),

              // Controls & Data Overlay
              SafeArea(
                child: Align(
                  alignment: isPortrait ? Alignment.bottomCenter : Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isPortrait ? 20 : 0, 
                      right: 20, 
                      bottom: isPortrait ? 20 : 0,
                      top: isPortrait ? 0 : 20,
                    ),
                    child: isPortrait
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDataOverlayRow(appState),
                              SizedBox(height: 24),
                              _buildModeSwitcher(),
                              SizedBox(height: 12),
                              _buildCameraControls(appState, true),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildDataOverlayColumn(appState),
                                ],
                              ),
                              SizedBox(width: 24),
                              _buildModeSwitcher(isPortrait: false),
                              SizedBox(width: 12),
                              _buildCameraControls(appState, false),
                            ],
                          ),
                  ),
                ),
              ),

            ],
          );
        }
      ),
    );
  }

  Widget _buildDataOverlayRow(AppStateProvider appState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildLocationData(appState),
        _buildVerifiedBadge(),
      ],
    );
  }

  Widget _buildDataOverlayColumn(AppStateProvider appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildLocationData(appState),
        SizedBox(height: 8),
        _buildVerifiedBadge(),
      ],
    );
  }

  Widget _buildLocationData(AppStateProvider appState) {
    return _buildGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            appState.currentLocation,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return _buildGlassPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            "SayTrees Verified",
            style: TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher({bool isPortrait = true}) {
    final switcher = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (!_isRecordingVideo) setState(() => _isVideoMode = false);
            },
            child: Text('PHOTO', style: TextStyle(fontSize: 12, color: !_isVideoMode ? Colors.amber : Colors.white54, fontWeight: !_isVideoMode ? FontWeight.bold : FontWeight.normal)),
          ),
          SizedBox(width: 24),
          GestureDetector(
            onTap: () {
              if (!_isRecordingVideo) setState(() => _isVideoMode = true);
            },
            child: Text('VIDEO', style: TextStyle(fontSize: 12, color: _isVideoMode ? Colors.amber : Colors.white54, fontWeight: _isVideoMode ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
    
    return isPortrait 
      ? switcher 
      : RotatedBox(quarterTurns: 1, child: switcher);
  }

  Widget _buildCameraControls(AppStateProvider appState, bool isPortrait) {
    final controls = [
      IconButton(
        icon: Icon(Icons.photo_library, color: Colors.white.withOpacity(0.8)),
        onPressed: _openPhotoLibrary,
      ),
      GestureDetector(
        onTap: () {
          if (_isVideoMode) {
            if (_isRecordingVideo) {
              _stopVideoRecording();
            } else {
              _startVideoRecording();
            }
          } else {
            _takePicture();
          }
        },
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              color: _isRecordingVideo ? Colors.red : const Color(0xFF2C694E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: _isRecordingVideo ? 8 : 4),
              boxShadow: [
                BoxShadow(
                  color: _isRecordingVideo ? Colors.red.withOpacity(0.6) : const Color(0xFF2C694E).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _isRecordingVideo ? Icons.stop : Icons.camera_alt, 
              color: Colors.white, 
              size: 32
            ),
          ),
        ),
      ),
      IconButton(
        icon: Icon(Icons.flip_camera_ios, color: Colors.white.withOpacity(0.8)),
        onPressed: _flipCamera,
      ),
    ];

    return _buildGlassPanel(
      padding: EdgeInsets.all(16),
      child: isPortrait
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: controls,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.min,
              children: controls,
            ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildGlassPanel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(8)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: child,
    );
  }
}
