import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class StoryApp extends StatefulWidget {
  const StoryApp({super.key});
  @override
  StoryAppState createState() => StoryAppState();
}

class StoryAppState extends State<StoryApp> {
  String _story = '';
  bool _isLoading = false;
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model =
        FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');
    _generateStory();
  }

  Future<void> _generateStory() async {
    setState(() => _isLoading = true); // Start loading

    final prompt = [
      Content.text('Write a story about a magic backpack in 400 words')
    ];

    try {
      final response = await _model.generateContent(prompt);

      setState(() {
        _story = response.text!;
      });
    } catch (error) {
      setState(() {
        _story = 'An error occurred while generating the story: $error';
      });
    } finally {
      setState(() => _isLoading = false); // Stop loading
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Magic Backpack Story'),
        ),
        body: Column(
          children: [
            Expanded(
              // Make the story area take up available space
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Text(_story),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              // Add padding around the button
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : _generateStory, // Disable when loading
                child: const Text('Regenerate Story'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
