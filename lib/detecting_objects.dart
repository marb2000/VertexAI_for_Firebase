import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:vertexai_101/debuging_model_tools.dart';

class DetectedObject {
  final String name;
  final int xmin;
  final int ymin;
  final int xmax;
  final int ymax;

  DetectedObject({
    required this.name,
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      name: json['name'],
      xmin: json['bbox']['xmin'],
      ymin: json['bbox']['ymin'],
      xmax: json['bbox']['xmax'],
      ymax: json['bbox']['ymax'],
    );
  }
}

class ObjectDetectionApp extends StatefulWidget {
  const ObjectDetectionApp({super.key});

  @override
  ObjectDetectionAppState createState() => ObjectDetectionAppState();
}

class ObjectDetectionAppState extends State<ObjectDetectionApp> {
  File? _selectedImage;
  List<DetectedObject> _detectedObjects = [];
  bool _isLoading = false;
  late final GenerativeModel _model;
  int? _selectedIndex;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    configDebug().then(onConfigFinished);
  }

  Future<void> configDebug() async {
    await ModelDebugingTools.setDebugSession();
  }

  Future<void> onConfigFinished(void value) async {
    _model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-1.5-flash',
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  Future<void> _processImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _detectedObjects.clear(); // Clear rectangles for new image
        _selectedIndex = null; // Reset selected index
      });

      final image = Image.file(_selectedImage!);
      image.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            setState(() {
              _imageSize = Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              );
              _isLoading = true;
              //print('$imageSize');
              _detectObjects();
            });
          },
        ),
      );
    }
  }

  Future<void> _detectObjects() async {
    if (_selectedImage == null || _imageSize == null) return;

    final imagePart =
        DataPart('image/jpeg', await _selectedImage!.readAsBytes());
    final prompt = Content.multi([
      TextPart('''Identify and label 5 or less objects present in this image and
        provide their bounding boxes (xmin, ymin, xmax, ymax). 
        Return just a JSON array that follows the next pattern:
              [
                {
                  "name": "table",
                  "bbox": { "xmin": 100, "ymin": 300, "xmax": 500, "ymax": 700 }
                },
                {
                  "name": "lamp",
                  "bbox": { "xmin": 105, "ymin": 630, "xmax": 910, "ymax": 820 }
                }
              ]
          '''),
      imagePart
    ]);

    try {
      final response = await _model.generateContent([prompt]);
      if (response.text!.isNotEmpty) {
        final responseText = response.text!.trim();

        final List<dynamic> jsonResponse = jsonDecode(responseText);
        setState(() {
          _detectedObjects = jsonResponse
              .map((item) => DetectedObject.fromJson(item))
              .toList();
        });
      }
    } catch (error) {
      ModelDebugingTools.printDebug('Error processing image: $error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Object Detection'),
          actions: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _processImage,
            ),
          ],
        ),
        body: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_selectedImage == null) {
      return const Center(child: Text('No image selected'));
    } else {
      return Column(
        children: [
          // Display the image with bounding box overlay
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                // Bounding Box Overlay
                Positioned.fill(
                  child: _buildBoundingBoxOverlay(),
                ),
              ],
            ),
          ),
          // Display the object list
          Expanded(
            child: ListView.builder(
              itemCount: _detectedObjects.length,
              itemBuilder: (context, index) {
                final object = _detectedObjects[index];
                return ListTile(
                  title: Text(object.name),
                  onTap: () => setState(() {
                    _selectedIndex = index == _selectedIndex ? null : index;
                  }),
                  selected: _selectedIndex == index,
                );
              },
            ),
          ),
        ],
      );
    }
  }

  // Bounding Box Overlay Widget (Simplified - No MouseRegion)
  Widget _buildBoundingBoxOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: _detectedObjects.asMap().entries.map((entry) {
            final int index = entry.key;
            final DetectedObject object = entry.value;

            // Only show bounding box if the item is selected
            if (index == _selectedIndex) {
              return _buildBoundingBox(object, constraints.biggest);
            } else {
              return const SizedBox
                  .shrink(); // Return an empty widget if not selected
            }
          }).toList(),
        );
      },
    );
  }

  // Individual Bounding Box Widget (Simplified - No hover effects)
  Widget _buildBoundingBox(DetectedObject object, Size imageSize) {
    return Positioned(
      left: object.xmin.toDouble() / 1000 * imageSize.width,
      top: object.ymin.toDouble() / 1000 * imageSize.height,
      width: (object.xmax - object.xmin).toDouble() / 1000 * imageSize.width,
      height: (object.ymax - object.ymin).toDouble() / 1000 * imageSize.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.blue,
            width: 2.0,
          ),
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
    );
  }
}
