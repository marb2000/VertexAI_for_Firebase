# Vertex AI for Firebase | Flutter Sample App

This Flutter app leverages [Vertex AI for Firebase Dart SDK](https://firebase.google.com/docs/vertex-ai) to generate creative stories about a magic backpack. It provides a user interface where you can read the generated story and request a new one by tapping a button.

__Key Learning Points:__

- Integrating AI into Apps: You'll see how to use Vertex AI for Firebase to incorporate generative AI capabilities (using the Gemini API) into your Flutter applications.
- Asynchronous Operations: The app uses async and await to handle the story generation process, which can take time. This ensures a smooth user experience without freezing the UI.
- State Management: The code demonstrates how to manage the widget state so the UI can update in response to the AI's output.
- Error Handling: The try...catch block handles potential errors during story generation.
