import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/rendering.dart' as ui;
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:herbal_i/screens/user/components/plant_result_modal.dart';
import 'dart:typed_data';

// Constants for plant database management
const int ML_CLASSES_COUNT = 41; // Classes 0-40 (including "Not a Leaf")
const int TOTAL_PLANTS_COUNT = 105; // Plants 0-104
const int NOT_A_LEAF_CLASS_ID = 40; // "Not a Leaf" class ID

class DetectPage extends StatefulWidget {
  const DetectPage({super.key});

  @override
  State<DetectPage> createState() => _DetectPageState();
}

class _DetectPageState extends State<DetectPage> {
  File? _image;
  final picker = ImagePicker();
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isModelLoaded = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _detectedPlant;
  double? _confidence;
  int? _detectedClassId;
  List<String> _labels = [];
  Interpreter? _interpreter;
  List<dynamic>? _detections;
  int? _pendingClassId;
  double? _pendingConfidence;
  String? _pendingAction;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['redirectToPlantId'] != null) {
      final int classId = args['redirectToPlantId'];
      final String? action = args['pendingAction'];
      final double confidence = args['confidence'] ?? 0.0;
      final String? label = args['label'];
      setState(() {
        _detectedClassId = classId;
        _confidence = confidence;
        _detectedPlant = label;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (ctx) => PlantResultModal(
            classId: classId,
            confidence: confidence,
          ),
        );
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      print('🔄 Starting model loading...');
      final modelPath = 'assets/best.tflite';
      print('📁 Model path: $modelPath');
      _interpreter = await Interpreter.fromAsset(modelPath);
      print('✅ Model loaded successfully');
      if (_interpreter != null) {
        final inputShape = _interpreter!.getInputTensor(0).shape;
        final outputShape = _interpreter!.getOutputTensor(0).shape;
        print('📊 Model input shape: $inputShape');
        print('📊 Model output shape: $outputShape');
        // Verify input shape is [1, 640, 640, 3]
        if (inputShape[1] != 640 || inputShape[2] != 640 || inputShape[3] != 3) {
          throw Exception('Model expects input shape [1, 640, 640, 3], but got $inputShape');
        }
        // Verify output shape matches our expected ML classes count
        if (outputShape[1] != ML_CLASSES_COUNT) {
          print('⚠️ Warning: Model output shape suggests ${outputShape[1]} classes, but we expect $ML_CLASSES_COUNT');
        }
      }
      _isModelLoaded = true;
    } catch (e) {
      print('❌ Error loading model: $e');
      _errorMessage = 'Failed to load model: $e';
      _isModelLoaded = false;
    }
  }

  Future<void> _loadLabels() async {
    try {
      print('🔄 Starting label loading...');
      final labelPath = 'assets/labels.txt';
      print('📁 Label path: $labelPath');
      final labelData = await rootBundle.loadString(labelPath);
      _labels = labelData.split('\n').map((label) => label.trim()).toList();
      print('✅ Labels loaded successfully');
      print('📝 Number of labels: ${_labels.length}');
      print('📝 First few labels: ${_labels.take(5).join(', ')}');
      
      // Verify we have the correct number of ML classes
      if (_labels.length != ML_CLASSES_COUNT) {
        print('⚠️ Warning: Expected $ML_CLASSES_COUNT ML classes, but found ${_labels.length}');
      }
    } catch (e) {
      print('❌ Error loading labels: $e');
      _errorMessage = 'Failed to load labels: $e';
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(File imageFile) async {
    try {
      print('🔄 Starting image preprocessing...');
      final imageBytes = await imageFile.readAsBytes();
      final image = await decodeImageFromList(imageBytes);
      print('✅ Image decoded successfully');
      print('📊 Original image size: ${image.width}x${image.height}');
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, 640.0, 640.0),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(640, 640);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = byteData!.buffer.asUint8List();
      var imageMatrix = List.generate(
        640,
        (y) => List.generate(
          640,
          (x) {
            final pixelIndex = (y * 640 + x) * 4;
            return [
              pixels[pixelIndex] / 255.0,
              pixels[pixelIndex + 1] / 255.0,
              pixels[pixelIndex + 2] / 255.0,
            ];
          },
        ),
      );
      return [imageMatrix];
    } catch (e) {
      print('❌ Error preprocessing image: $e');
      throw Exception('Failed to preprocess image: $e');
    }
  }

  Future<void> _processImage(File imageFile) async {
    if (!_isModelLoaded || _labels.isEmpty || _interpreter == null) {
      print('❌ Model or labels not loaded');
      _errorMessage = 'Model or labels not loaded';
      return;
    }
    try {
      print('🔄 Starting image processing...');
      final image = await _preprocessImage(imageFile);
      print('✅ Image preprocessed successfully');
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('📊 Output shape: $outputShape');
      var outputBuffer = List.filled(outputShape.reduce((a, b) => a * b), 0.0).reshape(outputShape);
      _interpreter!.run(image, outputBuffer);
      print('✅ Model inference completed');
      // Post-process detections
      final best = _postProcessYOLO(outputBuffer);
      setState(() {
        _detectedPlant = best['label'];
        _confidence = best['confidence'];
        _detectedClassId = best['classId'];
        _errorMessage = '';
      });
      
      // Handle detection results
      if (_detectedClassId != null && _detectedClassId! >= 0) {
        // Check if it's "Not a Leaf"
        if (best['isNotALeaf'] == true) {
          // Show special message for "Not a Leaf" detection
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('No Plant Detected'),
              content: const Text('The image does not appear to contain a plant leaf. Please try with a clear image of a plant leaf.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Valid plant detection - save to database and show result
          final scanKey = await _saveScanResultToDatabase(
            classId: _detectedClassId!,
            confidence: _confidence ?? 0.0,
            plantName: _detectedPlant ?? '',
          );
          showDialog(
            context: context,
            builder: (ctx) => PlantResultModal(
              classId: _detectedClassId!,
              confidence: _confidence ?? 0.0,
              scanKey: scanKey,
              onClosed: () async {
                await Future.delayed(const Duration(milliseconds: 200));
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx2) => FeedbackDialog(
                    classId: _detectedClassId!,
                  ),
                );
              },
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error processing image: $e');
      _errorMessage = 'Error processing image: $e';
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Map<String, dynamic> _postProcessYOLO(List outputBuffer, {double confThreshold = 0.25}) {
    // outputBuffer shape: [1, 25200, 45] (YOLOv5/YOLOv8)
    // Each detection: [x, y, w, h, obj_conf, class1, class2, ..., classN]
    final detections = outputBuffer[0];
    double bestConf = 0.0;
    int bestClass = -1;
    for (var det in detections) {
      final objConf = det[4];
      if (objConf > confThreshold) {
        double maxClassScore = 0.0;
        int maxClassIdx = -1;
        for (int i = 5; i < det.length; i++) {
          if (det[i] > maxClassScore) {
            maxClassScore = det[i];
            maxClassIdx = i - 5;
          }
        }
        final conf = objConf * maxClassScore;
        if (conf > bestConf) {
          bestConf = conf;
          bestClass = maxClassIdx;
        }
      }
    }
    if (bestClass >= 0 && bestClass < ML_CLASSES_COUNT) {
      String label = _labels[bestClass];
      if (bestClass == NOT_A_LEAF_CLASS_ID) {
        return {
          'label': 'Not a Leaf',
          'confidence': bestConf,
          'classId': bestClass,
          'isNotALeaf': true,
        };
      }
      return {
        'label': label,
        'confidence': bestConf,
        'classId': bestClass,
        'isNotALeaf': false,
      };
    }
    return {
      'label': 'No detection',
      'confidence': 0.0,
      'classId': -1,
      'isNotALeaf': false,
    };
  }

  void _openCamera() async {
    final isGranted = await Permission.camera.request().isGranted;
    if (!mounted) return;

    if (isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Camera...')),
      );
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() { _isProcessing = true; });
        await _processImage(File(image.path));
        setState(() { _isProcessing = false; });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
    }
  }

  void _openGallery() async {
    PermissionStatus status;

    if (Theme.of(context).platform == TargetPlatform.android) {
      status = await Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Gallery...')),
      );
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() { _isProcessing = true; });
        await _processImage(File(image.path));
        setState(() { _isProcessing = false; });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission denied')),
      );
    }
  }

  void _startRealtimeDetection() async {
    final isGranted = await Permission.camera.request().isGranted;
    if (!mounted) return;

    if (isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting Real-time Detection...')),
      );
      final cameras = await availableCameras();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RealTimeCameraScreen(cameras: cameras)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
      backgroundColor: const Color(0xFFF5FFF5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(230),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
            const Column(
              children: [
                Text(
                  "Touch to Identify",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Icon(Icons.arrow_downward, size: 80, color: Colors.black),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  children: [
                    GestureDetector(
                      onTap: _openGallery,
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.green, blurRadius: 6, offset: Offset(2, 2)),
                          ],
                        ),
                        child: const Icon(Icons.photo_library, size: 36, color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("Gallery", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black87)),
                  ],
                ),
                const SizedBox(width: 30),
                GestureDetector(
                  onTap: _openCamera,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8BC34A),
                      shape: BoxShape.circle,
                      boxShadow: [
                            BoxShadow(color: Colors.green.withAlpha(102), blurRadius: 10, offset: const Offset(2, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.photo_camera_rounded, size: 100, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Column(
                  children: [
                    GestureDetector(
                      onTap: _startRealtimeDetection,
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.green, blurRadius: 6, offset: Offset(2, 2)),
                          ],
                        ),
                        child: const Icon(Icons.center_focus_strong, size: 36, color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("Realtime", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black87)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _fetchPlantDetails(int plantId) async {
    // Validate plant ID range
    if (plantId < 0 || plantId >= TOTAL_PLANTS_COUNT) {
      print('❌ Invalid plant ID: $plantId (must be 0-${TOTAL_PLANTS_COUNT - 1})');
      return null;
    }
    
    // Skip "Not a Leaf" class for plant details
    if (plantId == NOT_A_LEAF_CLASS_ID) {
      print('❌ Cannot fetch details for "Not a Leaf" class');
      return null;
    }
    
    final ref = FirebaseDatabase.instance.ref('plants/$plantId');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  Future<List<dynamic>> _fetchUserBookmarks(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/bookmarks');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      return List<dynamic>.from(snapshot.value as List);
    }
    return [];
  }

  Future<void> _toggleBookmark(int plantId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/bookmarks');
    final snapshot = await ref.get();
    List<dynamic> bookmarks = [];
    if (snapshot.exists) {
      bookmarks = List<dynamic>.from(snapshot.value as List);
    }
    if (bookmarks.contains(plantId)) {
      bookmarks.remove(plantId);
    } else {
      bookmarks.add(plantId);
    }
    await ref.set(bookmarks);
  }

  void _showPlantModal(BuildContext context, int plantId) async {
    // Validate plant ID range
    if (plantId < 0 || plantId >= TOTAL_PLANTS_COUNT) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invalid Plant ID'),
          content: Text('Plant ID $plantId is out of range (0-${TOTAL_PLANTS_COUNT - 1}).'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    
    // Handle "Not a Leaf" class
    if (plantId == NOT_A_LEAF_CLASS_ID) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Plant Detected'),
          content: const Text('This is not a plant leaf. Please try with a clear image of a plant leaf.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    final plant = await _fetchPlantDetails(plantId);
    List<dynamic> bookmarks = [];
    if (user != null) {
      bookmarks = await _fetchUserBookmarks(user.uid);
    }
    if (plant == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Plant Not Found'),
          content: const Text('No details found for this plant.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) {
        final isBookmarked = user != null && bookmarks.contains(plantId);
        return AlertDialog(
          title: Text(plant['name'] ?? 'Plant'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plant['scientificName'] != null)
                  Text('Scientific Name: ${plant['scientificName']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                if (plant['family'] != null)
                  Text('Family: ${plant['family']}'),
                if (plant['partsUsed'] != null)
                  Text('Parts Used: ${plant['partsUsed']}'),
                const SizedBox(height: 12),
                if (user == null) ...[
                  const Text('Login to see more details!', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  const Divider(),
                  const Text('Uses: 🔒'),
                  const Text('How to Use: 🔒'),
                  const Text('Caution: 🔒'),
                ] else ...[
                  if (plant['uses'] != null) ...[
                    const Text('Uses:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...List.generate((plant['uses'] as List).length, (i) => Text('- ${plant['uses'][i]}')),
                  ],
                  const SizedBox(height: 8),
                  if (plant['howToUse'] != null) ...[
                    const Text('How to Use:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...List.generate((plant['howToUse'] as List).length, (i) => Text('- ${plant['howToUse'][i]}')),
                  ],
                  const SizedBox(height: 8),
                  if (plant['caution'] != null) ...[
                    const Text('Caution:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...List.generate((plant['caution'] as List).length, (i) => Text('- ${plant['caution'][i]}')),
                  ],
                ],
                if (plant['foundIn'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Found In: ${plant['foundIn']}'),
                ],
                if (plant['wikiUrl'] != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    child: Text('Wikipedia', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    onTap: () {
                      // You can use url_launcher to open the link
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (user != null)
              TextButton(
                onPressed: () async {
                  await _toggleBookmark(plantId);
                  Navigator.pop(context);
                },
                child: Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _saveScanResultToDatabase({
    required int classId,
    required double confidence,
    required String plantName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return null;
    }
    // Validate class ID range
    if (classId < 0 || classId >= ML_CLASSES_COUNT) {
      print('❌ Invalid class ID for scan: $classId (must be 0-${ML_CLASSES_COUNT - 1})');
      return null;
    }
    // Do not save 'Not a Leaf' scans
    if (classId == NOT_A_LEAF_CLASS_ID) {
      print('Not saving scan: Detected class is "Not a Leaf".');
      return null;
    }
    try {
      final scansRef = FirebaseDatabase.instance.ref('scans/${user.uid}').push();
      await scansRef.set({
        'classId': classId,
        'confidence': confidence,
        'plantName': plantName,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('Scan result saved to Realtime Database. Key: ${scansRef.key}');
      return scansRef.key;
    } catch (e) {
      print('Failed to save scan result to database: $e');
      return null;
    }
  }
}

class RealTimeCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const RealTimeCameraScreen({super.key, required this.cameras});

  @override
  State<RealTimeCameraScreen> createState() => _RealTimeCameraScreenState();
}

class _RealTimeCameraScreenState extends State<RealTimeCameraScreen> {
  CameraController? _controller;
  Interpreter? _interpreter;
  bool _isDetecting = false;
  String _detectedPlant = '';
  double _confidence = 0.0;
  List<String> _labels = [];
  String _errorMessage = '';
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _setupCamera();
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final String labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').map((e) => e.trim()).toList();
      if (kDebugMode) {
        print('✅ Labels loaded: ${_labels.length} classes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading labels: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load labels';
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/best.tflite');
      if (kDebugMode) {
        print('✅ Model loaded successfully');
        print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
        print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      }
      setState(() {
        _errorMessage = '';
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading model: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load model';
      });
    }
  }

  Future<void> _setupCamera() async {
    _controller = CameraController(widget.cameras[0], ResolutionPreset.medium);
    try {
    await _controller!.initialize();
    if (mounted) {
      setState(() {});
        _startImageStream();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing camera: $e');
      }
      setState(() {
        _errorMessage = 'Failed to initialize camera';
      });
    }
  }

  void _startImageStream() {
    _controller!.startImageStream((CameraImage image) async {
      _frameCount++;
      if (_frameCount % 10 != 0) return; // Throttle: process every 10th frame
      if (_isDetecting || _interpreter == null || _labels.isEmpty) return;
      _isDetecting = true;
      try {
        // Use robust static image pipeline for real-time
        var input = await _preprocessCameraImageLikeStatic(image);
        // Prepare output buffer
        final outputShape = _interpreter!.getOutputTensor(0).shape;
        var outputBuffer = List.filled(outputShape.reduce((a, b) => a * b), 0.0).reshape(outputShape);
        _interpreter!.run(input, outputBuffer);
        if (outputShape.length == 2 && outputShape[1] == ML_CLASSES_COUNT) {
          // Classifier output
          final scores = outputBuffer[0];
          double bestConf = 0.0;
          int bestClass = -1;
          for (int i = 0; i < scores.length; i++) {
            if (scores[i] > bestConf) {
              bestConf = scores[i];
              bestClass = i;
            }
          }
          if (mounted) {
            setState(() {
              if (bestClass == NOT_A_LEAF_CLASS_ID) {
                _detectedPlant = 'Not a Leaf';
              } else {
                _detectedPlant = _labels[bestClass];
              }
              _confidence = bestConf;
              _errorMessage = '';
            });
          }
        } else {
          // YOLO output
          final best = _postProcessYOLO(outputBuffer);
          if (mounted) {
            setState(() {
              if (best['classId'] == NOT_A_LEAF_CLASS_ID) {
                _detectedPlant = 'Not a Leaf';
              } else {
                _detectedPlant = best['label'] ?? '';
              }
              _confidence = best['confidence'] ?? 0.0;
              _errorMessage = '';
            });
          }
        }
      } catch (e, st) {
        print('❌ Error processing frame: $e\n$st');
        if (mounted) {
          setState(() {
            _errorMessage = 'Error processing frame: $e';
          });
        }
      }
      _isDetecting = false;
    });
  }

  Future<List<List<List<List<double>>>>> _preprocessCameraImageLikeStatic(CameraImage image) async {
    // Convert CameraImage (YUV420) to JPEG, then decode as ui.Image, then resize and convert to tensor
    try {
      // Convert YUV420 to RGB image using image package
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel!;
      final rgbBytes = Uint8List(width * height * 3);
      int byteIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final int index = y * width + x;
          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
          rgbBytes[byteIndex++] = r;
          rgbBytes[byteIndex++] = g;
          rgbBytes[byteIndex++] = b;
        }
      }
      // Encode to JPEG in memory
      final img.Image rgbImg = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBytes.buffer,
        order: img.ChannelOrder.rgb,
      );
      final jpegBytes = Uint8List.fromList(img.encodeJpg(rgbImg));
      // Decode as ui.Image (same as static image pipeline)
      final uiImage = await decodeImageFromList(jpegBytes);
      // Resize and convert to tensor (same as static image pipeline)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        uiImage,
        Rect.fromLTWH(0, 0, uiImage.width.toDouble(), uiImage.height.toDouble()),
        Rect.fromLTWH(0, 0, 640.0, 640.0),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(640, 640);
      final byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = byteData!.buffer.asUint8List();
      var imageMatrix = List.generate(
        640,
        (y) => List.generate(
          640,
          (x) {
            final pixelIndex = (y * 640 + x) * 4;
            return [
              pixels[pixelIndex + 2].toDouble(), // B
              pixels[pixelIndex + 1].toDouble(), // G
              pixels[pixelIndex + 0].toDouble(), // R
            ];
          },
        ),
      );
      return [imageMatrix];
    } catch (e) {
      print('❌ Error in robust camera preprocessing: $e');
      throw Exception('Failed to preprocess camera frame: $e');
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime Detection')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(230),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          if (_detectedPlant.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(51),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detected Plant: $_detectedPlant',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confidence: ${(_confidence * 100).toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _postProcessYOLO(List outputBuffer, {double confThreshold = 0.25}) {
    // outputBuffer shape: [1, 25200, 45] (YOLOv5/YOLOv8)
    // Each detection: [x, y, w, h, obj_conf, class1, class2, ..., classN]
    final detections = outputBuffer[0];
    double bestConf = 0.0;
    int bestClass = -1;
    for (var det in detections) {
      final objConf = det[4];
      if (objConf > confThreshold) {
        double maxClassScore = 0.0;
        int maxClassIdx = -1;
        for (int i = 5; i < det.length; i++) {
          if (det[i] > maxClassScore) {
            maxClassScore = det[i];
            maxClassIdx = i - 5;
          }
        }
        final conf = objConf * maxClassScore;
        if (conf > bestConf) {
          bestConf = conf;
          bestClass = maxClassIdx;
        }
      }
    }
    if (bestClass >= 0 && bestClass < ML_CLASSES_COUNT) {
      String label = _labels[bestClass];
      if (bestClass == NOT_A_LEAF_CLASS_ID) {
        return {
          'label': 'Not a Leaf',
          'confidence': bestConf,
          'classId': bestClass,
          'isNotALeaf': true,
        };
      }
      return {
        'label': label,
        'confidence': bestConf,
        'classId': bestClass,
        'isNotALeaf': false,
      };
    }
    return {
      'label': 'No detection',
      'confidence': 0.0,
      'classId': -1,
      'isNotALeaf': false,
    };
  }
}

class FeedbackDialog extends StatefulWidget {
  final int classId;
  const FeedbackDialog({Key? key, required this.classId}) : super(key: key);

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  int resultRating = 0;
  int uiRating = 0;
  TextEditingController commentController = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.feedback_outlined, color: Colors.green.shade700, size: 28),
                  const SizedBox(width: 10),
                  const Text('Feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Color(0xFF1B5E20))),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Would you like to give feedback on the result?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 18),
              const Text('Did the result match your expectation?', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < resultRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28),
                  onPressed: () => setState(() => resultRating = i + 1),
                )),
              ),
              const SizedBox(height: 10),
              const Text('How was your experience with the result UI?', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(i < uiRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28),
                  onPressed: () => setState(() => uiRating = i + 1),
                )),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Additional feedback',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.green.shade50,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () { Navigator.of(context).pop(); },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    onPressed: submitting || resultRating == 0 || uiRating == 0 ? null : () async {
                      setState(() { submitting = true; });
                      final user = FirebaseAuth.instance.currentUser;
                      final feedbackRef = FirebaseDatabase.instance.ref('feedback').push();
                      await feedbackRef.set({
                        'userId': user?.uid ?? '',
                        'classId': widget.classId,
                        'resultRating': resultRating,
                        'uiRating': uiRating,
                        'comment': commentController.text.trim(),
                        'timestamp': DateTime.now().toIso8601String(),
                      });
                      setState(() { submitting = false; });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
                    },
                    child: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
