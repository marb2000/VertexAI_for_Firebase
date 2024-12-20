import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/foundation.dart';

class ModelDebugingTools {
  static void printUsage(GenerateContentResponse? response) {
    var totalTokenCount = response!.usageMetadata?.totalTokenCount;
    var promptTokenCount = response.usageMetadata?.promptTokenCount;
    var candidatesTokenCount = response.usageMetadata?.candidatesTokenCount;
    if (kDebugMode) {
      print('''USAGE METADATA:
          -Total Token Count: $totalTokenCount, 
          -Prompt Token Count: $promptTokenCount, 
          -Candidates Token Count: $candidatesTokenCount''');
    }
  }

  static Future<void> printPreCountTokens(
      GenerativeModel model, List<Content> prompt) async {
    final tokenCount = await model.countTokens(prompt);

    if (kDebugMode) {
      print('''TOKEN COUNT:
          -Token count: ${tokenCount.totalTokens}, 
          -Billable characters: ${tokenCount.totalBillableCharacters}''');
    }
  }

  static void printDebug(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  static Future<void> setDebugSession() async {
    // This is only for demo proposals.
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    FirebaseVertexAI.instanceFor(appCheck: FirebaseAppCheck.instance)
        .generativeModel(model: 'gemini-1.5-flash');
  }
}
