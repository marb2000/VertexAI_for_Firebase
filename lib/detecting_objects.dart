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
  File? selectedImage;
  List<DetectedObject> detectedObjects = [];
  bool isLoading = false;
  late final GenerativeModel model;
  int? selectedIndex;
  Size? imageSize;

  @override
  void initState() {
    super.initState();
    model =
        FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');
  }

  Future<void> _processImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
        detectedObjects.clear(); // Clear rectangles for new image
        selectedIndex = null; // Reset selected index
      });

      final image = Image.file(selectedImage!);
      image.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            setState(() {
              imageSize = Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              );
              isLoading = true;
              //print('$imageSize');
              _detectObjects();
            });
          },
        ),
      );
    }
  }

  Future<void> _detectObjects() async {
    if (selectedImage == null || imageSize == null) return;

    final imagePart =
        DataPart('image/jpeg', await selectedImage!.readAsBytes());
    final prompt = Content.multi([
      TextPart(
          '''Detect objects in this image with their boundaries (xmin, ymin, xmax, ymax) and then return just the JSON array with the following format, no other text:
[
  {
    "name": "object_name",
    "bbox": { "xmin": 100, "ymin": 300, "xmax": 500, "ymax": 700 }
  },
  {
    "name": "another_object",
    "bbox": { "xmin": 105, "ymin": 630, "xmax": 910, "ymax": 820 }
  }
]
'''),
      imagePart
    ]);

    try {
      final response = await model.generateContent([prompt]);
      final responseText = response.text!.trim();

      if (responseText.startsWith('[') && responseText.endsWith(']')) {
        final List<dynamic> jsonResponse = jsonDecode(responseText);
        setState(() {
          detectedObjects = jsonResponse
              .map((item) => DetectedObject.fromJson(item))
              .toList();
        });
      } else {
        ModelDebugingTools.printDebug(
            'Unexpected response format: $responseText');
      }
    } catch (error) {
      ModelDebugingTools.printDebug('Error processing image: $error');
    } finally {
      setState(() => isLoading = false);
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
    if (selectedImage == null) {
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
                  selectedImage!,
                  fit: BoxFit.cover,
                ),
                if (isLoading) const Center(child: CircularProgressIndicator()),
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
              itemCount: detectedObjects.length,
              itemBuilder: (context, index) {
                final object = detectedObjects[index];
                return ListTile(
                  title: Text(object.name),
                  onTap: () => setState(() {
                    selectedIndex = index == selectedIndex ? null : index;
                  }),
                  selected: selectedIndex == index,
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
          children: detectedObjects.asMap().entries.map((entry) {
            final int index = entry.key;
            final DetectedObject object = entry.value;

            // Only show bounding box if the item is selected
            if (index == selectedIndex) {
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
