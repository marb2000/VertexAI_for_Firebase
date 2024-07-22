import 'dart:io'; // For File handling on mobile
import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vertexai_101/debuging_model_tools.dart';

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
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    configDebug().then(onConfigFinished);
  }

  Future<void> configDebug() async {
    await ModelDebugingTools.setDebugSession();
  }

  Future<void> onConfigFinished(void value) async {
    _model =
        FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');
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
      ModelDebugingTools.printDebug('Error picking image: $error');
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
      final response = await _model.generateContent([prompt]);
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
