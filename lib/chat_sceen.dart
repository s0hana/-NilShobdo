import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';
import 'chat_history_screen.dart';
import 'theme_manager.dart'; // Theme manager import করুন

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? chatId;

  const ChatScreen({super.key, required this.userData, this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> messages = [];
  bool isLoading = false;
  String currentChatId = '';
  List<Map<String, dynamic>> conversationHistory = [];
  bool isLocalUpdate = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // User information that will be extracted from conversations
  Map<String, dynamic> userPreferences = {};

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    
    // Generate or use existing chat ID
    currentChatId = widget.chatId ?? _db.push().key!;
    
    // Load existing messages if it's an existing chat
    if (widget.chatId != null) {
      _loadExistingMessages();
    } else {
      // For new chats, load user preferences from database
      _loadUserPreferences();
    }
    
    // Set up real-time listener for this chat
    _setupChatListener();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  void _setupChatListener() {
    _db.child('chats/$currentChatId/messages').onChildAdded.listen((event) {
      if (isLocalUpdate) return; // Skip if we're doing a local update
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      setState(() {
        messages.add(_ChatMessage(
          text: data['message'],
          isUser: data['isUser'],
        ));
        
        // Add to conversation history for context
        conversationHistory.add({
          'role': data['isUser'] ? 'user' : 'model',
          'parts': [{'text': data['message']}]
        });
      });
    });
  }

  // Load user preferences from Firebase
  Future<void> _loadUserPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _db.child('userPreferences/${user.uid}').once();
      if (snapshot.snapshot.value != null) {
        setState(() {
          userPreferences = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        });
      }
    } catch (e) {
      print("Error loading user preferences: $e");
    }
  }

  // Save user preferences to Firebase
  Future<void> _saveUserPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.child('userPreferences/${user.uid}').set(userPreferences);
    } catch (e) {
      print("Error saving user preferences: $e");
    }
  }

  // Extract user information from messages and save to preferences
  void _extractUserInfo(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Extract name
    if (lowerMessage.contains("my name is")) {
      
      // Simple extraction logic - can be improved
      final parts = message.split(RegExp(r"my name is"));
      if (parts.length > 1) {
        final name = parts[1].trim().split(RegExp(r"\s|\.|!|\?|,"))[0];
        if (name.isNotEmpty && name.length > 2) {
          userPreferences['name'] = name;
          _saveUserPreferences();
        }
      }
    }
    
    // Extract favorite things
    final favoritePatterns = {
      'favoriteFood': RegExp(r"favorite (food|dish|cuisine) is (\w+)", caseSensitive: false),
      'favoriteColor': RegExp(r"favorite color is (\w+)", caseSensitive: false),
      'favoriteFlower': RegExp(r"favorite flower is (\w+)", caseSensitive: false),
      'favoriteHobby': RegExp(r"favorite (hobby|activity) is (\w+)", caseSensitive: false),
      'favoriteMovie': RegExp(r"favorite movie is (\w+)", caseSensitive: false),
    };
    
    favoritePatterns.forEach((key, pattern) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        userPreferences[key] = match.group(match.groupCount) ?? match.group(1);
        _saveUserPreferences();
      }
    });
  }

  Future<void> _loadExistingMessages() async {
    try {
      final snapshot = await _db.child('chats/$currentChatId/messages').once();
      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          messages.clear();
          conversationHistory.clear();
          
          data.forEach((key, value) {
            messages.add(_ChatMessage(
              text: value['message'],
              isUser: value['isUser'],
            ));
            
            // Add to conversation history for context
            conversationHistory.add({
              'role': value['isUser'] ? 'user' : 'model',
              'parts': [{'text': value['message']}]
            });

            // Extract user info from past messages
            if (value['isUser']) {
              _extractUserInfo(value['message']);
            }
          });
        });
      }
      
      // Load user preferences after loading messages
      _loadUserPreferences();
    } catch (e) {
      print("Error loading messages: $e");
    }
  }

  // Save chat to Realtime Database
  Future<void> saveChat(String message, bool isUser) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatData = {
      'message': message,
      'isUser': isUser,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      // Save message to this specific chat
      await _db.child('chats/$currentChatId/messages').push().set(chatData);
      
      // Also save chat metadata if this is a new chat
      if (widget.chatId == null) {
        await _db.child('userChats/${user.uid}/$currentChatId').set({
          'lastMessage': message,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Update last message and timestamp for existing chat
        await _db.child('userChats/${user.uid}/$currentChatId').update({
          'lastMessage': message,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Extract user information from the message if it's from the user
      if (isUser) {
        _extractUserInfo(message);
      }
    } catch (e) {
      print("Error saving chat: $e");
    }
  }

  // Check if the message is asking about user information
  bool _isAskingAboutUser(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains("what is my") ||
           lowerMessage.contains("do you know my") ||
           lowerMessage.contains("remember my") ||
           lowerMessage.contains("my favorite") ||
           lowerMessage.contains("what's my") ||
           lowerMessage.contains("who am i");
  }

  // Generate response based on stored user preferences
  String _getUserInfoResponse(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains("name")) {
      return userPreferences.containsKey('name') 
          ? "Your name is ${userPreferences['name']}." 
          : "You haven't told me your name yet.";
    }
    else if (lowerMessage.contains("favorite food") || lowerMessage.contains("favorite dish")) {
      return userPreferences.containsKey('favoriteFood') 
          ? "Your favorite food is ${userPreferences['favoriteFood']}." 
          : "You haven't told me about your favorite food yet.";
    }
    else if (lowerMessage.contains("favorite color")) {
      return userPreferences.containsKey('favoriteColor') 
          ? "Your favorite color is ${userPreferences['favoriteColor']}." 
          : "You haven't told me about your favorite color yet.";
    }
    else if (lowerMessage.contains("favorite flower")) {
      return userPreferences.containsKey('favoriteFlower') 
          ? "Your favorite flower is ${userPreferences['favoriteFlower']}." 
          : "You haven't told me about your favorite flower yet.";
    }
    else if (lowerMessage.contains("favorite hobby") || lowerMessage.contains("favorite activity")) {
      return userPreferences.containsKey('favoriteHobby') 
          ? "Your favorite hobby is ${userPreferences['favoriteHobby']}." 
          : "You haven't told me about your favorite hobby yet.";
    }
    else if (lowerMessage.contains("favorite movie")) {
      return userPreferences.containsKey('favoriteMovie') 
          ? "Your favorite movie is ${userPreferences['favoriteMovie']}." 
          : "You haven't told me about your favorite movie yet.";
    }
    
    return "I remember some things about you, but I'm not sure what specific information you're asking about.";
  }

  // Gemini API call - Updated to include user preferences
  Future<String> getBotResponse(String userMessage) async {
    // Check if this is a question about user information
    if (_isAskingAboutUser(userMessage)) {
      return _getUserInfoResponse(userMessage);
    }
    
    const apiKey = "AIzaSyDLOTeHgytOoKGpxiMED0_BU4NvE7Cb3gA";
    
    // Use the correct Gemini API endpoint
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey");

    // Add the new user message to conversation history
    conversationHistory.add({
      'role': 'user',
      'parts': [{'text': userMessage}]
    });

    // Create user context based on stored preferences
    String userContext = "User information: ";
    if (userPreferences.isEmpty) {
      userContext += "I don't know much about the user yet.";
    } else {
      userPreferences.forEach((key, value) {
        userContext += "$key: $value. ";
      });
    }

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [{"text": "You are Ikri, a mental health support assistant. You mainly talk to Bangladeshi people. By default, speak in English. Only switch to another language (e.g., Bangla) if the user requests it, and continue in that language until the user asks to switch back. $userContext Keep responses empathetic and supportive, add relevant emojis to make your messages warm and friendly.You must never provide a diagnosis or treatment plan; if a user expresses intent to harm themselves or others, you must immediately provide the relevant crisis hotline (of Bangladesh) and strongly encourage them to contact professional help."}]
            },
            ...conversationHistory
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.8,
            "maxOutputTokens": 1024,
          },
          "safetySettings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("API Response: ${data.toString().substring(0, 200)}..."); // Log first 200 chars
        
        // Parse the response correctly
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final botText = data['candidates'][0]['content']['parts'][0]['text'];
          
          // Add the bot response to conversation history
          conversationHistory.add({
            'role': 'model',
            'parts': [{'text': botText}]
          });
          
          return botText ?? "Hello! I'm Ikri. How are you feeling today?";
        } else {
          return "Hello! I'm Ikri. How can I support you today?";
        }
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        // Fallback to simple responses if API fails
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      print("API Exception: $e");
      // Fallback to simple responses if API fails
      return _getFallbackResponse(userMessage);
    }
  }

  // Fallback responses in case API fails
  String _getFallbackResponse(String userMessage) {
    userMessage = userMessage.toLowerCase();
    
    if (userMessage.contains('hello') || userMessage.contains('hi') || userMessage.contains('hey')) {
      return "Hello! I'm Ikri. How are you feeling today?";
    } else if (userMessage.contains('sad') || userMessage.contains('upset') || userMessage.contains('unhappy')) {
      return "I'm sorry you're feeling this way. It's okay to feel sad sometimes. Would you like to talk about what's bothering you?";
    } else if (userMessage.contains('happy') || userMessage.contains('good') || userMessage.contains('great')) {
      return "That's wonderful to hear! I'm glad you're feeling good today. 😊";
    } else if (userMessage.contains('anxious') || userMessage.contains('worry') || userMessage.contains('nervous')) {
      return "I understand feeling anxious can be difficult. Remember to take deep breaths. Would practicing some breathing exercises help?";
    } else if (userMessage.contains('angry') || userMessage.contains('mad') || userMessage.contains('frustrated')) {
      return "It sounds like you're feeling frustrated. Sometimes taking a moment to pause and breathe can help. Would you like to try that?";
    } else if (userMessage.contains('tired') || userMessage.contains('exhausted') || userMessage.contains('sleep')) {
      return "It's important to listen to your body when you're tired. Rest is essential for our mental health. Have you been getting enough sleep?";
    } else if (userMessage.contains('thank') || userMessage.contains('thanks')) {
      return "You're welcome! I'm always here to listen and support you. 💙";
    } else if (userMessage.contains('help') || userMessage.contains('support')) {
      return "I'm here to support you emotionally. You can share anything that's on your mind, and I'll listen without judgment.";
    } else if(userMessage.contains('suicide')|| userMessage.contains('will die')|| userMessage.contains('die')) {
      return "Please, reach out immediately to someone trained to help in moments like this. 😔\n\nKaan Pete Roi (Bangladesh): +880 01711 616 000\nNational Mental Health Helpline: 333";
    }
    
    // Default response
    return "Thank you for sharing. I'm here to listen and support you. How has your day been?";
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(text: text, isUser: true));
      isLoading = true;
    });
    _controller.clear();

    isLocalUpdate = true;
    try {
      // Save user's message
      await saveChat(text, true);

      // Get bot response
      final botResponse = await getBotResponse(text);

      setState(() {
        messages.add(_ChatMessage(text: botResponse, isUser: false));
        isLoading = false;
      });

      // Save bot's response
      await saveChat(botResponse, false);
    } catch (e) {
      setState(() {
        isLoading = false;
        messages.add(_ChatMessage(
          text: "Sorry, I encountered an error. Please try again.", 
          isUser: false
        ));
      });
    }
    isLocalUpdate = false;
  }

  void _startNewChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userData: widget.userData,
          chatId: null, // This will create a new chat
        ),
      ),
    );
  }

  void _viewChatHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatHistoryScreen(userData: widget.userData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat with Ikri"),
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        elevation: 2,
        shadowColor: _currentTheme.primary.withOpacity(0.5),
        actions: [
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.pushNamed(context, '/set');
            },
          ),
          // Menu with icons
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: _currentTheme.containerColor,
            elevation: 6,
            itemBuilder: (context) => [
              // Home icon in menu
              PopupMenuItem(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home, color: _currentTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Home'),
                  ],
                ),
              ),
              // Exercise icon in menu
              PopupMenuItem(
                value: 'exercise',
                child: Row(
                  children: [
                    Icon(Icons.fitness_center, color: _currentTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Exercises'),
                  ],
                ),
              ),
              // Profile icon in menu
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle, color: _currentTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Profile'),
                  ],
                ),
              ),
              // Professionals icon in menu
              PopupMenuItem(
                value: 'professionals',
                child: Row(
                  children: [
                    Icon(Icons.people, color: _currentTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Professionals'),
                  ],
                ),
              ),
              // Divider
              const PopupMenuDivider(),
              // New Chat icon in menu
              PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: _currentTheme.primary),
                    const SizedBox(width: 8),
                    const Text('New Chat'),
                  ],
                ),
              ),
              // Chat History icon in menu
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: _currentTheme.primary),
                    const SizedBox(width: 8),
                    const Text('Chat History'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'home') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(userData: widget.userData),
                  ),
                );
              } else if (value == 'exercise') {
                Navigator.pushNamed(context, '/exercise');
              } else if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'professionals') {
                Navigator.pushNamed(context, '/pro');
              } else if (value == 'new_chat') {
                _startNewChat();
              } else if (value == 'history') {
                _viewChatHistory();
              }
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_currentTheme.gradientStart, _currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // 🔹 Messages
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? _currentTheme.primary
                            : _currentTheme.containerColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _currentTheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: message.isUser
                              ? Colors.black
                              : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: _currentTheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ikri is typing...',
                      style: TextStyle(
                        color: _currentTheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // 🔹 Input Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _currentTheme.containerColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Type your message here...",
                        hintStyle: TextStyle(color: Colors.black54),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      style: const TextStyle(color: Colors.black87),
                      onSubmitted: sendMessage,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: _currentTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black),
                      onPressed: () => sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}