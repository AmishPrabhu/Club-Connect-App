import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class InstitutionSettingsScreen extends StatefulWidget {
  const InstitutionSettingsScreen({super.key});

  @override
  State<InstitutionSettingsScreen> createState() => _InstitutionSettingsScreenState();
}

class _InstitutionSettingsScreenState extends State<InstitutionSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedThemeColor = '#002147'; // Default Navy
  bool _enableEmailRouting = true;
  bool _isLoading = true;

  final Map<String, String> _colorOptions = {
    '#002147': 'Navy Blue (WCE Standard)',
    '#b71c1c': 'Crimson Red (WCE Legacy Red)',
    '#1b5e20': 'Forest Green',
    '#311b92': 'Deep Purple',
    '#006064': 'Teal',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('inst_name') ?? 'Walchand College of Engineering';
      _emailController.text = prefs.getString('inst_email') ?? 'director@walchandsangli.ac.in';
      _selectedThemeColor = prefs.getString('inst_theme_color') ?? '#002147';
      _enableEmailRouting = prefs.getBool('inst_email_routing') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inst_name', _nameController.text.trim());
    await prefs.setString('inst_email', _emailController.text.trim());
    await prefs.setString('inst_theme_color', _selectedThemeColor);
    await prefs.setBool('inst_email_routing', _enableEmailRouting);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Institution configurations saved successfully! Restart app to apply theme.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institution Settings'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business_rounded, color: AppTheme.blue),
                      SizedBox(width: 8),
                      Text(
                        'Institution Branding',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Institution Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Theme Branding Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedThemeColor,
                        isExpanded: true,
                        items: _colorOptions.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(entry.key.replaceAll('#', '0xff'))),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(entry.value),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedThemeColor = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Email & Routing Config Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, color: AppTheme.blue),
                      SizedBox(width: 8),
                      Text(
                        'Global Communication Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Primary Support Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text('Enable Automated Event Updates'),
                    subtitle: const Text('Send emails to present attendees on event reports or schedule changes.'),
                    value: _enableEmailRouting,
                    activeColor: AppTheme.blue,
                    onChanged: (val) => setState(() => _enableEmailRouting = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Save actions
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save configurations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
