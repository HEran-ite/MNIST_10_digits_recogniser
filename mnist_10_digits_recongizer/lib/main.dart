import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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
  late Interpreter _interpreter;
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
    _cameraController = CameraController(camera, ResolutionPreset.high);
    await _cameraController.initialize();
    setState(() => _cameraInitialized = true);
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('mnist_model.tflite');
    } catch (e) {
      debugPrint("Error loading model: $e");
    }
  }

  Float32List preprocessImage(img.Image image) {
    final resizedImage = img.copyResize(image, width: 28, height: 28);
    final input = Float32List(28 * 28);
    for (int i = 0; i < 28; i++) {
      for (int j = 0; j < 28; j++) {
        final pixel = resizedImage.getPixel(j, i);
        final red = img.getRed(pixel);
        input[i * 28 + j] = red / 255.0;
      }
    }
    return Float32List.fromList(input);
  }

  Future<int> _predictDigit(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      debugPrint("Error decoding image.");
      return -1;
    }

    final input = preprocessImage(image);
    final output = Float32List(10);
    _interpreter.run(input.buffer.asFloat32List(), output);

    final digit = output
        .indexWhere((val) => val == output.reduce((a, b) => a > b ? a : b));
    return digit;
  }

  Future<void> _captureAndRecognize() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController.takePicture();
      final imageBytes = await image.readAsBytes();
      final digit = await _predictDigit(imageBytes);

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

  void _flipCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _cameraController.dispose();
      _initializeCamera();
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
      final imageBytes = await File(pickedFile.path).readAsBytes();
      final digit = await _predictDigit(imageBytes);

      if (digit >= 0) {
        await _flutterTts.speak("The number is $digit");
      } else {
        debugPrint("Failed to recognize digit.");
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _interpreter.close();
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
              child: ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 44, 147, 168),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
                child: const Text(
                  "Launch Camera",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
    );
  }
}
