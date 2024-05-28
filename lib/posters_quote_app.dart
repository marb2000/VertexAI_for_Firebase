import 'dart:io'; // For File handling on mobile
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart'; // To check the platform
import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:image_picker/image_picker.dart';

// Remember to give permissions to the iOS app to access the photo library in the info.plist file:
// <key>NSPhotoLibraryUsageDescription</key>
// <string>This app requires access to your photo libraryes.</string>

// Also, to the Android app:
// <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

class PosterQuoteApp extends StatefulWidget {
  const PosterQuoteApp({super.key});
  @override
  PosterQuoteAppState createState() => PosterQuoteAppState();
}

class PosterQuoteAppState extends State<PosterQuoteApp> {
  File? _image;
  String quote = '';
  bool isLoading = false;
  late final GenerativeModel model;

  @override
  void initState() {
    super.initState();
    model = FirebaseVertexAI.instance
        .generativeModel(model: 'gemini-1.5-flash'); // Model for images
  }

  Future<void> _getImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        _generateQuote();
      }
    } catch (error) {
      print('Error picking image: $error');
      // Show an error message to the user
    }
  }

  Future<void> _generateQuote() async {
    if (_image == null) return;

    setState(() => isLoading = true);

    final imagePart = DataPart('image/jpeg', await _image!.readAsBytes());
    final prompt = Content.multi([
      TextPart("Generate a creative and inspiring quote based on this image."),
      imagePart
    ]);

    try {
      final response = await model.generateContent([prompt]);
      setState(() {
        quote = response.text!;
      });
    } catch (error) {
      setState(() {
        quote = 'An error occurred while generating the quote.';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Inspirational Quotes'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: Image.file(_image!),
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _getImage,
                  child: const Text('Choose Image'),
                ),
                const SizedBox(height: 20),
                if (isLoading) const CircularProgressIndicator(),
                if (quote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      quote,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                if (quote.isNotEmpty)
                  ElevatedButton(
                    onPressed: isLoading ? null : _generateQuote,
                    child: const Text('Regenerate Quote'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
