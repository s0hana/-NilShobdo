import 'package:flutter/material.dart';

class MotivationScreen extends StatelessWidget {
  const MotivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy Motivational Quotes
    final List<Map<String, String>> quotes = [
      {
        "text": "Believe in yourself and all that you are.",
        "time": "10:30 AM",
        "date": "18 Aug 2025"
      },
      {
        "text": "Every day is a second chance.",
        "time": "08:15 AM",
        "date": "18 Aug 2025"
      },
      {
        "text": "Push yourself, because no one else will do it for you.",
        "time": "09:00 PM",
        "date": "17 Aug 2025"
      },
      {
        "text": "Small steps every day lead to big results.",
        "time": "05:45 PM",
        "date": "17 Aug 2025"
      },
      {
        "text": "Your only limit is your mind.",
        "time": "04:20 PM",
        "date": "16 Aug 2025"
      },
      {
        "text": "Your only limit is your mind.",
        "time": "04:20 PM",
        "date": "15 Aug 2025"
      },
      {
        "text": "Small steps every day lead to big results.",
        "time": "04:00 AM",
        "date": "15 Aug 2025"
      },
      {
        "text": "Your password was changed.",
        "time": "12:20 AM",
        "date": "14 Aug 2025"
      },
      {
        "text": "Welcome to Nilshobdo! We are here to support you.",
        "time": "1:30 AM",
        "date": "13 Aug 2025"
      },
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
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                    Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Icon(Icons.more_vert, size: 28, color: Colors.black),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Quotes List (Scrollable)
              Expanded(
                child: ListView.builder(
                  itemCount: quotes.length,
                  itemBuilder: (context, index) {
                    final quote = quotes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(2, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "“${quote["text"]}”",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "${quote["time"]} | ${quote["date"]}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                    IconButton(
                      icon: const Icon(Icons.home, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                    ),
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
                      icon: const Icon(Icons.account_circle_outlined,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
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
