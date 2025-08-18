import 'package:flutter/material.dart';

class MentalHealthProfessionalsPage extends StatelessWidget {
  const MentalHealthProfessionalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy professional list
    final List<Map<String, dynamic>> professionals = [
      {
        "photo": "assets/gtp.png",
        "name": "Dr. Sarah Khan",
        "specialization": "Clinical Psychologist",
        "description": "Expert in anxiety and depression management.",
        "contact": "01711111111"
      },
      {
        "photo": "assets/gtp.png",
        "name": "Dr. Amin Rahman",
        "specialization": "Psychotherapist",
        "description": "Focus on cognitive behavioral therapy (CBT).",
        "contact": "01711111111"
      },
      {
        "photo": "assets/gtp.png",
        "name": "Dr. Fatima Noor",
        "specialization": "Child Psychologist",
        "description": "Specializes in child and adolescent mental health.",
        "contact": "01711111111"
      },
      {
        "photo": "assets/gtp.png",
        "name": "Dr. Aklima Akter",
        "specialization": "Child Psychologist",
        "description": "Focus on cognitive behavioral therapy (CBT).",
        "contact": "01711111111"
      },
      {
        "photo": "assets/gtp.png",
        "name": "Dr. Fatima Noor",
        "specialization": "Child Psychologist",
        "description": "Specializes in child and adolescent mental health.",
        "contact": "01711111111"
      },
      {
        "photo": "assets/gtp.png",
        "name": "Dr. Fatima Noor",
        "specialization": "Child Psychologist",
        "description": "Specializes in child and adolescent mental health.",
        "contact": "01711111111"
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.blue, width: 2)),
                  color: Color(0xFF2196F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/settings");
                      },
                    ),
                    const Text(
                      "Meet Professionals",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 28, color: Colors.black),
                      onPressed: () {
                        
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Scrollable Professionals List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final prof = professionals[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: AssetImage(prof["photo"]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prof["name"],
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    prof["specialization"],
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    prof["description"],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.email, size: 16, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(prof["contact"], style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
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
                  border: Border(top: BorderSide(color: Colors.blue, width: 2)),
                  color: Color(0xFF2196F3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/home");
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
