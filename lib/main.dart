import 'package:flutter/material.dart';
import 'package:mew_shifts/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'pages/setting_page.dart';
import 'main_navigation.dart';
import 'database_helper.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'theme.dart';
import 'notifiers/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeNotifier = ThemeNotifier(AppThemes.lightTheme);
  await themeNotifier.loadTheme();

  await LocalNotificationService.init();

  // Initialize WorkManager for background tasks
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  tz.initializeTimeZones();

  // Ensure EasyLocalization is initialized
  await EasyLocalization.ensureInitialized();

  runApp(
    
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'AR')],
      path: 'assets/translations', // Path to the translation files
      fallbackLocale: const Locale('en', 'US'),
      child:
    ChangeNotifierProvider(create: (context) => themeNotifier,
      child: const MyApp(),),),
  );
}

// Callback function for WorkManager to handle background tasks
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Check for missed attendance and mark as absent if needed
    Future<void> checkAndMarkAbsentees() async {
      DatabaseHelper dbHelper = DatabaseHelper();
      DateTime now = DateTime.now();

      // Assuming DayRecord is defined and imported
      List<DayRecord> records =
          await dbHelper.getAllRecordsForDate(now.year, now.month, now.day);

      for (DayRecord record in records) {
        if (record.status == 'onDuty' && record.attend1 == null) {
          DateTime shiftEnd = (record.shift == 'day')
              ? DateTime(now.year, now.month, now.day, 19, 0)
              : DateTime(now.year, now.month, now.day + 1, 7, 0);

          if (now.isAfter(shiftEnd)) {
            record.status = "absent";
            await dbHelper.insertOrUpdateDayRecord(record);
          }
        }
      }
    }

    await checkAndMarkAbsentees();
    return Future.value(true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    EasyLocalization.of(context)!.setLocale(newLocale);
  }
  

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      title: 'Shift Manager',
      theme: themeNotifier.currentTheme,
      home: const Initializer(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routes: {
        '/setup': (context) => const SettingPage(),
        '/main': (context) => const MainNavigation(),
      },
    );
  }
}

class Initializer extends StatefulWidget {
  const Initializer({super.key});

  @override
  _InitializerState createState() => _InitializerState();
}

class _InitializerState extends State<Initializer> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? hasLaunched = prefs.getBool('hasLaunched');

    if (hasLaunched == null || hasLaunched == false) {
      // Show the informational dialog about offline mode
      await _showOfflineModeDialog();

      // Show the notification permission request dialog after the informational dialog
      await Future.delayed(
          Duration(milliseconds: 500)); // Optional delay between dialogs
      await _showNotificationPermissionDialog();

      // Set the 'hasLaunched' flag to true after the first launch
      await prefs.setBool('hasLaunched', true);
    }

    setState(() {
      _isFirstLaunch = hasLaunched == null || hasLaunched == false;
      _isLoading = false;
    });
  }

  Future<void> _showOfflineModeDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(textDirection: ui.TextDirection.rtl, 
              child:
        AlertDialog(
          backgroundColor: Colors.white,
          title: Text('تنبيه هام').tr(),
          content: Text('note_lunch').tr(),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                
              },
              style: TextButton.styleFrom(
            foregroundColor: Color(0xFF007AFF)),
              child: Text('حسناً').tr(),
            ),
          ],
        ));
      },
    );
  }

  Future<void> _showNotificationPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enable Notifications'),
          content:
              Text('Would you like to enable notifications to stay updated?'),
              contentTextStyle: TextStyle(color: Colors.black54),
          actions: [
            TextButton(
              onPressed: () async {
                // Request permissions for notifications
                await LocalNotificationService.requestPermission();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
            foregroundColor: Color(0xFF007AFF)),
              child: Text('Enable'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
            foregroundColor: Color(0xFF007AFF)),
              child: Text('Skip'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else {
      return _isFirstLaunch ? const SettingPage() : const MainNavigation();
    }
  }
}
