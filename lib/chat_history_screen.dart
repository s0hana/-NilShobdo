import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_sceen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChatHistoryScreen({super.key, required this.userData});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> chats = [];
  bool isLoading = true;
  Map<String, dynamic> userAnalysis = {};
  bool showAnalysis = false;
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _loadUserAnalysis();
  }

  // Load user analysis from Firestore
  Future<void> _loadUserAnalysis() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('userAnalysis').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userAnalysis = doc.data() ?? {};
          showAnalysis = userAnalysis.isNotEmpty;
        });
      }
    } catch (e) {
      print("Error loading user analysis: $e");
    }
  }

  // Show error dialog to user
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Analyze chats to extract user preferences, mental conditions, etc.
  Future<void> _analyzeChats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      // Get all chat messages
      List<String> allMessages = [];
      for (var chat in chats) {
        final snapshot = await _db.child('chats/${chat['id']}/messages').once();
        if (snapshot.snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
          data.forEach((key, value) {
            if (value['isUser'] == true) {
              allMessages.add(value['message']);
            }
          });
        }
      }

      if (allMessages.isEmpty) {
        setState(() {
          isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No user messages found to analyze"),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Combine all user messages for analysis (limit to avoid token limits)
      String combinedMessages = allMessages.join(" ");
      if (combinedMessages.length > 8000) {
        combinedMessages = combinedMessages.substring(0, 8000);
      }

      // Call Gemini API for analysis
      const apiKey = "AIzaSyA4D0lDLMAQIxkQGm2SDZDBnflcI5VqENQ";
      final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text": "Analyze the following chat messages from a user and provide a comprehensive analysis in JSON format. "
                      "Include these categories: "
                      "1. preferences (food, colors, hobbies, movies, etc.), "
                      "2. mental_condition (mood patterns, stress indicators, anxiety triggers, etc.), "
                      "3. interests (topics they frequently discuss), "
                      "4. dislikes (things they express negative feelings about), "
                      "5. summary (overall analysis summary). "
                      "Format the response as valid JSON with these exact keys. "
                      "Here are the messages: $combinedMessages"
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.3,
            "topP": 0.8,
            "maxOutputTokens": 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          
          final analysisText = data['candidates'][0]['content']['parts'][0]['text'];
          
          // Extract JSON from the response
          try {
            // Try to find JSON in the response
            final jsonStart = analysisText.indexOf('{');
            final jsonEnd = analysisText.lastIndexOf('}');
            if (jsonStart >= 0 && jsonEnd > jsonStart) {
              final jsonString = analysisText.substring(jsonStart, jsonEnd + 1);
              final analysisData = jsonDecode(jsonString);
              
              // Add timestamp and chat count
              analysisData['lastAnalyzed'] = DateTime.now().millisecondsSinceEpoch;
              analysisData['chatsAnalyzed'] = chats.length;
              
              // Save to Firestore
              await _firestore.collection('userAnalysis').doc(user.uid).set(
                analysisData,
                SetOptions(merge: true),
              );
              
              // Save to Realtime Database
              await _db.child('userAnalysis/${user.uid}').set(analysisData);
              
              setState(() {
                userAnalysis = analysisData;
                showAnalysis = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Chat analysis completed successfully"),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              throw Exception("The AI response didn't contain valid analysis data. Please try again.");
            }
          } catch (e) {
            print("Error parsing analysis JSON: $e");
            _showErrorDialog(
              "Analysis Error", 
              "Could not process the analysis results. The AI might have returned an unexpected format. Please try again."
            );
          }
        } else {
          throw Exception("The AI service returned an unexpected response format.");
        }
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        if (response.statusCode == 400) {
          throw Exception("Invalid request to the AI service. This might be due to an API key issue or incorrect request format.");
        } else if (response.statusCode == 403) {
          throw Exception("Access denied. Please check if your API key is valid and has proper permissions.");
        } else if (response.statusCode == 429) {
          throw Exception("Too many requests. Please wait a while before trying again.");
        } else if (response.statusCode >= 500) {
          throw Exception("The AI service is currently unavailable. Please try again later.");
        } else {
          throw Exception("API request failed with status ${response.statusCode}");
        }
      }
    } catch (e) {
      print("Error analyzing chats: $e");
      _showErrorDialog("Analysis Failed", e.toString());
    }

    setState(() {
      isAnalyzing = false;
    });
  }

  // Check if we should analyze chats (every 5 chats)
  bool _shouldAnalyzeChats() {
    if (chats.isEmpty) return false;
    
    final lastAnalyzed = userAnalysis['lastAnalyzed'] ?? 0;
    final chatsAnalyzed = userAnalysis['chatsAnalyzed'] ?? 0;
    
    // Analyze if we have 5 more chats since last analysis
    return chats.length >= chatsAnalyzed + 5;
  }

  Future<void> _loadChatHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _db.child('userChats/${user.uid}').once();
      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          chats.clear();
          data.forEach((key, value) {
            chats.add({
              'id': key,
              'lastMessage': value['lastMessage'],
              'timestamp': value['timestamp'],
              'createdAt': value['createdAt'],
            });
          });
          // Sort by timestamp (newest first)
          chats.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
          isLoading = false;
        });

        // Check if we should analyze chats
        if (_shouldAnalyzeChats()) {
          _analyzeChats();
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading chat history: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Update analysis after chat deletion
  Future<void> _updateAnalysisAfterDeletion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // If we have existing analysis, update it
      if (userAnalysis.isNotEmpty) {
        // Update the chat count
        userAnalysis['chatsAnalyzed'] = chats.length;
        
        // Update last analyzed timestamp
        userAnalysis['lastAnalyzed'] = DateTime.now().millisecondsSinceEpoch;
        
        // Save to both databases
        await _firestore.collection('userAnalysis').doc(user.uid).set(
          userAnalysis,
          SetOptions(merge: true),
        );
        
        await _db.child('userAnalysis/${user.uid}').set(userAnalysis);
        
        setState(() {
          // Keep the analysis but update the data
        });
      }
    } catch (e) {
      print("Error updating analysis after deletion: $e");
    }
  }

  Future<void> _deleteChat(String chatId, int index) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Show confirmation dialog
      bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Delete Chat"),
            content: const Text("Are you sure you want to delete this chat?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirmDelete == true) {
        // Remove from UI first for better UX
        setState(() {
          chats.removeAt(index);
        });

        // Delete from Firebase
        await _db.child('userChats/${user.uid}/$chatId').remove();
        
        // Also delete the chat messages
        await _db.child('chats/$chatId').remove();

        // Update analysis after deletion
        await _updateAnalysisAfterDeletion();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chat deleted successfully"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error deleting chat: $e");
      
      // Reload chats if deletion failed
      _loadChatHistory();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to delete chat"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteAllChats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Show confirmation dialog
      bool confirmDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Delete All Chats"),
            content: const Text("Are you sure you want to delete all chat history?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Delete All", style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirmDelete == true) {
        setState(() {
          isLoading = true;
        });

        // Get all chat IDs first
        final snapshot = await _db.child('userChats/${user.uid}').once();
        if (snapshot.snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
          
          // Delete each chat and its messages
          for (String chatId in data.keys) {
            await _db.child('userChats/${user.uid}/$chatId').remove();
            await _db.child('chats/$chatId').remove();
          }
        }

        // Clear analysis data when all chats are deleted
        if (userAnalysis.isNotEmpty) {
          await _firestore.collection('userAnalysis').doc(user.uid).delete();
          await _db.child('userAnalysis/${user.uid}').remove();
          
          setState(() {
            userAnalysis = {};
            showAnalysis = false;
          });
        }

        setState(() {
          chats.clear();
          isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All chats deleted successfully"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error deleting all chats: $e");
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to delete all chats"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Widget to display analysis results
  Widget _buildAnalysisSection() {
    if (!showAnalysis || userAnalysis.isEmpty) {
      return Container();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              "Chat Analysis Insights",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  showAnalysis = false;
                });
              },
            ),
          ),
          const Divider(),
          SizedBox(
            height: 400, // Fixed height to ensure scroll works
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userAnalysis['summary'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Summary:",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userAnalysis['summary'],
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  
                  if (userAnalysis['preferences'] != null)
                    _buildAnalysisCategory("Preferences", userAnalysis['preferences']),
                  
                  if (userAnalysis['mental_condition'] != null)
                    _buildAnalysisCategory("Mental Condition", userAnalysis['mental_condition']),
                  
                  if (userAnalysis['interests'] != null)
                    _buildAnalysisCategory("Interests", userAnalysis['interests']),
                  
                  if (userAnalysis['dislikes'] != null)
                    _buildAnalysisCategory("Dislikes", userAnalysis['dislikes']),
                  
                  if (userAnalysis['lastAnalyzed'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        "Last analyzed: ${_formatTimestamp(userAnalysis['lastAnalyzed'])}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  
                  if (userAnalysis['chatsAnalyzed'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Based on ${userAnalysis['chatsAnalyzed']} chats",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _analyzeChats,
              child: const Text("Update Analysis"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCategory(String title, dynamic data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title:",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (data is String)
            Text(data, style: const TextStyle(fontSize: 14)),
          if (data is Map)
            ...data.entries.map<Widget>((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text("• ${entry.key}: ${entry.value}", 
                  style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
          if (data is List)
            ...data.map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text("• $item", style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat History"),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          if (chats.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: _analyzeChats,
              tooltip: "Analyze Chats",
            ),
          if (chats.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _deleteAllChats,
              tooltip: "Delete All Chats",
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
              ? const Center(
                  child: Text(
                    "No chat history yet",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : Column(
                  children: [
                    if (isAnalyzing)
                      const LinearProgressIndicator(
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    if (showAnalysis) _buildAnalysisSection(),
                    if (!showAnalysis && chats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: _analyzeChats,
                          child: const Text("Analyze My Chats"),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return Dismissible(
                            key: Key(chat['id']),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Delete Chat"),
                                    content: const Text("Are you sure you want to delete this chat?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            onDismissed: (direction) {
                              _deleteChat(chat['id'], index);
                            },
                            child: ListTile(
                              leading: const Icon(Icons.chat, color: Color(0xFF2196F3)),
                              title: Text(
                                chat['lastMessage'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(_formatTimestamp(chat['timestamp'])),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _deleteChat(chat['id'], index),
                              ),
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      userData: widget.userData,
                                      chatId: chat['id'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}