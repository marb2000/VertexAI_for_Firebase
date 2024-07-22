import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:vertexai_101/storage_media_viewer.dart';
import 'package:vertexai_101/chat_gemini_app.dart';
import 'package:vertexai_101/detecting_objects.dart';
import 'package:vertexai_101/posters_quote_app.dart';
import 'package:vertexai_101/story_app.dart';
import 'package:vertexai_101/story_app_v2.dart';
import 'package:vertexai_101/story_app_streaming.dart';
import 'package:vertexai_101/take_away_chat.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final List<Map<String, dynamic>> widgetList = [
    {'name': 'Story App', 'widget': const StoryApp()},
    {'name': 'Story App Streaming', 'widget': const StoryAppStreaming()},
    {'name': 'Posters Quote App', 'widget': const PosterQuoteApp()},
    {'name': 'Chat Gemini App', 'widget': const ChatApp()},
    {'name': 'Storage Media Viewer', 'widget': const StoragePhotoList()},
    {'name': 'Detecting Objects', 'widget': const ObjectDetectionApp()},
    {'name': 'Take Away Chat', 'widget': const TakeAwayChat()},
    {'name': 'Story App V2', 'widget': const StoryV2App()},
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Vertex AI for Firebase Demos'),
        ),
        body: ListView.builder(
          itemCount: widgetList.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(widgetList[index]['name']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => widgetList[index]['widget'],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
