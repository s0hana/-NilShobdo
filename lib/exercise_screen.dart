import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

class RecommendationsScreen extends StatefulWidget {
  final String userId;

  const RecommendationsScreen({super.key, required this.userId});

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
  String? spotifyAccessToken;

  // Audio player
  final AudioPlayer audioPlayer = AudioPlayer();
  int? currentlyPlayingIndex;
  PlayerState playerState = PlayerState.stopped;

  // API Keys
  final String googleBooksApiKey = 'AIzaSyDXx4LY3ANAyAQFJhtixpugNAwEpKBzCfo';
  final String geminiApiKey = 'AIzaSyD4ORRJgXcWwKJWn0PeCB2Co0_kIabLovM';
  
  // Spotify credentials
  final String spotifyClientId = '58e043478b674da8ba95b5b98ec53663';
  final String spotifyClientSecret = 'f18ade44cc5543bda0f8b9f361775e1c';

  // Firebase references
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DatabaseReference realtimeDbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
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
      // Try to get data from Firestore first
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
      
      // If not in Firestore, try Realtime Database
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
      
      // If no data found
      setState(() {
        errorMessage = 'No user data found for analysis';
        isLoading = false;
      });
    } catch (e) {
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
        setState(() {
          spotifyAccessToken = data['access_token'];
        });
      } else {
        print('Failed to get Spotify access token: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error getting Spotify token: $e');
    }
  }

  Future<void> _fetchRecommendations() async {
    try {
      // Generate recommendations based on user data
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
    // Extract key themes from user data for book search
    final themes = _extractThemesFromUserData();
    
    // For each theme, search for relevant books
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
    
    // Remove duplicates
    final seenIds = <String>{};
    allBooks.retainWhere((book) => seenIds.add(book['id']));
    
    return allBooks.take(6).toList(); // Return top 6 books
  }

  Future<List<dynamic>> _getExerciseRecommendations() async {
    // Use Gemini API to generate personalized exercises
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
      
      // Parse the response to extract exercises
      return _parseExerciseResponse(text);
    } else {
      throw Exception('Failed to get exercise recommendations');
    }
  }

  Future<List<dynamic>> _getSongRecommendations() async {
    if (spotifyAccessToken == null) {
      print('No Spotify access token available');
      return _getFallbackSongs();
    }
    
    try {
      // Extract music preferences from user data
      final musicThemes = _extractMusicThemesFromUserData();
      
      // Validate and map themes to Spotify's accepted genre seeds
      final validGenres = _getValidSpotifyGenres(musicThemes);
      
      if (validGenres.isEmpty) {
        print('No valid Spotify genres found');
        return _getFallbackSongs();
      }
      
      // Get recommendations based on seed genres
      final url = Uri.https('api.spotify.com', '/v1/recommendations', {
        'limit': '6',
        'seed_genres': validGenres.join(','),
      });
      
      print('Making Spotify API request to: ${url.toString()}');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $spotifyAccessToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Spotify API success: ${data['tracks']?.length ?? 0} tracks found');
        return data['tracks'] ?? _getFallbackSongs();
      } else {
        print('Spotify API error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return _getFallbackSongs();
      }
    } catch (e) {
      print('Error getting song recommendations: $e');
      return _getFallbackSongs();
    }
  }

  // Map our themes to valid Spotify genre seeds
  List<String> _getValidSpotifyGenres(List<String> themes) {
    // Spotify's accepted genre seeds (partial list)
    const validSpotifyGenres = {
      'acoustic', 'afrobeat', 'alt-rock', 'alternative', 'ambient', 'anime',
      'black-metal', 'bluegrass', 'blues', 'bossanova', 'brazil', 'breakbeat',
      'british', 'cantopop', 'chicago-house', 'children', 'chill', 'classical',
      'club', 'comedy', 'country', 'dance', 'dancehall', 'death-metal',
      'deep-house', 'detroit-techno', 'disco', 'disney', 'drum-and-bass',
      'dub', 'dubstep', 'edm', 'electro', 'electronic', 'emo', 'folk', 'forro',
      'french', 'funk', 'garage', 'german', 'gospel', 'goth', 'grindcore',
      'groove', 'grunge', 'guitar', 'happy', 'hard-rock', 'hardcore',
      'hardstyle', 'heavy-metal', 'hip-hop', 'holidays', 'honky-tonk',
      'house', 'idm', 'indian', 'indie', 'indie-pop', 'industrial', 'iranian',
      'j-dance', 'j-idol', 'j-pop', 'j-rock', 'jazz', 'k-pop', 'kids',
      'latin', 'latino', 'malay', 'mandopop', 'metal', 'metal-misc',
      'metalcore', 'minimal-techno', 'movies', 'mpb', 'new-age', 'new-release',
      'opera', 'pagode', 'party', 'philippines-opm', 'piano', 'pop', 'pop-film',
      'post-dubstep', 'power-pop', 'progressive-house', 'psych-rock', 'punk',
      'punk-rock', 'r-n-b', 'rainy-day', 'reggae', 'reggaeton', 'road-trip',
      'rock', 'rock-n-roll', 'rockabilly', 'romance', 'sad', 'salsa', 'samba',
      'sertanejo', 'show-tunes', 'singer-songwriter', 'ska', 'sleep',
      'songwriter', 'soul', 'soundtracks', 'spanish', 'study', 'summer',
      'swedish', 'synth-pop', 'tango', 'techno', 'trance', 'trip-hop',
      'turkish', 'work-out', 'world-music'
    };
    
    // Convert themes to lowercase and find matches
    final lowercaseThemes = themes.map((theme) => theme.toLowerCase()).toList();
    return lowercaseThemes.where((theme) => validSpotifyGenres.contains(theme)).toList();
  }

  List<dynamic> _getFallbackSongs() {
    // Return fallback songs if Spotify API fails
    return [
      {
        'name': 'Calm Meditation',
        'artists': [{'name': 'Meditation Masters'}],
        'album': {'images': [{'url': 'https://placehold.co/150x150/2196F3/white?text=Meditation'}]},
        'external_urls': {'spotify': 'https://open.spotify.com'},
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      },
      {
        'name': 'Peaceful Mind',
        'artists': [{'name': 'Relaxation Sounds'}],
        'album': {'images': [{'url': 'https://placehold.co/150x150/2196F3/white?text=Relaxation'}]},
        'external_urls': {'spotify': 'https://open.spotify.com'},
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      },
      {
        'name': 'Stress Relief',
        'artists': [{'name': 'Calming Waves'}],
        'album': {'images': [{'url': 'https://placehold.co/150x150/2196F3/white?text=Calm'}]},
        'external_urls': {'spotify': 'https://open.spotify.com'},
        'preview_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      },
    ];
  }

  List<String> _extractThemesFromUserData() {
    final themes = <String>[];
    
    // Extract themes from mental condition
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
    
    // Extract from interests
    if (userData['interests'] != null) {
      final interests = userData['interests'];
      if (interests['topics'] != null) {
        if (interests['topics'].toString().contains('Friendship')) themes.add('friendship');
        if (interests['topics'].toString().contains('mental health')) themes.add('mental health');
        if (interests['topics'].toString().contains('conflict resolution')) themes.add('conflict resolution');
      }
      if (interests['medication'] != null) {
        themes.add('mental health medication');
      }
    }
    
    // Extract from dislikes
    if (userData['dislikes'] != null) {
      final dislikes = userData['dislikes'];
      if (dislikes['situations']?.toString().contains('bored') ?? false) {
        themes.add('overcoming boredom');
      }
      if (dislikes['situations']?.toString().contains('quarreling') ?? false) {
        themes.add('conflict resolution');
      }
    }
    
    // Extract from preferences
    if (userData['preferences'] != null) {
      final preferences = userData['preferences'];
      if (preferences['other']?.toString().contains('friendship recovery') ?? false) {
        themes.add('friendship repair');
      }
    }
    
    // Add some default themes if not enough
    if (themes.length < 3) {
      themes.addAll(['mindfulness', 'emotional wellness', 'self-care']);
    }
    
    return themes;
  }

  List<String> _extractMusicThemesFromUserData() {
    final musicThemes = <String>[];
    
    // Extract music preferences based on user's mental state
    if (userData['mental_condition'] != null) {
      final mentalCondition = userData['mental_condition'];
      
      if (mentalCondition['anger'] != null) {
        musicThemes.addAll(['ambient', 'classical']);
      }
      if (mentalCondition['anxiety_triggers'] != null) {
        musicThemes.addAll(['ambient', 'chill']);
      }
      if (mentalCondition['self_worth']?.toString().contains('Low') ?? false) {
        musicThemes.addAll(['pop', 'happy']);
      }
      if (mentalCondition['suicidal_ideation'] != null) {
        musicThemes.addAll(['meditation', 'ambient']);
      }
      if (mentalCondition['mood_patterns']?.toString().contains('mood swings') ?? false) {
        musicThemes.addAll(['classical', 'jazz']);
      }
      if (mentalCondition['stress_indicators']?.toString().contains('High') ?? false) {
        musicThemes.addAll(['ambient', 'piano']);
      }
    }
    
    // Add some default themes if not enough
    if (musicThemes.isEmpty) {
      musicThemes.addAll(['ambient', 'meditation', 'chill']);
    }
    
    return musicThemes.take(2).toList(); // Spotify allows up to 5 seed values, but we'll use 2
  }

  String _createExercisePrompt() {
    return """
Based on the following user profile, suggest 4-6 personalized mental health exercises. 
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

  List<dynamic> _parseExerciseResponse(String text) {
    try {
      // Extract JSON from the response
      final startIndex = text.indexOf('[');
      final endIndex = text.lastIndexOf(']') + 1;
      final jsonString = text.substring(startIndex, endIndex);
      
      return json.decode(jsonString);
    } catch (e) {
      // Fallback exercises if parsing fails
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

  void _openBookPreview(book) {
    // Extract preview link if available
    final previewLink = book['volumeInfo']?['previewLink'];
    final title = book['volumeInfo']?['title'] ?? 'Book Preview';
    
    if (previewLink != null) {
      // Navigate to the book preview screen
      Navigator.pushNamed(
        context, 
        '/book_preview', 
        arguments: {'url': previewLink, 'title': title}
      );
    } else {
      // Show a dialog if no preview is available
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview Not Available'),
          content: Text('Sorry, no preview is available for "$title".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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
      // Use url_launcher to open the URL
      if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
        await launchUrl(Uri.parse(spotifyUrl));
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Cannot Open $songName'),
            content: const Text('Please install Spotify to open this song.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Spotify Link Available'),
          content: Text('Sorry, no Spotify link is available for "$songName".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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
          title: const Text('Preview Not Available'),
          content: const Text('Sorry, no preview is available for this song.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }

    if (currentlyPlayingIndex == index && playerState == PlayerState.playing) {
      // Pause if this song is already playing
      await audioPlayer.pause();
      setState(() {
        playerState = PlayerState.paused;
      });
    } else if (currentlyPlayingIndex == index && playerState == PlayerState.paused) {
      // Resume if this song is paused
      await audioPlayer.resume();
      setState(() {
        playerState = PlayerState.playing;
      });
    } else {
      // Stop any currently playing song and play this one
      if (currentlyPlayingIndex != null) {
        await audioPlayer.stop();
      }
      
      await audioPlayer.play(UrlSource(previewUrl));
      setState(() {
        currentlyPlayingIndex = index;
        playerState = PlayerState.playing;
      });
      
      // Listen for completion
      audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          playerState = PlayerState.stopped;
          currentlyPlayingIndex = null;
        });
      });
    }
  }

  // Helper method to safely extract artist names
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
      print('Error parsing artists: $e');
      return 'Unknown Artist';
    }
  }

  // Helper method to safely extract image URL
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
      print('Error parsing image URL: $e');
      return '';
    }
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
              // Top Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue, width: 2),
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

              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (errorMessage != null)
                Expanded(
                  child: Center(
                    child: Text(errorMessage!),
                  ),
                )
              else
                Expanded(
                  child: DefaultTabController(
                    length: 3, // Changed from 2 to 3 for the new tab
                    child: Column(
                      children: [
                        const TabBar(
                          indicatorColor: Colors.blueAccent,
                          labelColor: Colors.black,
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            Tab(text: 'Book Recommendations'),
                            Tab(text: 'Mental Exercises'),
                            Tab(text: 'Music Recommendations'), // New tab
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Books Tab
                              ListView.builder(
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
                                        color: Colors.white70,
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
                                              child: const Icon(Icons.book, size: 60, color: Colors.grey),
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
                                              backgroundColor: Colors.blueAccent,
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
                              ),

                              // Exercises Tab
                              ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                itemCount: exerciseRecommendations.length,
                                itemBuilder: (context, index) {
                                  final exercise = exerciseRecommendations[index];
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white70,
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
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              exercise['description'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    exercise['duration'] ?? '',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              // Music Recommendations Tab (New)
                              ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                itemCount: songRecommendations.length,
                                itemBuilder: (context, index) {
                                  final song = songRecommendations[index];
                                  final title = song['name']?.toString() ?? 'Unknown Song';
                                  final artists = _getArtistNames(song['artists']);
                                  final thumbnail = _getImageUrl(song['album']);
                                  final previewUrl = song['preview_url'];
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white70,
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
                                                    child: const Icon(Icons.music_note, size: 60, color: Color.fromARGB(255, 9, 201, 57)),
                                                  );
                                                },
                                              ),
                                            )
                                          else
                                            Container(
                                              height: 180,
                                              width: double.infinity,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.music_note, size: 60, color: Color.fromARGB(255, 9, 201, 57)),
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
                                              // Play/Pause button
                                              IconButton(
                                                icon: Icon(
                                                  currentlyPlayingIndex == index && playerState == PlayerState.playing 
                                                      ? Icons.pause_circle_filled 
                                                      : Icons.play_circle_filled,
                                                  size: 36,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () => _playPauseSong(index, previewUrl),
                                              ),
                                              // Spotify button
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.open_in_new,
                                                  size: 30,
                                                  color: Colors.green,
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  border: Border(
                    top: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, size: 30, color: Colors.black),
                      onPressed: () {Navigator.pushNamed(context, '/home');},
                    ),
                    GestureDetector(
                      onTap: () {Navigator.pushNamed(context, '/chat');},
                      child: Image.asset(
                        'assets/icons/4616759.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 30, color: Colors.black),
                      onPressed: () {Navigator.pushNamed(context, '/profile');},
                    ),
                    IconButton(
                      icon: const Icon(Icons.people, size: 30, color: Colors.black),
                      onPressed: () {Navigator.pushNamed(context, '/pro');},
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