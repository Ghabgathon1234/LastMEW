import 'package:flutter/material.dart';
import 'package:mew_shifts/main_navigation.dart';
import 'package:mew_shifts/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../notifiers/theme_notifier.dart';
import 'package:provider/provider.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String? _selectedTeam;
  String? _tempselectedTeam;
  String? _selectedLocation;
  String? _tempselectedLocation;
  String? _selectedLanguage;
  String? _tempselectedLanguage;
  bool? _isDarkMode;
  bool _isLoading = true;
  

  final List<String> _teams = ['A', 'B', 'C', 'D'];
  final List<String> _locations = [
    'Alsabbiyah Powerplant',
    'East Doha Powerplant',
    'West Doha Powerplant',
    'Alshuwaikh Powerplant',
    'Shuaibah Powerplant',
    'Alzour Powerplant',
  ];

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English'},
    {'code': 'ar', 'label': 'Arabic'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs =await SharedPreferences.getInstance();
    setState(() {
      //if(_selectedTeam!=null && _selectedLocation!=null){
        _selectedTeam = prefs.getString('team') ?? _teams.first;
        _selectedLocation = prefs.getString('location') ?? _locations.first;
        _tempselectedTeam=_selectedTeam;
      //}
      _selectedLanguage = prefs.getString('language') ?? 'en';
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      //_tempisDarkMode=_isDarkMode;
      //_tempselectedLanguage=_selectedLanguage;
      
      _tempselectedLocation=_selectedLocation;
      _isLoading=false;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {

   
    if(_selectedLocation!=_tempselectedLocation){
      _selectedLocation=_tempselectedLocation;
    }
    if(_selectedTeam!=_tempselectedTeam){
      _selectedTeam=_tempselectedTeam;
    }
    });
    if(_selectedTeam!=null){  
      await prefs.setString('team', _selectedTeam!);
    }
    if(_selectedLocation!=null){
      await prefs.setString('location', _selectedLocation!);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved successfully!').tr()),);

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>MainNavigation()));

      //Navigator.push(context, MaterialPageRoute(builder: (context)=> HomePage()));
  }

  void _changeDarkmode()async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if(_isDarkMode!=null) {
    await prefs.setBool('darkMode',_isDarkMode!);
    }

  }

  void _changeLanguage(String languageCode)async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (languageCode == 'ar') {
      context.setLocale(const Locale('ar', 'AR'));
    } else {
      context.setLocale(const Locale('en', 'US'));
    }
    if(_tempselectedLanguage !=null){
      setState(() {
        _selectedLanguage=_tempselectedLanguage;
      });
    }
    if(_selectedLanguage !=null){
    await prefs.setString('language', _selectedLanguage!);
    
    }
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if(_isLoading){
      return Scaffold(
        appBar: AppBar(
          title: Text('Settings'.tr())),
          body: Center(child: CircularProgressIndicator(),),
          
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings'.tr(),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'App Settings'.tr(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Card for all dropdowns
            _buildCard(
              child: Column(
                children: [
                  // Team Selection
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: 'Select Team'.tr(),
                      labelStyle: TextStyle(color: Colors.grey),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey,
                        )
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey
                        )
                      )
                    ),
                  
                   
                    value: _tempselectedTeam ,
                    items: _teams.map((team) {
                      return DropdownMenuItem(
                        value: team ,
                        child: Text(tr('Team $team')),

                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _tempselectedTeam = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Location Selection
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: 'Select Location'.tr(),
                       labelStyle: TextStyle(color: Colors.grey),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey,
                        )
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey
                        )
                      )
                    ),
                    value: _selectedLocation,
                    items: _locations.map((location) {
                      String translatedLocation =
                          _getTranslatedLocation(location);
                      return DropdownMenuItem(
                        
                        value: location,
                        child: Text(translatedLocation),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _tempselectedLocation = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Language Selection
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).cardColor,
                    decoration: InputDecoration(
                      labelText: 'Change Language'.tr(),
                       labelStyle: TextStyle(color: Colors.grey),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey,
                        )
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey
                        )
                      ) 
                    ),
                    value: _selectedLanguage,
                    items: _languages.map((language) {
                      return DropdownMenuItem(
                        value: language['code'],
                        child: Text(tr(language['label']!)),
                      );
                    })
                    .toList(),
                    onChanged: (value) {
                      setState(() {
                        _tempselectedLanguage= value!;
                      });
                      _changeLanguage(value!);
                      
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildCard(child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dark Mode'.tr(),
                style: const TextStyle(fontSize: 16),),
                Switch(value: _isDarkMode ?? true, onChanged: (value){setState(() {
                  if(value ==true) {
                    _isDarkMode = true;
                  } else {
                    _isDarkMode=false;
                  }
                  final themeNotifier = Provider.of<ThemeNotifier>(context,listen: false);
                  themeNotifier.switchTheme(_isDarkMode! ? AppThemes.darkTheme : AppThemes.lightTheme);
                  _changeDarkmode();
                  //themeNotifier.switchTheme(value ? AppThemes.darkTheme : AppThemes.lightTheme,);
                });},activeColor: Color(0xFF007AFF),inactiveThumbColor: Color(0xFF007AFF),
                activeTrackColor: Color.fromARGB(255, 172, 212, 255),)
              ],
            )
            ),
            const SizedBox(height: 30,),

            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  backgroundColor: Theme.of(context).hintColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Save Settings'.tr(),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to create a card
  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 3,
      color: Theme.of(context).cardColor,
      shadowColor: Theme.of(context).shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  // Helper method for translated location names
  String _getTranslatedLocation(String location) {
    switch (location) {
      case 'Alsabbiyah Powerplant':
        return 'alsabbiyah'.tr();
      case 'East Doha Powerplant':
        return 'east_doha'.tr();
      case 'West Doha Powerplant':
        return 'west_doha'.tr();
      case 'Alshuwaikh Powerplant':
        return 'alshuwaikh'.tr();
      case 'Shuaibah Powerplant':
        return 'shuaibah'.tr();
      case 'Alzour Powerplant':
        return 'alzour'.tr();
      default:
        return location.tr();
    }
  }
}
