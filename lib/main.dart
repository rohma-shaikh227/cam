import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

List<CameraDescription>? cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Example',
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  late Future<void> initializeController;
  bool isRecording = false;
  List<int> videoBytes = [];

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  void initializeCamera() async {
    final frontCamera = cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front);

    controller = CameraController(frontCamera, ResolutionPreset.high);

    try {
      initializeController = controller.initialize();
      await initializeController;
    } catch (e) {
      print('Failed to initialize camera: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      body: CameraPreview(controller),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!isRecording) {
            _startVideoRecording();
          } else {
            _stopVideoRecording();
          }
        },
        child: Icon(isRecording ? Icons.stop : Icons.camera),
      ),
    );
  }

  void _startVideoRecording() async {
    if (!controller.value.isInitialized) {
      return;
    }
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String videoDirectory = '${appDirectory.path}/Videos';
    await Directory(videoDirectory).create(recursive: true);
    final String videoPath = '$videoDirectory/${DateTime
        .now()
        .millisecondsSinceEpoch}.mp4';

    try {
      await controller.startVideoRecording().then((value) => videoPath);
      setState(() {
        isRecording = true;
      });
      // Start a timer to stop the recording after 15 seconds
      Timer(Duration(seconds: 15), () {
        _stopVideoRecording();
      });
    } catch (e) {
      print(e);
    }
  }

  void _stopVideoRecording() async {
    if (!controller.value.isRecordingVideo) {
      return;
    }
    setState(() {
      isRecording = false;
    });
    XFile videoFile;
    try {
      videoFile = await controller.stopVideoRecording();
      final videoBytesChunk = await videoFile.readAsBytes();
      print("converting into bytes");
      videoBytes.addAll(videoBytesChunk);
      if (videoBytes.isNotEmpty) {
        // Send the video bytes to the API
        sendVideoToAPI(videoBytes);
        // print("sending to api fun");
      }
      videoBytes.clear();
    } catch (e) {
      print("error not sent $e");
    }
  }

  void sendVideoToAPI(List<int> bytes) async {
    print("in video to api fun");
    final String url ='http://localhost:5000/predict';
    print("send video to api");

    final response = await http.post(Uri.parse(url), body: bytes);
    print("parse");
    if (response.statusCode == 200) {
      print('Video sent to API successfully');
    } else {
      print('Failed to send video to API. Status code: ${response.statusCode}');
    }
  }
}