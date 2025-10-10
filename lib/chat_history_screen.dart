import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_sceen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'theme_manager.dart';
import 'setup_analisis_time_manager.dart'; // Add this import

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

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadChatHistory();
    _loadUserAnalysis();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
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
          backgroundColor: _currentTheme.containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: _currentTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "OK",
                style: TextStyle(
                  color: _currentTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Get messages within selected time range
  Future<List<String>> _getMessagesInTimeRange() async {
    final cutoffTimestamp = await AnalysisTimeManager.getCutoffTimestamp();
    List<String> allMessages = [];
    int analyzedChatsCount = 0;

    for (var chat in chats) {
      // Check if chat is within the time range
      if (chat['timestamp'] >= cutoffTimestamp) {
        final snapshot = await _db.child('chats/${chat['id']}/messages').once();
        if (snapshot.snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
          data.forEach((key, value) {
            // Check if message is from user and within time range
            if (value['isUser'] == true && value['timestamp'] >= cutoffTimestamp) {
              allMessages.add(value['message']);
            }
          });
          analyzedChatsCount++;
        }
      }
    }

    return allMessages;
  }

  // Analyze chats to extract user preferences, mental conditions, etc.
  Future<void> _analyzeChats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      // Get messages within selected time range
      final allMessages = await _getMessagesInTimeRange();
      final selectedTime = await AnalysisTimeManager.getSelectedTimeOption();

      if (allMessages.isEmpty) {
        setState(() {
          isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No user messages found in the last ${selectedTime.label.toLowerCase()}"),
            backgroundColor: _currentTheme.primary,
            duration: const Duration(seconds: 3),
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
                  "text": "Analyze the following chat messages from a user from the last ${selectedTime.label.toLowerCase()} and provide a comprehensive analysis in JSON format. "
                      "Include these categories: "
                      "1. preferences (food, colors, hobbies, movies, etc.), "
                      "2. mental_condition (mood patterns, stress indicators, anxiety triggers, etc.), "
                      "3. interests (topics they frequently discuss), "
                      "4. dislikes (things they express negative feelings about), "
                      "5. summary (overall analysis summary). "
                      "if the chat contains emojis then convert those emojis to text, like: 🍕: pizza"
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
            final jsonStart = analysisText.indexOf('{');
            final jsonEnd = analysisText.lastIndexOf('}');
            if (jsonStart >= 0 && jsonEnd > jsonStart) {
              final jsonString = analysisText.substring(jsonStart, jsonEnd + 1);
              final analysisData = jsonDecode(jsonString);
              
              // Add timestamp, chat count and time range info
              analysisData['lastAnalyzed'] = DateTime.now().millisecondsSinceEpoch;
              analysisData['chatsAnalyzed'] = chats.length;
              analysisData['timeRange'] = selectedTime.label;
              analysisData['cutoffTimestamp'] = await AnalysisTimeManager.getCutoffTimestamp();
              
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
                SnackBar(
                  content: Text("Chat analysis completed for last ${selectedTime.label.toLowerCase()}"),
                  backgroundColor: _currentTheme.primary,
                  duration: const Duration(seconds: 3),
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

  // Check if we should analyze chats (based on time range and new content)
  Future<bool> _shouldAnalyzeChats() async {
    if (chats.isEmpty) return false;
    
    final lastAnalyzed = userAnalysis['lastAnalyzed'] ?? 0;
    final lastCutoff = userAnalysis['cutoffTimestamp'] ?? 0;
    final currentCutoff = await AnalysisTimeManager.getCutoffTimestamp();
    
    // Analyze if:
    // 1. Never analyzed before, OR
    // 2. Time range has changed, OR
    // 3. It's been more than 24 hours since last analysis
    if (userAnalysis.isEmpty) return true;
    
    if (lastCutoff != currentCutoff) return true;
    
    final lastAnalysisTime = DateTime.fromMillisecondsSinceEpoch(lastAnalyzed);
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    return lastAnalysisTime.isBefore(twentyFourHoursAgo);
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
        if (await _shouldAnalyzeChats()) {
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
            backgroundColor: _currentTheme.containerColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              "Delete Chat",
              style: TextStyle(
                color: _currentTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text("Are you sure you want to delete this chat?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: _currentTheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Delete", 
                  style: TextStyle(color: Colors.red),
                ),
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
          SnackBar(
            content: const Text("Chat deleted successfully"),
            backgroundColor: _currentTheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error deleting chat: $e");
      
      // Reload chats if deletion failed
      _loadChatHistory();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to delete chat"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
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
            backgroundColor: _currentTheme.containerColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              "Delete All Chats",
              style: TextStyle(
                color: _currentTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text("Are you sure you want to delete all chat history?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: _currentTheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Delete All", 
                  style: TextStyle(color: Colors.red),
                ),
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
          SnackBar(
            content: const Text("All chats deleted successfully"),
            backgroundColor: _currentTheme.primary,
            duration: const Duration(seconds: 2),
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

  // Show current analysis time range info
  Widget _buildAnalysisTimeInfo() {
    return FutureBuilder<AnalysisTimeOption>(
      future: AnalysisTimeManager.getSelectedTimeOption(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Analysis includes chats from last ${snapshot.data!.label.toLowerCase()}",
              style: TextStyle(
                fontSize: 12,
                color: _currentTheme.primary.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }
        return const SizedBox();
      },
    );
  }

  // Widget to display analysis results
  Widget _buildAnalysisSection() {
    if (!showAnalysis || userAnalysis.isEmpty) {
      return Container();
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      color: _currentTheme.containerColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              "Chat Analysis Insights",
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: _currentTheme.primary,
                fontSize: 18,
              ),
            ),
            subtitle: userAnalysis['timeRange'] != null 
                ? Text(
                    "Based on last ${userAnalysis['timeRange']}",
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
            trailing: IconButton(
              icon: Icon(Icons.close, color: _currentTheme.primary),
              onPressed: () {
                setState(() {
                  showAnalysis = false;
                });
              },
            ),
          ),
          Divider(color: _currentTheme.primary.withOpacity(0.3)),
          SizedBox(
            height: 400,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userAnalysis['summary'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Summary:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: _currentTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userAnalysis['summary'],
                            style: const TextStyle(
                              fontStyle: FontStyle.italic, 
                              fontSize: 14,
                              color: Colors.black87,
                            ),
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
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _analyzeChats,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentTheme.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Update Analysis",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
              color: _currentTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (data is String)
            Text(
              data, 
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          if (data is Map)
            ...data.entries.map<Widget>((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  "• ${entry.key}: ${entry.value}", 
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              );
            }).toList(),
          if (data is List)
            ...data.map<Widget>((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  "• $item", 
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
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
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        elevation: 2,
        shadowColor: _currentTheme.primary.withOpacity(0.5),
        actions: [
          if (chats.isNotEmpty)
            IconButton(
              icon: Icon(Icons.analytics, color: Colors.black),
              onPressed: _analyzeChats,
              tooltip: "Analyze Chats",
            ),
          if (chats.isNotEmpty)
            IconButton(
              icon: Icon(Icons.settings, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/analysisSettings');
              },
              tooltip: "Analysis Settings",
            ),
          if (chats.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.black),
              onPressed: _deleteAllChats,
              tooltip: "Delete All Chats",
            ),
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
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: _currentTheme.primary,
                ),
              )
            : chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: _currentTheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No chat history yet",
                          style: TextStyle(
                            fontSize: 18,
                            color: _currentTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Start a conversation with Ikri to see your chat history here",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (isAnalyzing)
                        LinearProgressIndicator(
                          backgroundColor: _currentTheme.containerColor,
                          valueColor: AlwaysStoppedAnimation<Color>(_currentTheme.primary),
                        ),
                      _buildAnalysisTimeInfo(),
                      if (showAnalysis) _buildAnalysisSection(),
                      if (!showAnalysis && chats.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              ElevatedButton(
                                onPressed: _analyzeChats,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentTheme.primary,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Analyze My Chats",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/analysisSettings');
                                },
                                child: Text(
                                  "Adjust Analysis Time Range",
                                  style: TextStyle(
                                    color: _currentTheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: _currentTheme.containerColor,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.chat,
                                  color: _currentTheme.primary,
                                ),
                                title: Text(
                                  chat['lastMessage'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(chat['timestamp']),
                                  style: TextStyle(
                                    color: Colors.black54,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
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
      ),
    );
  }
}