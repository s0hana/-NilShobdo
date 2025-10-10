import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'chat_sceen.dart';
import 'theme_manager.dart';

class RecommendationsScreen extends StatefulWidget {
  final Map<String, dynamic> pUserData;
  final String userId;

  const RecommendationsScreen({super.key, required this.pUserData, required this.userId});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<dynamic> bookRecommendations = [];
  List<dynamic> exerciseRecommendations = [];
  List<dynamic> songRecommendations = [];
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic> userData = {};
  Map<String, dynamic> userProfileData = {};
  String? spotifyAccessToken;

  // Audio player
  final AudioPlayer audioPlayer = AudioPlayer();
  int? currentlyPlayingIndex;
  PlayerState playerState = PlayerState.stopped;

  // API Keys
  final String googleBooksApiKey = 'AIzaSyDXx4LY3ANAyAQFJhtixpugNAwEpKBzCfo';
  final String geminiApiKey = 'AIzaSyBSx-y5UfkQ8XlFGjFB5jDJHkmWI0Is-wQ';
  
  // Spotify credentials
  final String spotifyClientId = '58e043478b674da8ba95b5b98ec53663';
  final String spotifyClientSecret = '97ed3440fee644dca0d6c23a96884b68';

  // Firebase references
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DatabaseReference realtimeDbRef = FirebaseDatabase.instance.ref();

  // Track current section
  int _currentSection = 0;

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeFirebase();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    try {
      final themeIndex = await ThemeManager.getSelectedThemeIndex();
      setState(() {
        _currentThemeIndex = themeIndex;
        _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
      });
    } catch (e) {
      print("Error loading theme: $e");
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      await _fetchUserData();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize Firebase: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchUserData() async {
    try {
      // Try Firestore first
      final DocumentSnapshot firestoreSnapshot = 
          await firestore.collection('userAnalysis').doc(widget.userId).get();
      
      if (firestoreSnapshot.exists && firestoreSnapshot.data() != null) {
        final data = firestoreSnapshot.data();
        if (data is Map<String, dynamic>) {
          setState(() {
            userData = data;
          });
          await _getSpotifyAccessToken();
          await _fetchRecommendations();
          return;
        }
      }
      
      // Try Realtime Database
      final DataSnapshot realtimeSnapshot = 
          await realtimeDbRef.child('userAnalysis').child(widget.userId).get();
      
      if (realtimeSnapshot.exists && realtimeSnapshot.value != null) {
        final data = realtimeSnapshot.value;
        if (data is Map) {
          setState(() {
            userData = Map<String, dynamic>.from(data as Map);
          });
          await _getSpotifyAccessToken();
          await _fetchRecommendations();
          return;
        }
      }
      
      // If no data found
      setState(() {
        errorMessage = 'No user data found for analysis';
        isLoading = false;
      });
      
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        errorMessage = 'Failed to load user data: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _getSpotifyAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic ' + base64Encode(
            utf8.encode('$spotifyClientId:$spotifyClientSecret')
          ),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('access_token')) {
          setState(() {
            spotifyAccessToken = data['access_token'] as String;
          });
        }
      } else {
        print('Spotify token request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting Spotify token: $e');
    }
  }

