import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class StoryAppStreaming extends StatefulWidget {
  const StoryAppStreaming({super.key});
  @override
  StoryAppStreamingState createState() => StoryAppStreamingState();
}

class StoryAppStreamingState extends State<StoryAppStreaming> {
  String story = '';
  bool isGenerating = false; // Use isGenerating to control button state
  late final GenerativeModel model;

  @override
  void initState() {
    super.initState();
    model = FirebaseVertexAI.instance
        .generativeModel(model: 'gemini-1.5-pro-preview-0409');
    _generateStory();
  }

  Future<void> _generateStory() async {
    setState(() => isGenerating = true);

    final prompt = [
      Content.text('Write a story about a magic backpack in 400 words ')
    ];

    try {
      final responseStream = model.generateContentStream(prompt);
      story = '';

      await for (final chunk in responseStream) {
        setState(() {
          story += chunk.text ?? ''; // Update the UI with each new chunk
        });
      }
    } catch (error) {
      setState(() {
        story = 'An error occurred while generating the story.';
      });
    } finally {
      setState(() => isGenerating = false); // Re-enable the button
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Text(story), // Just display the story
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: isGenerating ? null : _generateStory,
                  child: const Text('Generate Story'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
