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
import 'theme_manager.dart'; // Theme manager import করুন

class RecommendationsScreen extends StatefulWidget {
  final Map<String, dynamic> p_userData;
  final String userId;

  const RecommendationsScreen({super.key, required this.p_userData, required this.userId});

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
    _fetchUserProfileData();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      _fetchUserData();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to initialize Firebase: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final DocumentSnapshot firestoreSnapshot = 
          await firestore.collection('userAnalysis').doc(widget.userId).get();
      
      if (firestoreSnapshot.exists) {
        setState(() {
          userData = firestoreSnapshot.data() as Map<String, dynamic>;
        });
        await _getSpotifyAccessToken();
        _fetchRecommendations();
        return;
      }
      
      final DataSnapshot realtimeSnapshot = 
          await realtimeDbRef.child('userAnalysis').child(widget.userId).get();
      
      if (realtimeSnapshot.exists) {
        setState(() {
          userData = Map<String, dynamic>.from(realtimeSnapshot.value as Map);
        });
        await _getSpotifyAccessToken();
        _fetchRecommendations();
        return;
      }
      
      setState(() {
        errorMessage = 'No user data found for analysis';
        isLoading = false;
      });

      final profileData = await _fetchUserProfileData();
      setState(() {
        userProfileData = profileData;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load user data: $e';
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfileData() async {
    try {
      final DocumentSnapshot userDoc = 
          await firestore.collection('users').doc(widget.userId).get();
      
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      
      final DataSnapshot realtimeSnapshot = 
          await realtimeDbRef.child('users').child(widget.userId).get();
      
      if (realtimeSnapshot.exists) {
        return Map<String, dynamic>.from(realtimeSnapshot.value as Map);
      }
      
      return {};
    } catch (e) {
      return {};
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
        setState(() {
          spotifyAccessToken = data['access_token'];
        });
      }
    } catch (e) {
      print('Error getting Spotify token: $e');
    }
  }

  Future<void> _fetchRecommendations() async {
    try {
      final bookRecs = await _getBookRecommendations();
      final exerciseRecs = await _getExerciseRecommendations();
      final songRecs = await _getSongRecommendations();
      
      setState(() {
        bookRecommendations = bookRecs;
        exerciseRecommendations = exerciseRecs;
        songRecommendations = songRecs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load recommendations: $e';
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _getBookRecommendations() async {
    final themes = _extractThemesFromUserData();
    List<dynamic> allBooks = [];
    
    for (String theme in themes) {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$theme&maxResults=3&key=$googleBooksApiKey')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null) {
          allBooks.addAll(data['items']);
        }
      }
    }
    
    final seenIds = <String>{};
    allBooks.retainWhere((book) => seenIds.add(book['id']));
    
    return allBooks.take(10).toList(); 
  }

  Future<List<dynamic>> _getExerciseRecommendations() async {
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
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return _parseExerciseResponse(text);
    } else {
      throw Exception('Failed to get exercise recommendations');
    }
  }

  Future<List<dynamic>> _getSongRecommendations() async {
    try {
      final geminiSongRecs = await _getGeminiSongRecommendations();
      
      if (spotifyAccessToken == null) {
        return geminiSongRecs;
      }
      
      final List<dynamic> spotifySongs = [];
      
      for (final song in geminiSongRecs) {
        final songName = song['title'] ?? '';
        final artistName = song['artist'] ?? '';
        
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
        
        if (spotifySongs.length >= 6) break;
      }
      
      if (spotifySongs.isNotEmpty) {
        return spotifySongs;
      }
      
      return geminiSongRecs;
    } catch (e) {
      return _getFallbackSongs();
    }
  }

  Future<List<dynamic>> _getGeminiSongRecommendations() async {
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
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return _parseMusicResponse(text);
    } else {
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
        final tracks = data['tracks']['items'];
        
        if (tracks != null && tracks.isNotEmpty) {
          return tracks[0];
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
        'title': 'Calm Meditation',
        'artist': 'Meditation Masters',
        'description': 'Relaxing meditation music for stress relief',
        'image': 'https://placehold.co/150x150/2196F3/white?text=Meditation',
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      },
      {
        'title': 'Peaceful Mind',
        'artist': 'Relaxation Sounds',
        'description': 'Soothing sounds for mental peace',
        'image': 'https://placehold.co/150x150/2196F3/white?text=Relaxation',
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      },
    ];
  }

  List<String> _extractThemesFromUserData() {
    final themes = <String>[];
    
    if (userData['mental_condition'] != null) {
      final mentalCondition = userData['mental_condition'];
      
      if (mentalCondition['anger'] != null) themes.add('anger management');
      if (mentalCondition['anxiety_triggers'] != null) themes.add('anxiety relief');
      if (mentalCondition['self_worth']?.toString().contains('Low') ?? false) {
        themes.add('self esteem');
      }
      if (mentalCondition['suicidal_ideation'] != null) {
        themes.add('mental health recovery');
        themes.add('suicide prevention');
      }
      if (mentalCondition['mood_patterns']?.toString().contains('mood swings') ?? false) {
        themes.add('mood stability');
      }
      if (mentalCondition['stress_indicators']?.toString().contains('High') ?? false) {
        themes.add('stress management');
      }
    }
    
    if (userData['interests'] != null) {
      final interests = userData['interests'];
      if (interests['topics'] != null) {
        if (interests['topics'].toString().contains('Friendship')) themes.add('friendship');
        if (interests['topics'].toString().contains('mental health')) themes.add('mental health');
        if (interests['topics'].toString().contains('conflict resolution')) themes.add('conflict resolution');
      }
    }
    
    if (userData['dislikes'] != null) {
      final dislikes = userData['dislikes'];
      if (dislikes['situations']?.toString().contains('bored') ?? false) {
        themes.add('overcoming boredom');
      }
      if (dislikes['situations']?.toString().contains('quarreling') ?? false) {
        themes.add('conflict resolution');
      }
    }
    
    if (userData['preferences'] != null) {
      final preferences = userData['preferences'];
      if (preferences['other']?.toString().contains('friendship recovery') ?? false) {
        themes.add('friendship repair');
      }
    }
    
    if (themes.length < 3) {
      themes.addAll(['mindfulness', 'emotional wellness', 'self-care']);
    }
    
    return themes;
  }

  String _createExercisePrompt() {
    return """
Based on the following user profile, suggest 10 personalized mental health exercises. 
Return the response as a JSON array with each exercise having: title, description, duration, and category.

User Profile:
- Mental Condition: ${userData['mental_condition'] ?? 'Not specified'}
- Interests: ${userData['interests'] ?? 'Not specified'}
- Dislikes: ${userData['dislikes'] ?? 'Not specified'}
- Preferences: ${userData['preferences'] ?? 'Not specified'}
- Summary: ${userData['summary'] ?? 'Not specified'}

Provide the response in valid JSON format only.
""";
  }

  String _createMusicPrompt() {
    return """
Based on the following user profile, suggest 10 personalized songs for mental health and emotional well-being.
Return ONLY a valid JSON array with each song object having exactly these fields: title, artist, description.

IMPORTANT: Return ONLY the JSON array, no additional text or explanations.

Example format:
[
  {
    "title": "Song Title",
    "artist": "Artist Name", 
    "description": "Why this song is recommended"
  }
]

User Profile:
- Mental Condition: ${userData['mental_condition'] ?? 'Not specified'}
- Interests: ${userData['interests'] ?? 'Not specified'}
- Dislikes: ${userData['dislikes'] ?? 'Not specified'}
- Preferences: ${userData['preferences'] ?? 'Not specified'}
- Summary: ${userData['summary'] ?? 'Not specified'}

Focus on songs that would help with the user's specific mental health needs.
""";
  }

  List<dynamic> _parseExerciseResponse(String text) {
    try {
      final startIndex = text.indexOf('[');
      final endIndex = text.lastIndexOf(']') + 1;
      final jsonString = text.substring(startIndex, endIndex);
      return json.decode(jsonString);
    } catch (e) {
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
        }
      ];
    }
  }

  List<dynamic> _parseMusicResponse(String text) {
    try {
      final jsonPattern = RegExp(r'\[.*\]', multiLine: true, dotAll: true);
      final match = jsonPattern.firstMatch(text);
      
      if (match != null) {
        final jsonString = match.group(0);
        return json.decode(jsonString!);
      }
      
      return _getFallbackSongs();
    } catch (e) {
      return _getFallbackSongs();
    }
  }

  void _openBookPreview(book) {
    final previewLink = book['volumeInfo']?['previewLink'];
    final title = book['volumeInfo']?['title'] ?? 'Book Preview';
    
    if (previewLink != null) {
      Navigator.pushNamed(
        context, 
        '/book_preview', 
        arguments: {'url': previewLink, 'title': title}
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          title: const Text('Preview Not Available'),
          content: Text('Sorry, no preview is available for "$title".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: _currentTheme.primary)),
            )
          ],
        ),
      );
    }
  }

  void _openSpotifySong(song) async {
    final spotifyUrl = song['external_urls']?['spotify'];
    final songName = song['name'] ?? 'Song';
    
    if (spotifyUrl != null) {
      if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
        await launchUrl(Uri.parse(spotifyUrl));
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _currentTheme.containerColor,
            title: Text('Cannot Open $songName'),
            content: const Text('Please install Spotify to open this song.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: _currentTheme.primary)),
              )
            ],
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          title: const Text('No Spotify Link Available'),
          content: Text('Sorry, no Spotify link is available for "$songName".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: _currentTheme.primary)),
            )
          ],
        ),
      );
    }
  }

  void _playPauseSong(int index, String? previewUrl) async {
    if (previewUrl == null || previewUrl.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          title: const Text('Preview Not Available'),
          content: const Text('Sorry, no preview is available for this song.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: _currentTheme.primary)),
            )
          ],
        ),
      );
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
        setState(() {
          playerState = PlayerState.stopped;
          currentlyPlayingIndex = null;
        });
      });
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
    switch (_currentSection) {
      case 0:
        return _buildBooksSection();
      case 1:
        return _buildExercisesSection();
      case 2:
        return _buildMusicSection();
      default:
        return Container();
    }
  }

  Widget _buildBooksSection() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: bookRecommendations.length,
      itemBuilder: (context, index) {
        final book = bookRecommendations[index];
        final volumeInfo = book['volumeInfo'];
        final title = volumeInfo?['title'] ?? 'Unknown Title';
        final authors = volumeInfo?['authors'] != null 
            ? volumeInfo['authors'].join(', ') 
            : 'Unknown Author';
        final thumbnail = volumeInfo?['imageLinks']?['thumbnail'] ?? '';
        
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
                    ),
                  )
                else
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: Icon(Icons.book, size: 60, color: _currentTheme.primary),
                  ),
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
                  onPressed: () {
                    _openBookPreview(book);
                  },
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: exerciseRecommendations.length,
      itemBuilder: (context, index) {
        final exercise = exerciseRecommendations[index];
        
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
                    exercise['title'] ?? 'Exercise',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _currentTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    exercise['description'] ?? '',
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: songRecommendations.length,
      itemBuilder: (context, index) {
        final song = songRecommendations[index];
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
                        return Container(
                          height: 180,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: Icon(Icons.music_note, size: 60, color: _currentTheme.primary),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: Icon(Icons.music_note, size: 60, color: _currentTheme.primary),
                  ),
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
                        onPressed: () {
                          _openSpotifySong(song);
                        },
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
                      onPressed: () {
                        Navigator.pop(context); 
                      },
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
                      onPressed: () {
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Section Buttons with theme colors
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentSection == 0 ? _currentTheme.primary : Colors.white,
                          foregroundColor: _currentSection == 0 ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentSection = 0;
                          });
                        },
                        child: const Text(
                          'Books',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentSection == 1 ? _currentTheme.primary : Colors.white,
                          foregroundColor: _currentSection == 1 ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentSection = 1;
                          });
                        },
                        child: const Text(
                          'Exercises',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentSection == 2 ? _currentTheme.primary : Colors.white,
                          foregroundColor: _currentSection == 2 ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentSection = 2;
                          });
                        },
                        child: const Text(
                          'Music',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (errorMessage != null)
                Expanded(
                  child: Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else
                Expanded(
                  child: _buildContent(),
                ),

              // Bottom Container with theme colors
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
                            builder: (context) => HomeScreen(userData: widget.p_userData),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(userData: widget.p_userData),
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
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.people, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/pro');
                      },
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