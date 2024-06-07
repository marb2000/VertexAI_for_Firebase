import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:vertexai_101/debuging_model_tools.dart';
import 'dart:ui' as ui;
import 'package:vertexai_101/order.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TakeAwayChat extends StatefulWidget {
  const TakeAwayChat({super.key});

  @override
  TakeAwayChatState createState() => TakeAwayChatState();
}

class TakeAwayChatState extends State<TakeAwayChat> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isSendingMessage = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final _userID = 'user123';

  @override
  void initState() {
    super.initState();
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

      _model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash',
        systemInstruction: Content.system(
            '''${SystemInstructionsPrompts.restaurantOrderingPrompt}.
            Thw week starts in Sunday.
            The user ID is $_userID, and today is ${DateTime.now()}'''),
        tools: [
          Tool(functionDeclarations: [
            FunctionDeclarations.getRestaurantTypesVisitedByUserTool,
            FunctionDeclarations.getOrdersFromDateRangeTool,
            FunctionDeclarations.placeOrderTool,
          ]),
        ],
      );

      _chat = _model!.startChat();

      // Send the initial welcome message
      _sendMessage(initialMessage: true);
    } catch (error) {
      _messages.add({
        'sender': 'bot',
        'text': "Error:$error",
        'timestamp': DateTime.now(),
      });
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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.containsKey('text'))
              MarkdownBody(
                data: message['text'],
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
    if (messageText.isEmpty) {
      return; // Don't send empty messages
    }

    setState(() {
      _isSendingMessage = true;
      _messages.add({
        'sender': 'user',
        'text': messageText,
        'timestamp': DateTime.now(),
      });
      _textController.clear();
    });

    List<Part> parts = [TextPart(messageText)];

    try {
      var response = await _chat?.sendMessage(Content.multi(parts));

      // Handle the Function Calls if any
      final functionCalls = response?.functionCalls.toList();
      if (functionCalls!.isNotEmpty) {
        for (var functionCall in functionCalls) {
          ModelDebugingTools.printDebug(
              '${functionCall.name} ${functionCall.args}');

          final result =
              await FunctionDeclarations.handleFunctionCall(functionCall);
          response = await _chat?.sendMessage(
            Content.functionResponse(functionCall.name, result),
          );
        }
      }
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
      _messages.add({
        'sender': 'bot',
        'text': "Error:$error",
        'timestamp': DateTime.now(),
      });
    } finally {
      setState(() => _isSendingMessage = false);
      _textFieldFocusNode
          .requestFocus(); // Ensure focus even if there's an error
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
            title: const Text('Take Away App'),
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
                          'What are you carving out for today?',
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class FunctionDeclarations {
  // Function callins definitions:
  static final getRestaurantTypesVisitedByUserTool = FunctionDeclaration(
    'getRestaurantTypesVisitedByUser',
    'Returns a list of unique restaurant types visited by a user.',
    Schema(
      SchemaType.object,
      properties: {
        'userId': Schema(
          SchemaType.string,
          description: 'The ID of the user.',
        ),
      },
      requiredProperties: [
        'userId',
      ],
    ),
  );

  static final getOrdersFromDateRangeTool = FunctionDeclaration(
    'getOrdersFromDateRange',
    '''Returns a list of orders placed by a user within a specific date range. 
    The orders contains information about what items the user ordered,date, 
    restaurant name, restaurant type, and price.''',
    Schema(
      SchemaType.object,
      properties: {
        'userId': Schema(
          SchemaType.string,
          description: 'The ID of the user.',
        ),
        'startDate': Schema(
          SchemaType.string,
          description: 'The start date of the date range in YYYY-MM-DD format.',
        ),
        'endDate': Schema(
          SchemaType.string,
          description: 'The end date of the date range in YYYY-MM-DD format.',
        ),
      },
      requiredProperties: [
        'userId',
        'startDate',
        'endDate',
      ],
    ),
  );

  static final placeOrderTool = FunctionDeclaration(
    'placeOrder',
    '''Places a new order for a user. Use this function to create a new order 
    and sent it to the restaurant.''',
    Schema(
      SchemaType.object,
      properties: {
        'userId': Schema(
          SchemaType.string,
          description: 'The ID of the user placing the order.',
        ),
        'date': Schema(
          SchemaType.string,
          description: 'The date of the order in YYYY-MM-DD format.',
        ),
        'restaurantName': Schema(
          SchemaType.string,
          description: 'The name of the restaurant.',
        ),
        'restaurantType': Schema(
          SchemaType.string,
          description: 'The type of restaurant.',
        ),
        'orderDetails': Schema(
          SchemaType.string,
          description: 'The details of the order.',
        ),
        'price': Schema(
          SchemaType.number,
          description: 'The total price of the order.',
        ),
        'tipPercentage': Schema(
          SchemaType.number,
          description: 'The tip percentage applied to the order.',
        ),
        'taxRate': Schema(
          SchemaType.number,
          description: 'The tax rate applied to the order.',
        ),
      },
      requiredProperties: [
        'userId',
        'date',
        'restaurantName',
        'restaurantType',
        'orderDetails',
        'price',
      ],
    ),
  );

  static Future<Map<String, Object?>> handleFunctionCall(
      FunctionCall functionCall) async {
    final orderService = OrderService(); // Assuming OrderService is accessible
    switch (functionCall.name) {
      case 'getRestaurantTypesVisitedByUser':
        return {
          'restaurantTypes': orderService.getRestaurantTypesVisitedByUser(
            _extractStringArg(functionCall.args, 'userId'),
          ),
        };
      case 'getOrdersFromDateRange':
        return {
          'orders': orderService
              .getOrdersFromDateRange(
                _extractStringArg(functionCall.args, 'userId'),
                _extractDateArg(functionCall.args, 'startDate'),
                _extractDateArg(functionCall.args, 'endDate'),
              )
              .map((order) => {
                    'userId': order.userId,
                    'date': order.date.toIso8601String(),
                    'restaurantName': order.restaurantName,
                    'restaurantType': order.restaurantType,
                    'orderDetails': order.orderDetails,
                    'price': order.price,
                    'tipPercentage': order.tipPercentage,
                    'taxRate': order.taxRate,
                  })
              .toList(),
        };
      case 'placeOrder':
        orderService.placeOrder(Order(
          userId: _extractStringArg(functionCall.args, 'userId'),
          date: _extractDateArg(functionCall.args, 'date'),
          restaurantName:
              _extractStringArg(functionCall.args, 'restaurantName'),
          restaurantType:
              _extractStringArg(functionCall.args, 'restaurantType'),
          orderDetails: _extractStringArg(functionCall.args, 'orderDetails'),
          price: _extractDoubleArg(functionCall.args, 'price'),
          tipPercentage: _extractDoubleArg(functionCall.args, 'tipPercentage',
              defaultValue: 0.15),
          taxRate: _extractDoubleArg(functionCall.args, 'taxRate',
              defaultValue: 0.08),
        ));
        return {'success': true};
      default:
        throw UnimplementedError(
            'Function not implemented: ${functionCall.name}');
    }
  }

// Helper functions to extract arguments from functionCall.args
  static String _extractStringArg(Map<String, Object?> args, String key,
      {String defaultValue = ''}) {
    return (args[key] as String?) ?? defaultValue;
  }

  static DateTime _extractDateArg(Map<String, Object?> args, String key,
      {DateTime? defaultValue}) {
    final dateString = args[key] as String?;
    return dateString != null
        ? DateTime.tryParse(dateString) ?? defaultValue!
        : defaultValue!;
  }

  static double _extractDoubleArg(Map<String, Object?> args, String key,
      {double defaultValue = 0.0}) {
    return (args[key] as num?)?.toDouble() ?? defaultValue;
  }
}

class SystemInstructionsPrompts {
  static String restaurantOrderingPrompt = """
You are a helpful assistant designed to streamline ordering food at restaurants for the user. Here's how to assist:

1. **Gather Information:**
    * Ask the user for their desired restaurant and order details.
    * If the user is unsure, inquire about their preferences (cuisine, price range, dietary restrictions).

2. **Check Order History:**
    * Review the user's past orders (if available) using the following format:
        * **Day, Date:** Restaurant Name |  Order Summary | Total Cost 
    * Example:  Mon, Jun 3: Sushi Palace – 2 Spicy Tuna Rolls, 1 Miso Soup – \$28.50

3. **Provide Recommendations (Optional):**
    * If the user has previous orders at the chosen restaurant, gently remind them of their past choices.
    * Example: "You previously enjoyed the Spicy Tuna Rolls at Sushi Palace. Would you like to order that again?"
    * If the restaurant is new to the user, offer suggestions based on their stated preferences or popular dishes.

4. **Summarize Order:**
    * Clearly list the items in the user's order, including any modifications.
    * State the estimated total cost (if available).
    * Example:
        * 1 Chicken Caesar Salad (dressing on the side)
        * 1 Pepperoni Pizza (extra cheese)
        * 2 Iced Teas
        * Estimated Total: \$35.00

5. **Confirm Before Placing:**
    * Always ask for the user's confirmation before finalizing the order.
    * Example: "Does this order look correct? If yes, I would order it right away."

**Important Considerations:**

* **Clarity:**  Use clear, concise language, and bullet points for easy reading. 
* **Data Format:**  Follow the specified date format (e.g., Tue, May 25) and week start day (Sunday).
* **Proactive Assistance:**  Offer relevant suggestions and reminders based on past orders or user preferences.
* **Double-Check:** Always prioritize accuracy by confirming the order with the user. 
* **User Control:** The user has the final say in their order. Respect their choices and make adjustments as needed.
""";
}
