import 'package:flutter/material.dart';
import 'theme_manager.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedTheme();
  }

  Future<void> _loadSelectedTheme() async {
    final index = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _selectedThemeIndex = index;
    });
  }

  Future<void> _selectTheme(int index) async {
    await ThemeManager.saveSelectedTheme(index);
    setState(() {
      _selectedThemeIndex = index;
    });
    

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ThemeManager.colorThemes[index].name} has been selected.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ThemeManager.getCurrentTheme(_selectedThemeIndex);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [currentTheme.gradientStart, currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: currentTheme.primary, width: 2),
                  ),
                  color: currentTheme.primary,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Appearance Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Current Theme Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Current Theme: ${currentTheme.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Preview of the theme
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [currentTheme.gradientStart, currentTheme.gradientEnd],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: currentTheme.primary),
                          ),
                          child: Center(
                            child: Text(
                              'Preview',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Theme Selection List
              Expanded(
                child: ListView.builder(
                  itemCount: ThemeManager.colorThemes.length,
                  itemBuilder: (context, index) {
                    final theme = ThemeManager.colorThemes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.gradientStart, theme.gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          theme.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Primary: ${theme.primary.value.toRadixString(16)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _selectedThemeIndex == index
                            ? Icon(Icons.check_circle, color: theme.primary)
                            : Icon(Icons.radio_button_unchecked, color: Colors.grey),
                        onTap: () => _selectTheme(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}