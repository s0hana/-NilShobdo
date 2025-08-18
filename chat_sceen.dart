import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> messages = [];
  bool isLoading = false;

  void sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(text: text, isUser: true));
      isLoading = true;
    });
    _controller.clear();

    // Simulate AI thinking delay
    await Future.delayed(const Duration(seconds: 1));

    // Simple keyword-based AI response
    final lowerText = text.toLowerCase();
    String botResponse;

    if (lowerText.contains("hi") || lowerText.contains("hello")) {
      botResponse = "Hey there! How can I help you?";
    } else if (lowerText.contains("help")) {
      botResponse = "Sure, tell me what you need help with.";
    }
    else if(lowerText.contains("my name is"))
    {
      String name = text.substring(text.toLowerCase().indexOf("my name is")+10).trim();
      if(name.isEmpty)
      {
        botResponse = "I didn't catch your name, could you repeat?";
      }
      else
      {
        botResponse = "Nice to meet you, $name!";
      }
    }
     else {
      botResponse = "Sorry, I am a prototype version. I can't fully understand everything yet.";
    }

    setState(() {
      messages.add(_ChatMessage(text: botResponse, isUser: false));
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFFBAE0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔹 Top Navigation Bar (same as HomeScreen style)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.blue, width: 2),
                  ),
                  color: Color(0xFF2196F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/set');
                      },
                    ),
                    const Text("Chat Screen",
                    style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
                    Icon(Icons.more_vert, size: 28, color: Colors.black),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Messages
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                              ? const Color(0xFF2196F3)
                              : Colors.white70,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
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
                                ? Colors.white
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),

              // 🔹 Input Box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText:
                              "Share your thoughts, worries, or just say hi!",
                          border: InputBorder.none,
                        ),
                        onSubmitted: sendMessage,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: () {
                        sendMessage(_controller.text);
                      },
                    ),
                  ],
                ),
              ),

              // 🔹 Bottom Navigation Bar (same as HomeScreen)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.blue, width: 2),
                  ),
                  color: Color(0xFF2196F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.fitness_center,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/exercise');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/pro');
                      },
                      child: Image.asset(
                        'assets/icons/a.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
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

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
