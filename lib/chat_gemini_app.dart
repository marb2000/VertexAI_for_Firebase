import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import 'package:vertexai_101/debuging_model_tools.dart';

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  ChatAppState createState() => ChatAppState();
}

class ChatAppState extends State<ChatApp> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isSendingMessage = false;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    configDebug().then(onConfigFinished);
  }

  Future<void> configDebug() async {
    await ModelDebugingTools.setDebugSession();
  }

  Future<void> onConfigFinished(void value) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFirebaseAndVertexAI();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeFirebaseAndVertexAI() async {
    try {
      await Firebase.initializeApp();
      _model =
          FirebaseVertexAI.instance.generativeModel(model: 'gemini-1.5-flash');
      _chat = _model!.startChat();

      // Send the initial welcome message
      _sendMessage(initialMessage: true);
    } catch (error) {
      if (kDebugMode) {
        print('Error initializing Firebase/VertexAI: $error');
      }
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    return Align(
      // Add Align widget
      alignment: message['sender'] == 'user'
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: const BoxConstraints(
            maxWidth: 250), // Adjust the maximum width as needed
        decoration: BoxDecoration(
          color:
              message['sender'] == 'user' ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Add this line
          //crossAxisAlignment: CrossAxisAlignment.start, // Remove this line
          children: [
            if (message.containsKey('text'))
              Text(
                message['text'],
              ),
            if (message.containsKey('image')) // Check if image exists
              ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: 250), // Adjust the maximum width for images too
                child: Image.file(File(message['image'])),
              ),
            if (message['timestamp'] != null)
              Text(
                DateFormat('HH:mm').format(message['timestamp']),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({bool initialMessage = false}) async {
    if (initialMessage) {
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': "Hi! How can I help you?",
          'timestamp': DateTime.now(),
        });
      });
      return;
    }

    String messageText = _textController.text.trim();
    if (messageText.isEmpty && _selectedImage == null) {
      return; // Don't send empty messages
    }

    setState(() {
      _isSendingMessage = true;
      _messages.add({
        'sender': 'user',
        'text': messageText,
        'timestamp': DateTime.now(),
        if (_selectedImage != null) 'image': _selectedImage!.path,
      });
      _textController.clear();
    });

    List<Part> parts = [TextPart(messageText)];

    if (_selectedImage != null) {
      Uint8List imageBytes = await _selectedImage!.readAsBytes();
      parts.add(DataPart('image/jpeg', imageBytes));
      _selectedImage = null; // Clear the image after sending
    }

    try {
      final response = await _chat?.sendMessage(Content.multi(parts));

      ModelDebugingTools.printUsage(response);

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': response?.text ?? '',
          'timestamp': DateTime.now(),
        });
        _textFieldFocusNode.requestFocus(); // Refocus the text field
      });

      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom()); // Scroll after build
    } catch (error) {
      ModelDebugingTools.printDebug('Error sending message: $error');
    } finally {
      setState(() => _isSendingMessage = false);
      _textFieldFocusNode
          .requestFocus(); // Ensure focus even if there's an error
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _chat = _model?.startChat();
      _sendMessage(initialMessage: true);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Chat App'),
            actions: [
              IconButton(
                onPressed: _resetConversation,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Ask me anything!',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _buildMessage(_messages[index]),
                      ),
              ),
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.file(_selectedImage!),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                    ),
                    Expanded(
                      child: TextField(
                        focusNode: _textFieldFocusNode,
                        controller: _textController,
                        decoration:
                            const InputDecoration(hintText: 'Type a message'),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSendingMessage ? null : _sendMessage,
                      icon: _isSendingMessage
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
