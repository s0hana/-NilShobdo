import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisTimeManager {
  static const String _selectedTimeKey = 'selected_analysis_time';
  static const int _defaultTimeInMinutes = 60; // Default: 1 hour

  // Available time options for analysis
  static final List<AnalysisTimeOption> timeOptions = [
    AnalysisTimeOption('30 Minutes', 30),
    AnalysisTimeOption('1 Hour', 60),
    AnalysisTimeOption('2 Hours', 120),
    AnalysisTimeOption('6 Hours', 360),
    AnalysisTimeOption('12 Hours', 720),
    AnalysisTimeOption('1 Day', 1440),
    AnalysisTimeOption('2 Days', 2880),
    AnalysisTimeOption('3 Days', 4320),
    AnalysisTimeOption('5 Days', 7200),
  ];

  // Get currently selected time in minutes
  static Future<int> getSelectedTimeInMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedTimeKey) ?? _defaultTimeInMinutes;
  }

  // Set selected time in minutes
  static Future<void> setSelectedTimeInMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTimeKey, minutes);
  }

  // Get currently selected time option
  static Future<AnalysisTimeOption> getSelectedTimeOption() async {
    final selectedMinutes = await getSelectedTimeInMinutes();
    return timeOptions.firstWhere(
      (option) => option.minutes == selectedMinutes,
      orElse: () => timeOptions[1], // Default to 1 hour
    );
  }

  // Check if a timestamp is within the selected analysis time range
  static Future<bool> isWithinAnalysisTimeRange(int timestamp) async {
    final selectedMinutes = await getSelectedTimeInMinutes();
    final cutoffTime = DateTime.now().subtract(Duration(minutes: selectedMinutes));
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return messageTime.isAfter(cutoffTime);
  }

  // Get cutoff timestamp for analysis
  static Future<int> getCutoffTimestamp() async {
    final selectedMinutes = await getSelectedTimeInMinutes();
    final cutoffTime = DateTime.now().subtract(Duration(minutes: selectedMinutes));
    return cutoffTime.millisecondsSinceEpoch;
  }

  // Format minutes to readable text
  static String formatMinutesToText(int minutes) {
    if (minutes < 60) {
      return '$minutes Minutes';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '$hours Hour${hours > 1 ? 's' : ''}';
    } else {
      final days = minutes ~/ 1440;
      return '$days Day${days > 1 ? 's' : ''}';      
    }
  }
}

class AnalysisTimeOption {
  final String label;
  final int minutes;

  AnalysisTimeOption(this.label, this.minutes);

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisTimeOption &&
          runtimeType == other.runtimeType &&
          minutes == other.minutes;

  @override
  int get hashCode => minutes.hashCode;
}

// Settings UI for selecting analysis time
class AnalysisTimeSettingsDialog extends StatefulWidget {
  final Color primaryColor;

  const AnalysisTimeSettingsDialog({super.key, required this.primaryColor});

  @override
  State<AnalysisTimeSettingsDialog> createState() => _AnalysisTimeSettingsDialogState();
}

class _AnalysisTimeSettingsDialogState extends State<AnalysisTimeSettingsDialog> {
  late AnalysisTimeOption _selectedOption;

  @override
  void initState() {
    super.initState();
    _loadSelectedOption();
  }

  Future<void> _loadSelectedOption() async {
    final selected = await AnalysisTimeManager.getSelectedTimeOption();
    setState(() {
      _selectedOption = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Chat Analysis Time Range',
        style: TextStyle(
          color: widget.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: AnalysisTimeManager.timeOptions.length,
          itemBuilder: (context, index) {
            final option = AnalysisTimeManager.timeOptions[index];
            return RadioListTile<AnalysisTimeOption>(
              title: Text(option.label),
              value: option,
              groupValue: _selectedOption,
              onChanged: (AnalysisTimeOption? value) {
                if (value != null) {
                  setState(() {
                    _selectedOption = value;
                  });
                }
              },
              activeColor: widget.primaryColor,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await AnalysisTimeManager.setSelectedTimeInMinutes(_selectedOption.minutes);
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}