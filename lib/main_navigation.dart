// lib/main_navigation.dart

import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/records_page.dart';
import 'pages/setting_page.dart';
import 'pages/about_page.dart';
import 'pages/vacations.dart';
import 'package:easy_localization/easy_localization.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // List of pages corresponding to each tab
  final List<Widget> _pages = [
    HomePage(),
    VacationsPage(),
    RecordsPage(),
    SettingPage(),
    AboutPage(),
  ];

  // List of BottomNavigationBar items
  final List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.beach_access),
      label: 'Vacations'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list),
      label: 'Records'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings),
      label: 'Settings'.tr(),
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.info),
      label: 'About'.tr(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Display the selected page
      body: _pages[_currentIndex],
      // Bottom Navigation Bar with shadow
      bottomNavigationBar: Material(
        elevation: 14.0, // Adds the shadow effect
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          items: _navItems,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Color(0xFF007AFF),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
