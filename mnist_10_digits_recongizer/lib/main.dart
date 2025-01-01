import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 159, 206, 225),
      ),
      home: DigitRecognizer(cameras: cameras),
    );
  }
}

class DigitRecognizer extends StatefulWidget {
  final List<CameraDescription> cameras;
  const DigitRecognizer({super.key, required this.cameras});

  @override
  _DigitRecognizerState createState() => _DigitRecognizerState();
}

class _DigitRecognizerState extends State<DigitRecognizer> {
  late CameraController _cameraController;
  final FlutterTts _flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool _cameraInitialized = false;
  bool _isFrontCamera = false;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  void _initializeCamera() async {
    final camera = _isFrontCamera ? widget.cameras.last : widget.cameras.first;
    _cameraController = CameraController(camera, ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() => _cameraInitialized = true);
  }

  Future<void> _loadModel() async {
    try {
      String? result = await Tflite.loadModel(
        model: "assets/mnist_model.tflite", // Ensure the model is in assets/
      );
      debugPrint("Model loaded: $result");
    } catch (e) {
      debugPrint("Error loading model: $e");
    }
  }

  Future<int> _predictDigit(String imagePath) async {
    try {
      var recognitions = await Tflite.runModelOnImage(
        path: imagePath, // Path to the image file
        imageMean: 0.0,
        imageStd: 255.0,
        numResults: 1,
        threshold: 0.1,
      );

      if (recognitions != null && recognitions.isNotEmpty) {
        final digit = recognitions[0]["index"] as int;
        return digit;
      } else {
        debugPrint("No recognitions found.");
        return -1;
      }
    } catch (e) {
      debugPrint("Error during prediction: $e");
      return -1;
    }
  }

  Future<void> _captureAndRecognize() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController.takePicture();
      final digit = await _predictDigit(image.path);

      if (digit >= 0) {
        await _flutterTts.speak("The number is $digit");
      } else {
        debugPrint("Failed to recognize digit.");
      }
    } catch (e) {
      debugPrint("Error capturing or processing image: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
      final digit = await _predictDigit(pickedFile.path);

      if (digit >= 0) {
        await _flutterTts.speak("The number is $digit");
      } else {
        debugPrint("Failed to recognize digit.");
      }
    }
  }

  void _flipCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _cameraController.dispose();
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    Tflite.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Digit Recognizer"),
        backgroundColor: const Color.fromARGB(255, 44, 147, 168),
      ),
      body: _cameraInitialized
          ? Column(
              children: [
                Expanded(child: CameraPreview(_cameraController)),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _pickImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 44, 147, 168),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                        ),
                        child: const Icon(Icons.photo_library,
                            color: Colors.white, size: 50),
                      ),
                      ElevatedButton(
                        onPressed: _captureAndRecognize,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 44, 147, 168),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                        ),
                        child: const Icon(Icons.camera,
                            color: Colors.white, size: 50),
                      ),
                      ElevatedButton(
                        onPressed: _flipCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 44, 147, 168),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(20),
                        ),
                        child: const Icon(Icons.flip_camera_android,
                            color: Colors.white, size: 50),
                      ),
                    ],
                  ),
                ),
                if (_imageFile != null) ...[
                  const SizedBox(height: 20),
                  Image.file(File(_imageFile!.path), height: 200),
                ],
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Welcome to Digit Recognizer",
                    style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Icon(Icons.camera_alt, size: 100, color: Colors.white),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _initializeCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 44, 147, 168),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 20),
                    ),
                    child: const Text(
                      "Launch Camera",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
