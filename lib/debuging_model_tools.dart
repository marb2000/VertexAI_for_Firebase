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
}
