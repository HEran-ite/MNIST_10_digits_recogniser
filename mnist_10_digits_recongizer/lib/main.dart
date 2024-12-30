import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    _cameraController =
        CameraController(widget.cameras.first, ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('mnist_model.tflite');
    } catch (e) {
      debugPrint("Error loading model: $e");
    }
  }



Float32List preprocessImage(img.Image image) {
  // Resize the image to 28x28.
  final resizedImage = img.copyResize(image, width: 28, height: 28);

  // Normalize pixel values to grayscale.
  final input = Float32List(28 * 28);
  for (int i = 0; i < 28; i++) {
    for (int j = 0; j < 28; j++) {
      final pixel = resizedImage.getPixel(j, i); // ARGB pixel value

      // Extract red, green, and blue components
      final red = img.getRed(pixel);   // Extract red channel
      final green = img.getGreen(pixel); // Extract green channel (optional)
      final blue = img.getBlue(pixel);  // Extract blue channel (optional)

      // You can combine the channels for grayscale, for now using red only
      input[i * 28 + j] = red / 255.0; // Normalize to [0.0, 1.0]
    }
  }

  return Float32List.fromList(input); // Return the processed input
}

  Future<int> _predictDigit(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      debugPrint("Error decoding image.");
      return -1; // Invalid prediction
    }

    final input = preprocessImage(image);
    final output =
        Float32List(10); // Output is a 1D tensor of size 10 for probabilities

    _interpreter.run(input.buffer.asFloat32List(), output);

    // Find the digit with the highest probability
    final digit = output
        .indexWhere((val) => val == output.reduce((a, b) => a > b ? a : b));
    return digit;
  }

  void _captureAndPredict() async {
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
      appBar: AppBar(title: const Text("Digit Recognizer")),
      body: _cameraController.value.isInitialized
          ? Column(
              children: [
                Expanded(child: CameraPreview(_cameraController)),
                if (_isProcessing)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _captureAndPredict,
                    child: const Text("Capture and Recognize"),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
