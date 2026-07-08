import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'providers/app_state_provider.dart';
import 'screens/main_screen.dart';

List<CameraDescription> cameras = [];

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    if (task == "backgroundLocationTask") {
      try {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        print("Background Location: ${position.latitude}, ${position.longitude}");
        // In a real app, you would send this location to a backend server.
      } catch (e) {
        print("Error fetching location in background: $e");
      }
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB cap
  
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }
  
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Register the background location task to run periodically.
  // Note: Minimum interval on Android/iOS is ~15 minutes.
  Workmanager().registerPeriodicTask(
    "1",
    "backgroundLocationTask",
    frequency: Duration(minutes: 15),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'SayTrees',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: const Color(0xFF012D1D),
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            fontFamily: 'Inter',
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            primaryColor: const Color(0xFF95D4B3),
            scaffoldBackgroundColor: const Color(0xFF041710),
            fontFamily: 'Inter',
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainScreen(),
        );
      },
    );
  }
}
