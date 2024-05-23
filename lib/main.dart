import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String story = '';
  bool isLoading = false;
  late final GenerativeModel model;

  @override
  void initState() {
    super.initState();
    model = FirebaseVertexAI.instance
        .generativeModel(model: 'gemini-1.5-pro-preview-0409');
    _generateStory();
  }

  Future<void> _generateStory() async {
    setState(() => isLoading = true); // Start loading

    final prompt = [
      Content.text('Write a story about a magic backpack in 400 words ')
    ];

    try {
      final response = await model.generateContent(prompt);
      setState(() {
        story = response.text!;
      });
    } catch (error) {
      setState(() {
        story = 'An error occurred while generating the story.';
      });
    } finally {
      setState(() => isLoading = false); // Stop loading
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
                      if (isLoading)
                        const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Text(story),
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
                    isLoading ? null : _generateStory, // Disable when loading
                child: const Text('Regenerate Story'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
