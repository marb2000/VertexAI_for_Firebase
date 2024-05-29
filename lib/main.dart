import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vertexai_101/chat_gemini_app.dart';
import 'package:vertexai_101/detecting_objects.dart';
import 'package:vertexai_101/posters_quote_app.dart';
import 'package:vertexai_101/story_app.dart';
import 'package:vertexai_101/story_app_streaming.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //runApp(const StoryApp());
  //runApp(const StoryAppStreaming());
  //runApp(const PosterQuoteApp());
  //runApp(const ChatApp());
  runApp(const ObjectDetectionApp());
}
