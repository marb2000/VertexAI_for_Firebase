import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:vertexai_101/debuging_model_tools.dart';

class StoryAppStreaming extends StatefulWidget {
  const StoryAppStreaming({super.key});
  @override
  StoryAppStreamingState createState() => StoryAppStreamingState();
}

class StoryAppStreamingState extends State<StoryAppStreaming> {
  String _story = '';
  bool _isGenerating = false;
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
    _generateStory();
  }

  Future<void> _generateStory() async {
    setState(() => _isGenerating = true);

    final prompt = [
      Content.text('Write a story about a magic backpack in 400 words ')
    ];

    try {
      final responseStream = _model.generateContentStream(prompt);
      _story = '';

      await for (final chunk in responseStream) {
        setState(() {
          _story += chunk.text ?? ''; // Update the UI with each new chunk
        });
      }
    } catch (error) {
      setState(() {
        _story = 'An error occurred while generating the story.';
      });
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Streaming Magic Backpack Story'),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Text(_story), // Just display the story
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateStory,
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
