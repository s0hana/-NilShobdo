import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> settingsOptions = [
      {"icon": Icons.settings, "title": "Settings", "route": "/general"},
      {"icon": Icons.notifications, "title": "Notifications", "route": "/notifications"},
      {"icon": Icons.color_lens, "title": "Appearance", "route": "/appearance"},
      {"icon": Icons.help_outline, "title": "Help & Support", "route": "/help"},
      {"icon": Icons.lock_outline, "title": "Privacy & Safety", "route": "/privacy"},
      {"icon": Icons.info_outline, "title": "About", "route": "/about"},
    ];

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
              // 🔹 Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      icon: const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/note");
                      },
                    ),
                   
                    const Text(
                      "Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 28, color: Colors.black),
                      onPressed: () {
                        
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 Settings List
              Expanded(
                child: ListView.builder(
                  itemCount: settingsOptions.length,
                  itemBuilder: (context, index) {
                    final option = settingsOptions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(option["icon"], color: Colors.blue),
                        title: Text(
                          option["title"],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pushNamed(context, option["route"]);
                        },
                      ),
                    );
                  },
                ),
              ),

              // 🔹 Bottom Bar
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
                    GestureDetector(
                      onTap: ()
                      {
                        Navigator.pushNamed(context, '/chat');
                      },
                    
                    child: Image.asset(
                      'assets/icons/4616759.png',
                      height: 30,
                      width: 30,
                      color: Colors.black,
                    ),

                    ),
                    IconButton(
                      icon: const Icon(Icons.fitness_center, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/exercise");
                      },
                    ),
                    
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/profile");
                      },
                    ),
                    GestureDetector(
                      onTap: ()
                      {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Image.asset(
                      'assets/icons/a.png',
                      height: 30,
                      width: 30,
                      color: Colors.black,
                    ),
                    )
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

// 🔹 Dummy Pages for Navigation
class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          "This is the $title Page",
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        "/": (context) => const SettingsScreen(),
        "/menu": (context) => const DummyPage(title: "Menu"),
        "/general": (context) => const DummyPage(title: "General Settings"),
        "/notifications": (context) => const DummyPage(title: "Notifications"),
        "/appearance": (context) => const DummyPage(title: "Appearance"),
        "/help": (context) => const DummyPage(title: "Help & Support"),
        "/privacy": (context) => const DummyPage(title: "Privacy & Safety"),
        "/about": (context) => const DummyPage(title: "About"),
        "/home": (context) => const DummyPage(title: "Home"),
        "/exercise": (context) => const DummyPage(title: "Exercise"),
        "/chat": (context) => const DummyPage(title: "Chat"),
        "/profile": (context) => const DummyPage(title: "Profile"),
      },
    );
  }
}