  Future<void> _fetchRecommendations() async {
    try {
      final List<dynamic> bookRecs = await _getBookRecommendations();
      final List<dynamic> exerciseRecs = await _getExerciseRecommendations();
      final List<dynamic> songRecs = await _getSongRecommendations();
      
      // Validate data types
      if (bookRecs is! List) throw Exception('Book recommendations is not a list');
      if (exerciseRecs is! List) throw Exception('Exercise recommendations is not a list');
      if (songRecs is! List) throw Exception('Song recommendations is not a list');
      
      setState(() {
        bookRecommendations = bookRecs;
        exerciseRecommendations = exerciseRecs;
        songRecommendations = songRecs;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching recommendations: $e");
      setState(() {
        errorMessage = 'Failed to load recommendations: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _getBookRecommendations() async {
    try {
      final themes = _extractThemesFromUserData();
      List<dynamic> allBooks = [];
      
      for (String theme in themes.take(3)) { // Limit to 3 themes to avoid too many requests
        final response = await http.get(
          Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$theme&maxResults=3&key=$googleBooksApiKey')
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data.containsKey('items')) {
            final items = data['items'];
            if (items is List) {
              allBooks.addAll(items);
            }
          }
        }
        
        // Add delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Remove duplicates
      final seenIds = <String>{};
      final uniqueBooks = allBooks.where((book) {
        if (book is Map<String, dynamic> && book.containsKey('id')) {
          final id = book['id'] as String;
          return seenIds.add(id);
        }
        return false;
      }).toList();
      
      return uniqueBooks.take(10).toList();
    } catch (e) {
      print("Error getting book recommendations: $e");
      return _getFallbackBooks();
    }
  }

  List<dynamic> _getFallbackBooks() {
    return [
      {
        'volumeInfo': {
          'title': 'The Power of Now',
          'authors': ['Eckhart Tolle'],
          'imageLinks': {'thumbnail': 'https://placehold.co/150x200/4CAF50/white?text=Power+of+Now'},
          'previewLink': 'https://books.google.com/books?id=some_id'
        }
      },
      {
        'volumeInfo': {
          'title': 'Atomic Habits',
          'authors': ['James Clear'],
          'imageLinks': {'thumbnail': 'https://placehold.co/150x200/2196F3/white?text=Atomic+Habits'},
          'previewLink': 'https://books.google.com/books?id=some_id'
        }
      }
    ];
  }

  Future<List<dynamic>> _getExerciseRecommendations() async {
    try {
      final prompt = _createExercisePrompt();
      
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }]
        })
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && 
            data.containsKey('candidates') && 
            data['candidates'] is List && 
            data['candidates'].isNotEmpty) {
          
          final candidate = data['candidates'][0];
          if (candidate is Map<String, dynamic> &&
              candidate.containsKey('content') &&
              candidate['content'] is Map<String, dynamic> &&
              candidate['content']['parts'] is List &&
              candidate['content']['parts'].isNotEmpty) {
            
            final text = candidate['content']['parts'][0]['text'] as String;
            return _parseExerciseResponse(text);
          }
        }
      }
      
      return _getFallbackExercises();
    } catch (e) {
      print("Error getting exercise recommendations: $e");
      return _getFallbackExercises();
    }
  }

  List<dynamic> _parseExerciseResponse(String text) {
    try {
      print("Raw exercise response: $text");
      
      final jsonPattern = RegExp(r'\[.*\]', multiLine: true, dotAll: true);
      final match = jsonPattern.firstMatch(text);
      
      if (match != null) {
        final jsonString = match.group(0);
        if (jsonString != null) {
          final parsedData = json.decode(jsonString);
          if (parsedData is List) {
            // Validate each item in the list
            for (var item in parsedData) {
              if (item is! Map<String, dynamic>) {
                return _getFallbackExercises();
              }
            }
            return parsedData;
          }
        }
      }
      
      return _getFallbackExercises();
    } catch (e) {
      print("Error parsing exercise response: $e");
      return _getFallbackExercises();
    }
  }

  List<dynamic> _getFallbackExercises() {
    return [
      {
        'title': 'Deep Breathing',
        'description': 'Practice deep breathing for 5 minutes to calm your mind',
        'duration': '5 minutes',
        'category': 'Relaxation'
      },
      {
        'title': 'Gratitude Journaling',
        'description': 'Write down three things you are grateful for today',
        'duration': '10 minutes',
        'category': 'Mindfulness'
      },
      {
        'title': 'Mindful Walking',
        'description': 'Take a 10-minute walk while paying attention to your surroundings',
        'duration': '10 minutes',
        'category': 'Mindfulness'
      }
    ];
  }

  Future<List<dynamic>> _getSongRecommendations() async {
    try {
      final geminiSongRecs = await _getGeminiSongRecommendations();
      
      if (spotifyAccessToken == null) {
        return geminiSongRecs;
      }
      
      final List<dynamic> spotifySongs = [];
      
      for (final song in geminiSongRecs.take(8)) { // Limit to 8 songs
        if (song is Map<String, dynamic>) {
          final songName = (song['title'] ?? '') as String;
          final artistName = (song['artist'] ?? '') as String;
          
          if (songName.isNotEmpty) {
            try {
              final spotifySong = await _searchSpotifySong(songName, artistName);
              if (spotifySong != null) {
                spotifySongs.add(spotifySong);
              }
            } catch (e) {
              print('Error searching for song $songName on Spotify: $e');
            }
          }
        }
        
        if (spotifySongs.length >= 6) break;
      }
      
      return spotifySongs.isNotEmpty ? spotifySongs : geminiSongRecs;
    } catch (e) {
      print("Error getting song recommendations: $e");
      return _getFallbackSongs();
    }
  }

  Future<List<dynamic>> _getGeminiSongRecommendations() async {
    try {
      final prompt = _createMusicPrompt();
      
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [{
            'parts': [{
              'text': prompt
            }]
          }]
        })
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && 
            data.containsKey('candidates') && 
            data['candidates'] is List && 
            data['candidates'].isNotEmpty) {
          
          final candidate = data['candidates'][0];
          if (candidate is Map<String, dynamic> &&
              candidate.containsKey('content') &&
              candidate['content'] is Map<String, dynamic> &&
              candidate['content']['parts'] is List &&
              candidate['content']['parts'].isNotEmpty) {
            
            final text = candidate['content']['parts'][0]['text'] as String;
            return _parseMusicResponse(text);
          }
        }
      }
      
      return _getFallbackSongs();
    } catch (e) {
      print("Error getting Gemini song recommendations: $e");
      return _getFallbackSongs();
    }
  }

  List<dynamic> _parseMusicResponse(String text) {
    try {
      print("Raw music response: $text");
      
      final jsonPattern = RegExp(r'\[.*\]', multiLine: true, dotAll: true);
      final match = jsonPattern.firstMatch(text);
      
      if (match != null) {
        final jsonString = match.group(0);
        if (jsonString != null) {
          final parsedData = json.decode(jsonString);
          if (parsedData is List) {
            // Validate each item has required fields
            for (var item in parsedData) {
              if (item is! Map<String, dynamic> || 
                  !item.containsKey('title') || 
                  !item.containsKey('artist')) {
                return _getFallbackSongs();
              }
            }
            return parsedData;
          }
        }
      }
      
      return _getFallbackSongs();
    } catch (e) {
      print("Error parsing music response: $e");
      return _getFallbackSongs();
    }
  }

  Future<dynamic> _searchSpotifySong(String songName, String artistName) async {
    if (spotifyAccessToken == null) return null;
    
    try {
      String query = 'track:$songName';
      if (artistName.isNotEmpty) {
        query += ' artist:$artistName';
      }
      
      final url = Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '1',
      });
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $spotifyAccessToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && 
            data.containsKey('tracks') && 
            data['tracks'] is Map<String, dynamic> &&
            data['tracks']['items'] is List) {
          
          final tracks = data['tracks']['items'] as List;
          if (tracks.isNotEmpty) {
            return tracks[0];
          }
        }
      }
    } catch (e) {
      print('Error searching Spotify for $songName: $e');
    }
    
    return null;
  }

  List<dynamic> _getFallbackSongs() {
    return [
      {
        'name': 'Weightless',
        'artists': [{'name': 'Marconi Union'}],
        'album': {'images': [{'url': 'https://placehold.co/150x150/4CAF50/white?text=Weightless'}]},
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'external_urls': {'spotify': 'https://open.spotify.com/track/example1'}
      },
      {
        'name': 'Clair de Lune',
        'artists': [{'name': 'Claude Debussy'}],
        'album': {'images': [{'url': 'https://placehold.co/150x150/2196F3/white?text=Clair+de+Lune'}]},
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        'external_urls': {'spotify': 'https://open.spotify.com/track/example2'}
      }
    ];
  }

  List<String> _extractThemesFromUserData() {
    final themes = <String>[];
    
    try {
      // Safe access to mental_condition
      final mentalCondition = userData['mental_condition'];
      if (mentalCondition is Map<String, dynamic>) {
        if (mentalCondition['anger'] != null) themes.add('anger management');
        if (mentalCondition['anxiety_triggers'] != null) themes.add('anxiety relief');
        
        final selfWorth = mentalCondition['self_worth'];
        if (selfWorth is String && selfWorth.contains('Low')) {
          themes.add('self esteem');
        }
        
        final suicidalIdeation = mentalCondition['suicidal_ideation'];
        if (suicidalIdeation != null) {
          themes.add('mental health recovery');
          themes.add('suicide prevention');
        }
        
        final moodPatterns = mentalCondition['mood_patterns'];
        if (moodPatterns is String && moodPatterns.contains('mood swings')) {
          themes.add('mood stability');
        }
        
        final stressIndicators = mentalCondition['stress_indicators'];
        if (stressIndicators is String && stressIndicators.contains('High')) {
          themes.add('stress management');
        }
      }
      
      // Safe access to interests
      final interests = userData['interests'];
      if (interests is Map<String, dynamic>) {
        final topics = interests['topics'];
        if (topics is String) {
          if (topics.contains('Friendship')) themes.add('friendship');
          if (topics.contains('mental health')) themes.add('mental health');
          if (topics.contains('conflict resolution')) themes.add('conflict resolution');
        }
      }
      
      // Safe access to dislikes
      final dislikes = userData['dislikes'];
      if (dislikes is Map<String, dynamic>) {
        final situations = dislikes['situations'];
        if (situations is String) {
          if (situations.contains('bored')) themes.add('overcoming boredom');
          if (situations.contains('quarreling')) themes.add('conflict resolution');
        }
      }
      
      // Safe access to preferences
      final preferences = userData['preferences'];
      if (preferences is Map<String, dynamic>) {
        final other = preferences['other'];
        if (other is String && other.contains('friendship recovery')) {
          themes.add('friendship repair');
        }
      }
    } catch (e) {
      print("Error extracting themes: $e");
    }
    
    // Fallback themes
    if (themes.length < 3) {
      themes.addAll(['mindfulness', 'emotional wellness', 'self-care']);
    }
    
    return themes.take(5).toList(); // Limit to 5 themes
  }

  String _createExercisePrompt() {
    return """
Based on the following user profile, suggest 8 personalized mental health exercises. 
Return the response as a JSON array with each exercise having: title, description, duration, and category.

User Profile:
- Mental Condition: ${_safeString(userData['mental_condition'])}
- Interests: ${_safeString(userData['interests'])}
- Dislikes: ${_safeString(userData['dislikes'])}
- Preferences: ${_safeString(userData['preferences'])}
- Summary: ${_safeString(userData['summary'])}

Provide the response in valid JSON format only. Example:
[
  {
    "title": "Exercise Name",
    "description": "Detailed description",
    "duration": "5 minutes", 
    "category": "Category Name"
  }
]
""";
  }

  String _createMusicPrompt() {
    return """
Based on the following user profile, suggest 8 personalized songs for mental health and emotional well-being.
Return ONLY a valid JSON array with each song object having exactly these fields: title, artist, description.

IMPORTANT: Return ONLY the JSON array, no additional text or explanations.

User Profile:
- Mental Condition: ${_safeString(userData['mental_condition'])}
- Interests: ${_safeString(userData['interests'])}
- Dislikes: ${_safeString(userData['dislikes'])}
- Preferences: ${_safeString(userData['preferences'])}
- Summary: ${_safeString(userData['summary'])}

Recommend songs that cater to the user's mental health requirements while giving priority to their religious preferences and values.
""";
  }

  String _safeString(dynamic value) {
    if (value == null) return 'Not specified';
    if (value is String) return value;
    if (value is Map || value is List) return value.toString();
    return value.toString();
  }

  void _openBookPreview(dynamic book) {
    try {
      if (book is Map<String, dynamic> && 
          book.containsKey('volumeInfo') && 
          book['volumeInfo'] is Map<String, dynamic>) {
        
        final volumeInfo = book['volumeInfo'] as Map<String, dynamic>;
        final previewLink = volumeInfo['previewLink'];
        final title = volumeInfo['title'] ?? 'Book Preview';
        
        if (previewLink is String && previewLink.isNotEmpty) {
          Navigator.pushNamed(
            context, 
            '/book_preview', 
            arguments: {'url': previewLink, 'title': title}
          );
          return;
        }
      }
      
      _showErrorDialog('Preview Not Available', 'Sorry, no preview is available for this book.');
    } catch (e) {
      _showErrorDialog('Error', 'Failed to open book preview: $e');
    }
  }

  void _openSpotifySong(dynamic song) async {
    try {
      if (song is Map<String, dynamic> && 
          song.containsKey('external_urls') && 
          song['external_urls'] is Map<String, dynamic>) {
        
        final externalUrls = song['external_urls'] as Map<String, dynamic>;
        final spotifyUrl = externalUrls['spotify'];
        final songName = song['name']?.toString() ?? 'Song';
        
        if (spotifyUrl is String && spotifyUrl.isNotEmpty) {
          if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
            await launchUrl(Uri.parse(spotifyUrl));
            return;
          }
        }
      }
      
      _showErrorDialog('Cannot Open Song', 'Please install Spotify to open this song.');
    } catch (e) {
      _showErrorDialog('Error', 'Failed to open Spotify: $e');
    }
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _currentTheme.containerColor,
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: _currentTheme.primary)),
          )
        ],
      ),
    );
  }

  void _playPauseSong(int index, String? previewUrl) async {
    try {
      if (previewUrl == null || previewUrl.isEmpty) {
        _showErrorDialog('Preview Not Available', 'Sorry, no preview is available for this song.');
        return;
      }

      if (currentlyPlayingIndex == index && playerState == PlayerState.playing) {
        await audioPlayer.pause();
        setState(() {
          playerState = PlayerState.paused;
        });
      } else if (currentlyPlayingIndex == index && playerState == PlayerState.paused) {
        await audioPlayer.resume();
        setState(() {
          playerState = PlayerState.playing;
        });
      } else {
        if (currentlyPlayingIndex != null) {
          await audioPlayer.stop();
        }
        
        await audioPlayer.play(UrlSource(previewUrl));
        setState(() {
          currentlyPlayingIndex = index;
          playerState = PlayerState.playing;
        });
        
        audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              playerState = PlayerState.stopped;
              currentlyPlayingIndex = null;
            });
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Playback Error', 'Failed to play audio: $e');
    }
  }

  String _getArtistNames(dynamic artistsData) {
    if (artistsData == null) return 'Unknown Artist';
    
    try {
      if (artistsData is List) {
        return artistsData.map<String>((artist) {
          if (artist is Map<String, dynamic>) {
            return artist['name']?.toString() ?? 'Unknown Artist';
          }
          return 'Unknown Artist';
        }).join(', ');
      }
      return 'Unknown Artist';
    } catch (e) {
      return 'Unknown Artist';
    }
  }

  String _getImageUrl(dynamic albumData) {
    if (albumData == null) return '';
    
    try {
      if (albumData is Map<String, dynamic>) {
        final images = albumData['images'];
        if (images is List && images.isNotEmpty) {
          final firstImage = images[0];
          if (firstImage is Map<String, dynamic>) {
            return firstImage['url']?.toString() ?? '';
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    switch (_currentSection) {
      case 0:
        return _buildBooksSection();
      case 1:
        return _buildExercisesSection();
      case 2:
        return _buildMusicSection();
      default:
        return const Center(child: Text('Select a category'));
    }
  }

  Widget _buildBooksSection() {
    if (bookRecommendations.isEmpty) {
      return const Center(child: Text('No book recommendations available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: bookRecommendations.length,
      itemBuilder: (context, index) {
        final book = bookRecommendations[index];
        if (book is! Map<String, dynamic>) return const SizedBox();

        final volumeInfo = book['volumeInfo'];
        if (volumeInfo is! Map<String, dynamic>) return const SizedBox();

        final title = (volumeInfo['title'] ?? 'Unknown Title') as String;
        final authors = volumeInfo['authors'] is List 
            ? (volumeInfo['authors'] as List).join(', ')
            : 'Unknown Author';
        final thumbnail = volumeInfo['imageLinks'] is Map<String, dynamic>
            ? (volumeInfo['imageLinks']['thumbnail'] ?? '') as String
            : '';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: _currentTheme.containerColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (thumbnail.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      thumbnail,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderIcon(Icons.book);
                      },
                    ),
                  )
                else
                  _buildPlaceholderIcon(Icons.book),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    authors,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _openBookPreview(book),
                  child: const Text("Read Preview"),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercisesSection() {
    if (exerciseRecommendations.isEmpty) {
      return const Center(child: Text('No exercise recommendations available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: exerciseRecommendations.length,
      itemBuilder: (context, index) {
        final exercise = exerciseRecommendations[index];
        if (exercise is! Map<String, dynamic>) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: _currentTheme.containerColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (exercise['title'] ?? 'Exercise') as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _currentTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (exercise['description'] ?? '') as String,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (exercise['duration'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Duration: ${exercise['duration']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _currentTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMusicSection() {
    if (songRecommendations.isEmpty) {
      return const Center(child: Text('No music recommendations available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: songRecommendations.length,
      itemBuilder: (context, index) {
        final song = songRecommendations[index];
        if (song is! Map<String, dynamic>) return const SizedBox();

        final title = song['name']?.toString() ?? song['title']?.toString() ?? 'Unknown Song';
        final artists = song['artists'] != null 
            ? _getArtistNames(song['artists']) 
            : song['artist']?.toString() ?? 'Unknown Artist';
        final thumbnail = song['album'] != null 
            ? _getImageUrl(song['album']) 
            : song['image']?.toString() ?? '';
        final previewUrl = song['preview_url']?.toString() ?? '';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: _currentTheme.containerColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (thumbnail.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      thumbnail,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderIcon(Icons.music_note);
                      },
                    ),
                  )
                else
                  _buildPlaceholderIcon(Icons.music_note),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    artists,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        currentlyPlayingIndex == index && playerState == PlayerState.playing 
                            ? Icons.pause_circle_filled 
                            : Icons.play_circle_filled,
                        size: 36,
                        color: _currentTheme.primary,
                      ),
                      onPressed: () => _playPauseSong(index, previewUrl),
                    ),
                    if (song['external_urls'] != null)
                      IconButton(
                        icon: Icon(
                          Icons.open_in_new,
                          size: 30,
                          color: _currentTheme.primary,
                        ),
                        onPressed: () => _openSpotifySong(song),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderIcon(IconData icon) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[300],
      child: Icon(icon, size: 60, color: _currentTheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_currentTheme.gradientStart, _currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Container with theme colors
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _currentTheme.primary,
                  border: Border(
                    bottom: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Let's keep it positive",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, size: 20, color: Colors.black),
                      onPressed: () => Navigator.pushNamed(context, "/set"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionButton(0, 'Books'),
                    const SizedBox(width: 8),
                    _buildSectionButton(1, 'Exercises'),
                    const SizedBox(width: 8),
                    _buildSectionButton(2, 'Music'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content Area
              Expanded(child: _buildContent()),

              // Bottom Navigation
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentTheme.primary,
                  border: Border(
                    top: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(userData: widget.pUserData),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(userData: widget.pUserData),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/icons/4616759.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 30, color: Colors.black),
                      onPressed: () => Navigator.pushNamed(context, '/profile'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.people, size: 30, color: Colors.black),
                      onPressed: () => Navigator.pushNamed(context, '/pro'),
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

  Widget _buildSectionButton(int sectionIndex, String text) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _currentSection == sectionIndex ? _currentTheme.primary : Colors.white,
          foregroundColor: _currentSection == sectionIndex ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          setState(() {
            _currentSection = sectionIndex;
          });
        },
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}