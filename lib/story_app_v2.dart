import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:vertexai_101/debuging_model_tools.dart';

class StoryV2App extends StatefulWidget {
  const StoryV2App({super.key});
  @override
  StoryV2AppState createState() => StoryV2AppState();
}

class StoryV2AppState extends State<StoryV2App> {
  String _story = '';
  bool _isLoading = false;
  late final GenerativeModel _model;
  late String _modelName;
  late String _textprompt;
  late FirebaseRemoteConfig _remoteConfig;

  @override
  void initState() {
    super.initState();

    configFirebase().then(onConfigFinished);
  }

  Future<void> configFirebase() async {
    await activateAppCheck();
    await fetchRemoteConfig();
  }

  Future<void> fetchRemoteConfig() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    await _remoteConfig.fetchAndActivate();
    _modelName = _remoteConfig.getString('modelName');
    _textprompt = _remoteConfig.getString('promptText');

    if (_modelName.isEmpty || _textprompt.isEmpty) {
      setState(() => _story =
          '''Error: Create "modelName" and "promptText"  parameters in Remote Config''');
    }
  }

  Future<void> activateAppCheck() async {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  Future<FutureOr> onConfigFinished(void value) async {
    // Remote config should be fetched before callin the model
    if (_modelName.isNotEmpty && _textprompt.isNotEmpty) {
      _model = FirebaseVertexAI.instanceFor(appCheck: FirebaseAppCheck.instance)
          .generativeModel(model: _modelName);
      await _generateStory();
    }
  }

  Future<void> _generateStory() async {
    setState(() => _isLoading = true); // Start loading

    final prompt = [Content.text(_textprompt)];

    try {
      ModelDebugingTools.printPreCountTokens(_model, prompt);
      final response = await _model.generateContent(prompt);
      ModelDebugingTools.printUsage(response);

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
          title: const Text('Generate Story'),
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
