import 'package:flutter/material.dart';
import 'theme_manager.dart'; // Theme manager import করুন

class MentalHealthProfessionalsPage extends StatefulWidget {
  const MentalHealthProfessionalsPage({super.key});

  @override
  State<MentalHealthProfessionalsPage> createState() => _MentalHealthProfessionalsPageState();
}

class _MentalHealthProfessionalsPageState extends State<MentalHealthProfessionalsPage> {
  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  // Dummy professional list
  final List<Map<String, dynamic>> professionals = [
    {
      "photo": "assets/gtp.png",
      "name": "Dr. Sarah Khan",
      "specialization": "Clinical Psychologist",
      "description": "Expert in anxiety and depression management.",
      "contact": "01711111111",
      "experience": "8 years",
      "rating": "4.8",
    },
    {
      "photo": "assets/gtp.png",
      "name": "Dr. Amin Rahman",
      "specialization": "Psychotherapist",
      "description": "Focus on cognitive behavioral therapy (CBT).",
      "contact": "01711111111",
      "experience": "6 years",
      "rating": "4.7",
    },
    {
      "photo": "assets/gtp.png",
      "name": "Dr. Fatima Noor",
      "specialization": "Child Psychologist",
      "description": "Specializes in child and adolescent mental health.",
      "contact": "01711111111",
      "experience": "10 years",
      "rating": "4.9",
    },
    {
      "photo": "assets/gtp.png",
      "name": "Dr. Aklima Akter",
      "specialization": "Child Psychologist",
      "description": "Focus on cognitive behavioral therapy (CBT).",
      "contact": "01711111111",
      "experience": "7 years",
      "rating": "4.6",
    },
    {
      "photo": "assets/gtp.png",
      "name": "Dr. Rahim Islam",
      "specialization": "Family Therapist",
      "description": "Specializes in family and relationship counseling.",
      "contact": "01711111111",
      "experience": "9 years",
      "rating": "4.8",
    },
    {
      "photo": "assets/gtp.png",
      "name": "Dr. Nusrat Jahan",
      "specialization": "Trauma Specialist",
      "description": "Expert in PTSD and trauma recovery.",
      "contact": "01711111111",
      "experience": "12 years",
      "rating": "4.9",
    },
  ];

  void _showProfessionalDetails(Map<String, dynamic> professional) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.containerColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage(professional["photo"]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional["name"],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          professional["specialization"],
                          style: TextStyle(
                            fontSize: 16,
                            color: _currentTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              professional["rating"],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.work, color: _currentTheme.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(professional["experience"]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "About",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                professional["description"],
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                "Contact Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone, color: _currentTheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    professional["contact"],
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.email, color: _currentTheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    "contact@mentalhealth.com",
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showContactDialog(professional);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Contact Professional",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showContactDialog(Map<String, dynamic> professional) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Contact ${professional["name"]}",
            style: TextStyle(
              color: _currentTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Phone: ${professional["contact"]}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Email: contact@mentalhealth.com",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                "Please be respectful and professional when contacting mental health professionals.",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: TextStyle(
                  color: _currentTheme.primary,
                ),
              ),
            ),
          ],
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
              // 🔹 Top Bar with theme colors
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _currentTheme.primary, width: 2)),
                  color: _currentTheme.primary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      "Meet Professionals",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, size: 28, color: Colors.black),
                      onPressed: () {
                        // Implement search functionality
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Header Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _currentTheme.containerColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _currentTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 40,
                        color: _currentTheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Professional Support",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _currentTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Connect with qualified mental health professionals for personalized support",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🔹 Scrollable Professionals List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final prof = professionals[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: _currentTheme.containerColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: _currentTheme.primary.withOpacity(0.1),
                              backgroundImage: AssetImage(prof["photo"]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prof["name"],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    prof["specialization"],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _currentTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    prof["description"],
                                    style: const TextStyle(fontSize: 14, height: 1.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        prof["rating"],
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.work, color: _currentTheme.primary, size: 16),
                                      const SizedBox(width: 4),
                                      Text(prof["experience"]),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: _currentTheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        prof["contact"],
                                        style: const TextStyle(fontSize: 14),
                                      ),
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

              // 🔹 Bottom Bar with theme colors
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _currentTheme.primary, width: 2)),
                  color: _currentTheme.primary,
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
                      onTap: () {
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