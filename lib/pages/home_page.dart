// lib/pages/home_page.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database_helper.dart'; // Adjust the import path as needed
import 'package:easy_localization/easy_localization.dart'; // Add this import to use platform channels
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import '../local_notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _delayMinutes = 0; // Track the total delay for the day
  int _monthlyDelayMinutes = 0; // Initialize the variable to hold monthly delay
  String? selectedTeam;
  String? preSelectedTeam;
  String? selectedLocation;
  String? preSelectedLocation;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now(); // For multi-selection
  final Map<String, String> _shifts = {}; // Use String keys
 String _selectedDayAttendTime ='none';
 String _selectedDayPresenceTime = 'none';
 String _selectedDayLeaveTime = 'none';
  bool _canAttend = false;
  bool _canLeave = false;
  bool _isLoading = false;

  // Current shift details
  DateTime? _currentShiftDay;
  String _currentShift = 'off';

  // Variables to hold selected day's information
  String _selectedDayStatus = 'none';
  int _selectedDayDelay = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    // Initialize the database and perform setup tasks
    _initializeDatabase().then((_) {
      _determineCurrentShift();
      _fetchMonthlyDelay();
      _updateButtonStates();
      _selectedDay = DateTime.now(); // Set the selected day to today by default

      // Cache day records for the current, previous, and next months
      _cacheDayRecords().then((_) {
        _fetchDayInfo(_selectedDay!).then((_) {
          setState(() {
            _isLoading =
                false; // Hide the loading spinner after all tasks are completed
          });
        });
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The app is resumed from the background, so refresh the state
      _determineCurrentShift();
      _fetchMonthlyDelay(); // Ensure monthly delay is refreshed on resume
      _updateButtonStates();
    }
  }

  Future<void> _fetchMonthlyDelay() async {
    DatabaseHelper dbHelper = DatabaseHelper();

    // Get the current year and month
    int year = _focusedDay.year;
    int formattedMonth = _focusedDay.month;

    // Fetch the monthly delay from the database using the formatted month
    int? delay = await dbHelper.getMonthlyDelay(year, formattedMonth);
    // Handle the case where the delay is null
    delay ??= 0;

    // Use a single setState to update both _monthlyDelayMinutes and _calculateShiftProgress
    setState(() {
      if (delay != null) {
        _monthlyDelayMinutes = delay;
      } // Update the state with the fetched delay
      _calculateShiftProgress(DateTime.now()); // Recalculate gauge progress
    });
    print("Fetched monthly delay: $_monthlyDelayMinutes");
  }

  // Load team and location settings
  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      selectedTeam = prefs.getString('team') ?? 'D';
      preSelectedTeam = prefs.getString('preteam') ?? 'D';
      selectedLocation = prefs.getString('location') ?? 'Alzour Powerplant';
      preSelectedLocation = prefs.getString('prelocation') ?? 'Alzour Powerplant';
    });

    if (selectedTeam != null) {
      _generateShifts();
    }
  }

  //Initialize the database
  Future<void> _initializeDatabase() async {
    DatabaseHelper dbHelper = DatabaseHelper();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    DateTime firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    DateTime today = DateTime(_focusedDay.year,_focusedDay.month,_focusedDay.day);

    YearRecord? yearRecord = await dbHelper.getYearRecord(today.year);
    if(yearRecord==null){
      await dbHelper.insertOrUpdateYearRecord(today.year, 0, 0);
    }
    MonthRecord? monthRecord = await dbHelper.getMonthRecord(today.year, today.month);
    if(monthRecord==null){
      await dbHelper.insertOrUpdateMonthRecord(today.year, today.month, 0);
    }

    if(preSelectedTeam!=null && selectedTeam!=null
      && preSelectedLocation!=null && selectedLocation!=null){
            if((preSelectedTeam!=selectedTeam)||(preSelectedLocation!=selectedLocation)){
              for (int i = 0; i < 365; i++) {
                DateTime currentDay = today.add(Duration(days: i));
                String shift = _getShiftForDay(currentDay);

                // Check if the record already exists in the database
                DayRecord? existingRecord = await dbHelper.getDayRecord(
                    currentDay.year, currentDay.month, currentDay.day);
                if (existingRecord != null) {
                  // If the record doesn't exist, create a new one
                  DayRecord newRecord = DayRecord(
                    year: currentDay.year,
                    month: currentDay.month,
                    day: currentDay.day,
                    status: 'onDuty',
                    shift: shift,
                    attend1: null,
                    attend2: null,
                    attend3: null,
                    leave1: null,
                    leave2: null,
                    delayMinutes: 0,
                  );
                  await dbHelper.insertOrUpdateDayRecord(newRecord);
                }
              }
              setState(() {
                preSelectedTeam=selectedTeam;
                preSelectedLocation=selectedLocation;
              });
              await prefs.setString('preteam', preSelectedTeam!);
              await prefs.setString('prelocation', preSelectedLocation!);
            }
          }
    // Populate the database from the 1st of the current month onward
    for (int i = -365; i < 365; i++) {
      DateTime currentDay = firstDayOfMonth.add(Duration(days: i));
      String shift = _getShiftForDay(currentDay);

      // Check if the record already exists in the database
      DayRecord? existingRecord = await dbHelper.getDayRecord(
          currentDay.year, currentDay.month, currentDay.day);
      if (existingRecord == null) {
        // If the record doesn't exist, create a new one
        DayRecord newRecord = DayRecord(
          year: currentDay.year,
          month: currentDay.month,
          day: currentDay.day,
          status: 'onDuty',
          shift: shift,
          attend1: null,
          attend2: null,
          attend3: null,
          leave1: null,
          leave2: null,
          delayMinutes: 0,
        );
        await dbHelper.insertOrUpdateDayRecord(newRecord);
      }
    }
  }

  // Generate shift cycle based on the team
  void _generateShifts() async{
    _shifts.clear();
    List<String> shiftPattern = ['day', 'night', 'off', 'off']; // Shift pattern
    DateTime baseDate = DateTime(2023, 1, 1); // Fixed base date for consistency
    DateTime today = DateTime.now();
    int teamOffset = _getTeamOffset(selectedTeam!);
    int daysSinceBase = today.difference(baseDate).inDays;

    // Calculate the shift index for today, adjusted by the team offset
    int shiftIndexToday = (daysSinceBase + teamOffset) % shiftPattern.length;

    // Generate shifts for the next 365 days
    for (int i = -365; i <= 365; i++) {
      DateTime currentDay = today.add(Duration(days: i));
      String formattedDate = currentDay.toIso8601String().split('T').first;
      int shiftIndex = (shiftIndexToday + i) % shiftPattern.length;
      if (shiftIndex < 0) shiftIndex += shiftPattern.length;
      _shifts[formattedDate] = shiftPattern[shiftIndex];
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String shiftsJson = jsonEncode(_shifts);
    await prefs.setString('shifts', shiftsJson);
  }

  int _getTeamOffset(String team) {
    if (selectedLocation! == 'Alzour Powerplant') {
      switch (team) {
        case 'D':
          return 0;
        case 'C':
          return 1;
        case 'A':
          return 2;
        case 'B':
        default:
          return 3;
      }
    } else if (selectedLocation! == 'Shuaibah Powerplant') {
      switch (team) {
        case 'C': //D
          return 0;
        case 'A': //C
          return 1;
        case 'B'://A
          return 2;
        case 'D': //B
        default:
          return 3;
      }
    } else if (selectedLocation! == 'Alshuwaikh Powerplant') {
      switch (team) {
        case 'C': //D
          return 0;
        case 'B': //C
          return 1;
        case 'D': //A
          return 2;
        case 'A': //B
        default:
          return 3;
      }
    } else if (selectedLocation! == 'West Doha Powerplant') {
      switch (team) {
        case 'C': //D
          return 0;
        case 'A': //C
          return 1;
        case 'D'://A
          return 2;
        case 'B': //B
        default:
          return 3;
      }
    } else if (selectedLocation! == 'East Doha Powerplant') {
      switch (team) {
        case 'C': //D
          return 0;
        case 'B'://C
          return 1;
        case 'D'://A
          return 2;
        case 'A'://B
        default:
          return 3;
      }
    } else if (selectedLocation! == 'Alsabbiyah Powerplant') {
      switch (team) {
        case 'C'://D
          return 0;
        case 'B'://C
          return 1;
        case 'A'://A
          return 2;
        case 'D'://B
        default:
          return 3;
      }
    } else {
      return 3;
    }
  }

  // Determine the shift for a given day using the _shifts map
  String _getShiftForDay(DateTime day) {
    String formattedDate = day.toIso8601String().split('T').first;
    return _shifts[formattedDate] ?? 'off';
  }

  // Determine the current shift based on current time
  // In-memory cache to store shift information for specific dates
  final Map<String, String> _shiftCache = {};

  void _determineCurrentShift() async {
    DateTime now = DateTime.now().toLocal();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(Duration(days: 1));

    // Check the cache for today's shift
    String todayShift;
    if (!_shiftCache.containsKey(today.toIso8601String())) {
      // If today's shift is not cached, calculate and cache it
      todayShift = _getShiftForDay(today);
      _shiftCache[today.toIso8601String()] = todayShift;
    } else {
      todayShift = _shiftCache[today.toIso8601String()]!;
    }

    // Check the cache for yesterday's shift
    String yesterdayShift;
    if (!_shiftCache.containsKey(yesterday.toIso8601String())) {
      // If yesterday's shift is not cached, calculate and cache it
      yesterdayShift = _getShiftForDay(yesterday);
      _shiftCache[yesterday.toIso8601String()] = yesterdayShift;
    } else {
      yesterdayShift = _shiftCache[yesterday.toIso8601String()]!;
    }

    // Determine the current shift based on the time and cached shift information
    if (todayShift == 'day' && now.hour >= 5 && now.hour < 21) {
      // Day shift: 5:00 AM to 9:00 PM
      _currentShiftDay = today;
      _currentShift = 'day';
    } else if ((todayShift == 'night' && now.hour >= 17) ||
        (yesterdayShift == 'night' && now.hour < 9)) {
      // Night shift: 5:00 PM to 9:00 AM next day
      _currentShiftDay = now.hour < 9 ? yesterday : today;
      _currentShift = 'night';
    } else {
      _currentShiftDay = null;
      _currentShift = 'off';
    }

    await _updateButtonStates();
  }

  Future<void> _updateButtonStates() async {
    if (_currentShift == 'off' || _currentShiftDay == null) {
      setState(() {
        _canAttend = false;
        _canLeave = false;
      });
      print('Shift is off or no current shift day found.');
      return;
    }
    DateTime now = DateTime.now();
    DateTime shiftStart;
    DateTime shiftEnd;
    // Calculate shift start and end times
    if (_currentShift == 'day') {
      shiftStart = DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
              _currentShiftDay!.day, 7, 0)
          .toLocal();
      shiftEnd =
          shiftStart.add(Duration(hours: 12)); // Day shift: 7:00 AM to 7:00 PM
    } else if (_currentShift == 'night') {
      shiftStart = DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
              _currentShiftDay!.day, 19, 0)
          .toLocal();
      shiftEnd = shiftStart
          .add(Duration(hours: 12)); // Night shift: 7:00 PM to 7:00 AM next day
    } else if (_currentShift == 'Training Course') {
      shiftStart = DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
              _currentShiftDay!.day, 8, 30)
          .toLocal();
      shiftEnd = shiftStart
          .add(Duration(hours: 4)); // Night shift: 7:00 PM to 7:00 AM next day
    } else {
      setState(() {
        _canAttend = false;
        _canLeave = false;
      });
      print('No valid shift found.');
      return;
    }

    print('Now: $now');
    print('Shift Start: $shiftStart');
    print('Shift End: $shiftEnd');

    // Fetch the existing record for the current day
    DatabaseHelper dbHelper = DatabaseHelper();
    DayRecord? existingRecord = await dbHelper.getDayRecord(
        _currentShiftDay!.year, _currentShiftDay!.month, _currentShiftDay!.day);

    // Initialize button states
    bool hasAttended1 = false;
    bool hasAttended2 = false;
    bool hasAttended3 = false;
    bool hasLeft1 = false;
    bool hasLeft2 = false;

    if (existingRecord != null) {
      if (existingRecord.status != 'onDuty') {
        _delayMinutes = 0;
        _canAttend = false;
        _canLeave = false;
        return;
      }
      print(
          'Existing Record Found: attend1=${existingRecord.attend1}, leaveTime=${existingRecord.leave1}');

      DateTime? attend1 = existingRecord.attend1 != null
          ? DateTime.parse(existingRecord.attend1!)
          : null;
      DateTime? attend2 = existingRecord.attend2 != null
          ? DateTime.parse(existingRecord.attend2!)
          : null;
      DateTime? attend3 = existingRecord.attend3 != null
          ? DateTime.parse(existingRecord.attend3!)
          : null;
      DateTime? leave1 = existingRecord.leave1 != null
          ? DateTime.parse(existingRecord.leave1!)
          : null;
      DateTime? leave2 = existingRecord.leave2 != null
          ? DateTime.parse(existingRecord.leave2!)
          : null;

      // Check if the user has attended during the current shift
      if (attend1 != null) {
        hasAttended1 = true;

        if (attend2 != null) {
          hasAttended2 = true;
        }
        if (attend2 == null &&
            now.isAfter(shiftStart.add(Duration(hours: 3)))) {
          hasAttended2 = true;
        }
      }

      // Check if the user has left during the current shift
      if (leave1 != null) {
        hasLeft1 = true;
      }
      if (attend3 != null) {
        hasAttended3 = true;
      }
      if (leave2 != null) {
        hasLeft2 = true;
      }

      // Update button states based on the current shift and the actions taken
      setState(() {
        print('Entering setState'); //..........0
        if ((!hasAttended1) &&
            (now.isAfter(shiftStart.subtract(Duration(hours: 2))) &&
                now.isBefore(shiftEnd))) {
          print('if---------1'); //..........1
          _canAttend = true; // Enable the Attend for first attendance
          _canLeave = false;
        } else if ((attend1 != null) && (!hasLeft1) && (!hasAttended2)) {
          if (now.isAfter(attend1.add(Duration(hours: 2))) &&
              now.isBefore(attend1.add(Duration(hours: 3)))) {
            //****ADD NOTIFICATION *****/
            print('if---------2'); //..........2
            _canAttend = true; // Enable the Attend for first attendance
            _canLeave = false;
          }
        } else if ((hasAttended2) &&
            (!hasLeft1) &&
            (now.isBefore(shiftEnd.add(Duration(hours: 2))))) {
          print('if---------4'); //..........4
          _canAttend = false; // Enable the Leave for first leave
          _canLeave = true;
        } else if ((leave1 != null) &&
            (!hasAttended3) &&
            (now.isAfter(leave1)) &&
            (now.isBefore(shiftEnd.subtract(Duration(hours: 1))))) {
          print('if---------5'); //..........5
          _canAttend = true; // Enable the Attend for second attendance
          _canLeave = false;
        } else if ((attend3 != null) &&
            (!hasLeft2) &&
            (now.isAfter(attend3)) &&
            now.isBefore(shiftEnd.add(Duration(hours: 2)))) {
          print('if---------6');
          _canAttend = false; // Enable the Attend for first attendance
          _canLeave = true;
          //..........6
        } else {
          _canAttend = false;
          _canLeave = false;
          print('if---------7'); //..........7
        }
      });
    } else {
      print('No existing record found for today. Initializing fresh state.');
    }
    print(
        'Final Button States: Attend1=$hasAttended1, attend2$hasAttended2,  attend3$hasAttended3');
    print('Final Button States: leave1=$hasLeft1, leave2$hasLeft2');
  }

  void handleNotification(isAttend, time) async {
    if (isAttend == 0) {
      //LocalNotificationService.showScheduledNotification(
          //tr('Time to attend!'), tr('press to open'), time, isAttend);
      
    } else if (isAttend == 1) {
      LocalNotificationService.showScheduledNotification(
          tr('Time to prove your presence!'),
          tr('press to open'),
          time,
          isAttend);
    } else if (isAttend == 2) {
      LocalNotificationService.showScheduledNotification(
         tr('Time to go home!'), tr('press to open'), time, isAttend);
    }
  }

  void _handleAttend() async {
    if (!_canAttend || _currentShiftDay == null) return;
    tz.TZDateTime.now(tz.local).add(Duration(seconds: 10));

    DateTime now = DateTime.now();
    DateTime shiftStart = (_currentShift == 'day')
        ? DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
            _currentShiftDay!.day, 7, 0)
        : DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
            _currentShiftDay!.day, 19, 0);
    DateTime shiftEnd = (_currentShift == 'day')
        ? DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
            _currentShiftDay!.day, 19, 0)
        : DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
            _currentShiftDay!.day + 1, 7, 0);

    print(
        'Attend in "$now" ------ shiftStart: $shiftStart, shiftEnd: $shiftEnd');

    int year = now.year;
    int yearDelay = _delayMinutes;
    int workedDays = 0;
    int delayDif = _delayMinutes;
    final tzShiftEnd = tz.TZDateTime.from(shiftEnd, tz.local);

    DatabaseHelper dbHelper = DatabaseHelper();
    YearRecord? yearRecord = await dbHelper.getYearRecord(now.year);
    if (yearRecord != null) {
      year = yearRecord.year;
      yearDelay = yearRecord.delay;
      workedDays = yearRecord.workedDays;
    } else {
      await dbHelper.insertOrUpdateYearRecord(now.year, 0, 0);
    }

    DayRecord? existingRecord = await dbHelper.getDayRecord(
        _currentShiftDay!.year, _currentShiftDay!.month, _currentShiftDay!.day);

    if (existingRecord != null) {
      if (existingRecord.attend1 == null) {
        if (now.isBefore(shiftStart)) {
          _delayMinutes = 0;
          handleNotification(1, tzShiftEnd.subtract(Duration(hours: 10)));
          LocalNotificationService.cancelNotification(0);
        } else {
          if (now.difference(shiftStart).inHours < 3) {
            // للبصمة الثالثة
            handleNotification(
                1, tz.TZDateTime.now(tz.local).add(Duration(hours: 2)));
          }
          // Adjust delay to ensure it's positive
          _delayMinutes = shiftEnd.isAfter(now)
              ? now.difference(shiftStart).inMinutes
              : shiftEnd.difference(shiftStart).inMinutes;
        }
        existingRecord.attend1 = now.toIso8601String();
        _canAttend = false;
        yearDelay += _delayMinutes;
        _monthlyDelayMinutes += _delayMinutes;
        workedDays++;
        handleNotification(2, tzShiftEnd.subtract(Duration(minutes: 5)));
      } else if ((existingRecord.attend2 == null) &&
          (existingRecord.attend1 != null) &&
          (existingRecord.leave1 == null)) {
        existingRecord.attend2 = now.toIso8601String();
      } else if (existingRecord.leave1 != null) {
        delayDif = _delayMinutes;
        _delayMinutes += now.difference(shiftEnd).inMinutes;
        //_monthlyDelayMinutes += now.difference(shiftEnd).inMinutes;
        existingRecord.attend3 ??= now.toIso8601String();
        if (delayDif > _delayMinutes) {
          yearDelay += (_delayMinutes - delayDif);
          _monthlyDelayMinutes += (_delayMinutes - delayDif);
        }
      }
      existingRecord.delayMinutes = _delayMinutes;

      print('Day record is updated: delayMinutes = $_delayMinutes');
      setState(() {
        _isLoading = true; // Show loading spinner
      });

      try {
        // Simulate a network call or some async operation
        await dbHelper.insertOrUpdateDayRecord(existingRecord);

        await dbHelper.updateYearRecord(year, yearDelay, workedDays);
        await dbHelper.insertOrUpdateMonthRecord(_currentShiftDay!.year,
            _currentShiftDay!.month, _monthlyDelayMinutes);
      } finally {
        setState(() {
          _isLoading = false; // Hide loading spinner
        });
      }
    }
    // Fetch updated monthly delay after updating
    await _fetchMonthlyDelay();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('attend_success', args: ['$_delayMinutes']),
        ),
      ),
    );

    _fetchDayInfo(now);
    await _updateButtonStates();
    setState(() {});
  }

  Future<tz.TZDateTime?> checkNextWorkingDay() async{
    final DatabaseHelper dbHelper = DatabaseHelper();
    DateTime today = DateTime.now();
    int x =0;
    while (x != 30){
      DayRecord? dayRecord = await dbHelper.getDayRecord(today.year, today.month, today.day);
      if(dayRecord!=null){ 
        if(dayRecord.status == 'Training Course'|| dayRecord.status == "onDuty"){
          String? shiftType = dayRecord.shift;

          if(shiftType == "day"){
            return tz.TZDateTime.from(DateTime(today.year,today.month,today.day,7,0),tz.local);
          }
          else if(shiftType == "night"){
            return tz.TZDateTime.from(DateTime(today.year,today.month,today.day,19,0),tz.local);
          }
          else if(shiftType == "Training Course"){
            return tz.TZDateTime.from(DateTime(today.year,today.month,today.day,8,30),tz.local);
          }
        }
      }
      x++;
      today = today.add(const Duration(days: 1));
    }
    return null;
  }

  void _handleLeave() async {
    if (!_canLeave || _currentShiftDay == null) return;
    tz.TZDateTime? nextShiftStart = await checkNextWorkingDay();

    DateTime now = DateTime.now();
    DateTime shiftEnd = (_currentShift == 'day')
        ? DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
            _currentShiftDay!.day, 19, 0)
        : DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
            _currentShiftDay!.day + 1, 7, 0);
    int oldDelay = _delayMinutes;
    final tzShiftEnd = tz.TZDateTime.from(shiftEnd, tz.local);

    print('Left in "$now" ------ shiftStart: , shiftenda: $shiftEnd');

    DatabaseHelper dbHelper = DatabaseHelper();
    YearRecord? yearRecord =
        await dbHelper.getYearRecord(_currentShiftDay!.year);

    DayRecord? existingRecord = await dbHelper.getDayRecord(
        _currentShiftDay!.year, _currentShiftDay!.month, _currentShiftDay!.day);

    if (existingRecord != null) {
      existingRecord.leave1 ??= now.toIso8601String();
      if ((existingRecord.leave1 != null) && (existingRecord.attend3 != null)) {
        existingRecord.leave2 ??= now.toIso8601String();
      }
      if (now.isBefore(shiftEnd)) {
        _delayMinutes -= now.difference(shiftEnd).inMinutes;
        LocalNotificationService.cancelNotification(2);
      }
      existingRecord.delayMinutes = _delayMinutes;
      if (yearRecord != null) {
        yearRecord.delay += (_delayMinutes - oldDelay);
        _monthlyDelayMinutes += (_delayMinutes - oldDelay);
        await dbHelper.updateYearRecord(
            yearRecord.year, yearRecord.delay, yearRecord.workedDays);
      }
      if(nextShiftStart != null){
        handleNotification(0, nextShiftStart);
      }
      print('Day record is updated: delayMinutes = $_delayMinutes');
      await dbHelper.insertOrUpdateDayRecord(existingRecord);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('leave_success', args: ['$_delayMinutes']),
          ),
        ),
      );
      setState(() {
        _isLoading = true; // Show loading spinner
      });

      try {
        // Simulate a network call or some async operation
        await dbHelper.insertOrUpdateMonthRecord(_currentShiftDay!.year,
            _currentShiftDay!.month, _monthlyDelayMinutes);
        _fetchDayInfo(now);
        await _fetchMonthlyDelay();
      } finally {
        setState(() {
          _isLoading = false; // Hide loading spinner
        });
      }
    }

    await _updateButtonStates();
    setState(() {});
    // Fetch updated monthly delay after leave action
    //await _fetchMonthlyDelay();
  }

  Future<bool> checkNextWorkingDayStatus() async {
    DatabaseHelper dbHelper = DatabaseHelper();

    // Get today's date
    DateTime today = DateTime.now();
    DateTime nextDay = today.add(Duration(days: 1));

    // If the current shift is night, set the next day check to two days ahead
    if (_currentShift == 'night') {
      nextDay = today.add(Duration(days: 2));
    }

    // Query the next working day record from the database
    DayRecord? nextDayRecord = await dbHelper.getDayRecord(
      nextDay.year,
      nextDay.month,
      nextDay.day,
    );

    // Check if the record exists and if the status is a vacation type
    if (nextDayRecord != null &&
        (nextDayRecord.status == 'Sick Leave' ||
            nextDayRecord.status == 'Vacation' ||
            nextDayRecord.status == 'Casual Leave')) {
      // Return true if the next day is a vacation
      return true;
    }
    // Return false if the next day is not a vacation
    return false;
  }

  // Add this function in the same file as your _fetchDayInfo method.
  String _formatTime(String? time) {
    if (time == null) return '';
    DateTime parsedTime = DateTime.parse(time);
    int hour = parsedTime.hour % 12 == 0
        ? 12
        : parsedTime.hour % 12; // Convert to 12-hour format
    return '${hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';
  }

  // Fetch day information from the database
  // Fetch day information from the database
  Future<void> _fetchDayInfo(DateTime day) async {
    DatabaseHelper dbHelper = DatabaseHelper();
    
    //_selectedDayAttendTime = '';
    //_selectedDayLeaveTime = '';

    // Fetch the day record for the selected day, not the current shift day
    DayRecord? record =
        await dbHelper.getDayRecord(day.year, day.month, day.day);
    int? monthDelay = await dbHelper.getMonthlyDelay(day.year,day.month);

    // Update the state with the selected day's status and delay
    setState(() {
      if (record != null) {
        _delayMinutes = record.delayMinutes;
        
        if (record.attend1 != null) {
          _selectedDayStatus = 'On Duty';
          _selectedDayAttendTime = _formatTime(record.attend1);
        } else if (record.attend1 == null){
          _selectedDayAttendTime='--:--';
            if(record.status == 'onDuty') {
              _selectedDayStatus = record.shift!;
            }
            else {
              _selectedDayStatus = record.status!;
            }
        }
        _selectedDayDelay = record.status != 'onDuty' ? 0 : record.delayMinutes;
        if (record.attend2 != null) {
          _selectedDayPresenceTime =_formatTime(record.attend2);
        }
        else{
          _selectedDayPresenceTime='--:--';
        }
        if (record.attend3 != null) {
          //_selectedDayAttendTime _formatTime(record.attend3));
        }

        if (record.leave1 != null) {
          _selectedDayLeaveTime =_formatTime(record.leave1);
          _selectedDayStatus = 'Done';
        }
        else{
          _selectedDayLeaveTime='--:--';
        }

        _selectedDayDelay = record.status != 'onDuty' ? 0 : record.delayMinutes;
      } else {
        _selectedDayDelay = 0;
        _selectedDayAttendTime='--:--';
        _selectedDayPresenceTime='--:--';
        _selectedDayLeaveTime='--:--';
        _selectedDayStatus = 'none'; // Default value if no record exists
        _selectedDayDelay = 0;
      }
      if(monthDelay!=null){
        _monthlyDelayMinutes=monthDelay;
      }
      else{
        _monthlyDelayMinutes=0;
      }
    });

    // Update the button states (Attend/Leave) based on the selected day
    await _updateButtonStates();
  }

  void _editDayInfo(BuildContext context)async{
     
   
    showDialog(
      context: context, 
      builder: (BuildContext context){
      return AlertDialog(
        title: Text('Edit Day Info').tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Edit Attend Time').tr(),
              //textColor: Theme.of(context).textTheme?.bodyMedium,
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context, 
                  initialTime: TimeOfDay.now(),
                  barrierColor: Theme.of(context).cardColor,
                  builder: (BuildContext context,Widget? child){
                    
                    return Theme(data: Theme.of(context).copyWith(
                      timePickerTheme: TimePickerThemeData(
                        dayPeriodColor: Color(0xFF007AFF),
                        backgroundColor: Theme.of(context).canvasColor,
                        dialBackgroundColor: Theme.of(context).canvasColor
                      ),
                      colorScheme: ColorScheme.light(
                        primary: Color(0xFF007AFF),
                        onPrimary: Theme.of(context).cardColor,
                        onSurface: Color(0xFF007AFF), 
                      ),
                      
                      
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF007AFF),
                        ),
                      ),
                     
                    ), child: child!);
                  }
                );
                if (pickedTime !=null){
                  setState(() {
                    _updateAttendTime(pickedTime);
                  });
                }
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('Edit Presence').tr(),
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context, 
                  initialTime: TimeOfDay.now(),
                  barrierColor: Theme.of(context).cardColor,
                  builder: (BuildContext context,Widget? child){
                    
                    return Theme(data: Theme.of(context).copyWith(
                      timePickerTheme: TimePickerThemeData(
                        dayPeriodColor: Color(0xFF007AFF),
                        backgroundColor: Theme.of(context).canvasColor,
                        dialBackgroundColor: Theme.of(context).canvasColor
                      ),
                      colorScheme: ColorScheme.light(
                        primary: Color(0xFF007AFF),
                        onPrimary: Theme.of(context).cardColor,
                        onSurface: Color(0xFF007AFF), 
                      ),
                      
                      
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF007AFF),
                        ),
                      ),
                     
                    ), child: child!);
                  }
                );
                if (pickedTime != null){
                  setState(() {
                    _updatePresenceTime(pickedTime);
                  });
                }
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('Edit Leave Time').tr(),
              onTap: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context, 
                  initialTime: TimeOfDay.now(),
                  barrierColor: Theme.of(context).cardColor,
                  builder: (BuildContext context,Widget? child){
                    
                    return Theme(data: Theme.of(context).copyWith(
                      timePickerTheme: TimePickerThemeData(
                        dayPeriodColor: Color(0xFF007AFF),
                        backgroundColor: Theme.of(context).canvasColor,
                        dialBackgroundColor: Theme.of(context).canvasColor
                      ),
                      colorScheme: ColorScheme.light(
                        primary: Color(0xFF007AFF),
                        onPrimary: Theme.of(context).cardColor,
                        onSurface: Color(0xFF007AFF), 
                      ),
                      
                    
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF007AFF),
                        ),
                      ),
                     
                    ), child: child!);
                  }
                );
                  if (pickedTime != null){
                    setState(() {
                      _updateLeaveTime(pickedTime);
                    });
                  }
                  Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text('Delete Day Times').tr(),
              textColor: Colors.red,
              onTap: () async {
                setState(() {
                  _deleteDayInfo();
                });
                  Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFF007AFF),
          ),
          child: Text('Cancel').tr(),
          
          ),
        ],
      );
    },
    );
  }

  void _deleteDayInfo() async{
    DatabaseHelper dbHelper = DatabaseHelper();
    DateTime? selected =_selectedDay;
    if(selected!=null){
      DayRecord? existingRecord = await dbHelper.getDayRecord(selected.year, selected.month,  selected.day);
      
      if(existingRecord!=null){
        int? monthDelay= await dbHelper.getMonthlyDelay(selected.year,selected.month);
        YearRecord? yearRecord = await dbHelper.getYearRecord(selected.year);
        if(monthDelay!=null&&yearRecord!=null){
          if(existingRecord.delayMinutes>0){
            monthDelay=(monthDelay-existingRecord.delayMinutes);
            yearRecord.delay=yearRecord.delay-existingRecord.delayMinutes; 
          }
          if(existingRecord.attend1!=null){
            --yearRecord.workedDays;
          }
    
        
      DayRecord updatedRecord = DayRecord(
          year: selected.year,
          month: selected.month,
          day: selected.day,
          status: 'onDuty',
          shift: existingRecord.shift,
          attend1: null,
          attend2: null,
          attend3: null,
          leave1:  null,
          leave2:  null,
          delayMinutes: 0,
        );
        await dbHelper.insertOrUpdateDayRecord(updatedRecord);
        await dbHelper.updateYearRecord(selected.year, yearRecord.delay, yearRecord.workedDays);
        await dbHelper.updateMonthRecord(selected.year, selected.month, monthDelay);
      }
      }
      tz.TZDateTime? nextShiftStart = await checkNextWorkingDay();
      handleNotification(0, nextShiftStart);
    
    setState(() {
       _fetchDayInfo(selected);
    });
    }
  }

  void _updateAttendTime(TimeOfDay time) async{
    DatabaseHelper dbHelper = DatabaseHelper();
    DateTime? selected =_selectedDay;
    // ignore: non_constant_identifier_names
    DateTime? ShiftStart;
    int newDelay=0;
    int yearDelay=0;
    
    if (selected!=null){
    DayRecord? existingRecord = await dbHelper.getDayRecord(selected.year, selected.month,  selected.day);
    YearRecord? yearRecord = await dbHelper.getYearRecord(selected.year);
    DateTime stTime = DateTime(selected.year,selected.month,selected.day,time.hour,time.minute);
    int? monthDelay= await dbHelper.getMonthlyDelay(stTime.year,stTime.month) ??0;

    if (existingRecord !=null){
      if(existingRecord.shift == 'day'){
        ShiftStart = DateTime(selected.year,selected.month,selected.day,7,0);
      }
      else if (existingRecord.shift =='night'){
        ShiftStart = DateTime(selected.year,selected.month,selected.day,19,0);
      }
       else if (existingRecord.shift =='Training Course'){
        ShiftStart = DateTime(selected.year,selected.month,selected.day,8,30);
      }
      else{return;}
       
        
      if(stTime.isAfter(ShiftStart)){
        newDelay=stTime.difference(ShiftStart).inMinutes;
      }
      if(yearRecord!=null){
      yearDelay=yearRecord.delay;
    }

      if(existingRecord.attend1==null){
        if(yearRecord!=null ) {
            yearRecord.workedDays++;
          }
      }
      if(existingRecord.delayMinutes==0){
          existingRecord.delayMinutes=newDelay;
          monthDelay+=newDelay;
          yearDelay+=newDelay;
      }
      else if(existingRecord.delayMinutes>0){
        if(existingRecord.attend1!=null){
          DateTime oldAttend1 = DateTime.parse( existingRecord.attend1!);
          if(oldAttend1.isAfter(ShiftStart)){
            existingRecord.delayMinutes -= oldAttend1.difference(ShiftStart).inMinutes;
            monthDelay -= oldAttend1.difference(ShiftStart).inMinutes;
            yearDelay -=oldAttend1.difference(ShiftStart).inMinutes;
          }
        }
        existingRecord.delayMinutes+=newDelay;
        monthDelay+=newDelay;
        yearDelay+=newDelay;    
      }
      if(stTime.day == DateTime.now().day){
        final tzshiftStart = tz.TZDateTime.from(ShiftStart,tz.local);
        await LocalNotificationService.cancelNotification(1);
        if(stTime.isBefore(ShiftStart)){
          handleNotification(1,tzshiftStart.add(Duration(hours: 2)));
        }
        else{
          handleNotification(1, (tz.TZDateTime.from(stTime,tz.local)).add(Duration(hours: 2)));
        }
      }
      
      existingRecord.attend1=stTime.toIso8601String();
      if(yearRecord!=null){
        yearRecord.delay=yearDelay;
        await dbHelper.updateYearRecord(yearRecord.year, yearRecord.delay, yearRecord.workedDays);
      }
      setState(() {
        _selectedDayAttendTime=_formatTime(existingRecord.attend1);
        _selectedDayDelay=existingRecord.delayMinutes;
        DateTime now = DateTime.now();
        if(stTime.month == now.month ){
          _monthlyDelayMinutes = monthDelay!;
        }
      });
        
      

      existingRecord.attend1= stTime.toIso8601String();
      await dbHelper.insertOrUpdateMonthRecord(stTime.year, stTime.month, monthDelay);
      await dbHelper.insertOrUpdateDayRecord(existingRecord);
      
    }
  }
  }
  void _updatePresenceTime(TimeOfDay time)async{
     DatabaseHelper dbHelper = DatabaseHelper();
    DateTime? selected =_selectedDay;
    if (selected!=null){
    DayRecord? existingRecord = await dbHelper.getDayRecord(selected.year, selected.month,  selected.day);
    
    if (existingRecord !=null){
      DateTime stTime = DateTime(selected.year,selected.month,selected.day,time.hour,time.minute);
      existingRecord.attend2= stTime.toIso8601String();
      dbHelper.insertOrUpdateDayRecord(existingRecord);
      setState(() {
          _selectedDayPresenceTime=_formatTime(existingRecord.attend2!);
        });
    }
  }
  
  }

void _updateLeaveTime(TimeOfDay time)async{
  DatabaseHelper dbHelper = DatabaseHelper();
    DateTime now =DateTime.now();
    DateTime? selected =_selectedDay;
    // ignore: non_constant_identifier_names
    DateTime? ShiftEnd;
    int newDelay=0;
    int yearDelay=0;

    
    if (selected!=null){
      if(now.day==selected.day){
        tz.TZDateTime? nextShiftStart = await checkNextWorkingDay();
        handleNotification(0, nextShiftStart);
      }
    
    DayRecord? existingRecord = await dbHelper.getDayRecord(selected.year, selected.month,  selected.day);
    YearRecord? yearRecord = await dbHelper.getYearRecord(selected.year);
    if(yearRecord!=null){
      yearDelay=yearRecord.delay;
    }
    else{
      await dbHelper.insertOrUpdateYearRecord(selected.year,0,0);
    }
    if (existingRecord !=null){
      
      DateTime stTime = DateTime(selected.year,selected.month,selected.day,time.hour,time.minute);
      int? monthDelay= await dbHelper.getMonthlyDelay(stTime.year,stTime.month);
      print("selected shift is: ${existingRecord.shift}");
      monthDelay ??= 0;
      if(existingRecord.shift == 'day'){
        ShiftEnd = DateTime(selected.year,selected.month,selected.day,19,0);
      }
      else if (existingRecord.shift =='night'){
        ShiftEnd = DateTime(selected.year,selected.month,selected.day+1,7,0);
        stTime = stTime.add(Duration(days: 1));
      }
       else if (existingRecord.shift =='Training Course'){
        ShiftEnd = DateTime(selected.year,selected.month,selected.day,12,30);
      }

       
      if(ShiftEnd!=null){
        if(stTime.isBefore(ShiftEnd)){
          newDelay=ShiftEnd.difference(stTime).inMinutes;
        }
        
        if(existingRecord.delayMinutes==0){
            existingRecord.delayMinutes=newDelay;
            monthDelay+=newDelay;
            yearDelay+=newDelay;
        }
        else if(existingRecord.delayMinutes>0){
          if(existingRecord.leave1!=null){
            DateTime oldLeave1 = DateTime.parse( existingRecord.leave1!);
            if(oldLeave1.isBefore(ShiftEnd)){
              existingRecord.delayMinutes-=ShiftEnd.difference(oldLeave1).inMinutes;
              monthDelay-=ShiftEnd.difference(oldLeave1).inMinutes;
              yearDelay-=ShiftEnd.difference(oldLeave1).inMinutes;
            }
          }
            existingRecord.delayMinutes+=newDelay;
            monthDelay+=newDelay;
            yearDelay+=newDelay;
          
        }
      }
      
      existingRecord.leave1=stTime.toIso8601String();
      if(yearRecord!=null){
        yearRecord.delay=yearDelay;
        await dbHelper.updateYearRecord(yearRecord.year, yearRecord.delay, yearRecord.workedDays);
      }
      setState(() {
        _selectedDayLeaveTime=_formatTime(existingRecord.leave1);
        _selectedDayDelay=existingRecord.delayMinutes;
        DateTime now = DateTime.now();
        if(stTime.month == now.month ){
          _monthlyDelayMinutes = monthDelay!;
        }
      });
        
      

      
      await dbHelper.insertOrUpdateMonthRecord(stTime.year, stTime.month, monthDelay);
      await dbHelper.insertOrUpdateDayRecord(existingRecord);
      
    }
  }
}
  void reloadPage(){
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()),);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color backgroundColor = theme.scaffoldBackgroundColor;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(
              'Welcome, Team $selectedTeam!'.tr(),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            //elevation: 4.0,
          ),
          body: selectedTeam == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Directionality(textDirection: ui.TextDirection.ltr, child: 
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        
                      // Calendar without Card
                      
                        child: TableCalendar(
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            leftChevronIcon: Icon(Icons.chevron_left,color: Color(0xFF007AFF),),
                            rightChevronIcon: Icon(Icons.chevron_right,color: Color(0xFF007AFF),)
                          ),
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                            _fetchDayInfo(selectedDay);
                          },
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, date, _) =>
                                _buildDayCell(date, false),
                            selectedBuilder: (context, date, _) =>
                                _buildSelectedDateWidget(date),
                            todayBuilder: (context, date, _) =>
                                _buildTodayDateWidget(date),
                          ),
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                          },
                        ),
                      ),
                      ),
                    
                      const SizedBox(height: 10),

                      // Selected Day's Information Card
                      if (_selectedDay != null) ...[
                        Card(
                          elevation: 3,
                          color: Theme.of(context).cardColor,
                          shadowColor: Theme.of(context).shadowColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left: Status and Delay
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${'Status'.tr()}: ${_selectedDayStatus.tr()}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            
                                            ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '${'Delay'.tr()}: ${_formatHoursAndMinutes(_selectedDayDelay)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(onPressed: (){_editDayInfo(context);},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).hintColor,
                                        ),
                                        child: const Text('Edit',
                                        style: TextStyle(color: Colors.white),).tr()
                                        ),
                                      ],
                                    ),
                                    // Right: Attendance and Leave Times
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_selectedDayAttendTime.isNotEmpty)
                                          Text(
                                            '${'Attend'.tr()}: $_selectedDayAttendTime',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        if (_selectedDayAttendTime.isNotEmpty)
                                          Text(
                                            '${'Presence'.tr()}: $_selectedDayPresenceTime',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        if (_selectedDayLeaveTime.isNotEmpty)
                                          Text(
                                            '${'Leave'.tr()}: $_selectedDayLeaveTime',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Attend and Leave Buttons with Shift Gauge Card
                      Card(
                        elevation: 3,
                        color: Theme.of(context).cardColor,
                        shadowColor: Theme.of(context).shadowColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),                        
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(150, 50),
                                        backgroundColor:
                                            Theme.of(context).hintColor
                                      ),
                                      onPressed:
                                          _canAttend ? _handleAttend : null,
                                      child: const Text(
                                        'Attend',
                                        style: TextStyle(color: Colors.white),
                                      ).tr(),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(150, 50),
                                        backgroundColor:
                                            Theme.of(context).hintColor,
                                      ),
                                      onPressed:
                                          _canLeave ? _handleLeave : null,
                                      child: const Text(
                                        'Leave',
                                        style: TextStyle(color: Colors.white),
                                      ).tr(),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _buildShiftGauge(_monthlyDelayMinutes),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),

        // Loading Indicator
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedDateWidget(DateTime date) {
    final formattedDate = date.toIso8601String().split('T').first;
    final shift = _shifts[formattedDate] ?? 'off';
    final color = _getShiftColor(shift);
    final dayRecord = _dayRecordsCache[formattedDate];
    final bool isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

    Color cellColor;
    if (dayRecord?.status == 'Training Course') {
      cellColor = Color(0xFFFFD43B);
    } else if (dayRecord != null && dayRecord.status != 'onDuty') {
      cellColor = Color.fromARGB(211, 218, 33, 0);
    } else {
      cellColor = color;
    }

    if(isToday){ // Selected day == today
     return Stack(
      alignment: Alignment.center,
      children: [
        Container(
      width: 45.0,
      height: 45.0,
      alignment: Alignment(0,-0.75),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius:
            BorderRadius.circular(100.0), 
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.5),
                blurRadius: 6.0,
                offset: Offset(0, 2)

              ),
              ],
            // Full circular radius for today
      ),
      child: Text(
        date.day.toString(),
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold,
            shadows: [Shadow(offset: Offset(-2.0, 2.0),
              blurRadius: 4.0,color: Colors.grey)]),
      ),
    ),
    Positioned(
      bottom: 9,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          'Today'.tr(),
          style: TextStyle(
            color: const ui.Color.fromARGB(255, 173, 32, 22),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(offset: Offset(-2.0, 2.0),
              blurRadius: 4.0,color: Colors.grey)]
          ),
        ),
      )
    ),
      ],
    ); 
    }

    return Container(
      margin: const EdgeInsets.all(3.0),
      alignment: Alignment.center,
      width: 45.0,
      height: 45.0,
      decoration: BoxDecoration(
        color: cellColor,
        
        borderRadius:
            BorderRadius.circular(100.0),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.3),
                blurRadius: 6.0,
                offset: Offset(0, 3),
              ),
              ], // Unique radius for selected day
      ),
      child: Text(
        date.day.toString(),
        style: const TextStyle(color: Colors.white ,fontSize: 26, fontWeight: FontWeight.bold,
          ),
      ),
    );
  }

  Widget _buildTodayDateWidget(DateTime date) {
    final formattedDate = date.toIso8601String().split('T').first;
    final shift = _shifts[formattedDate] ?? 'off';
    final color = _getShiftColor(shift);
    final dayRecord = _dayRecordsCache[formattedDate];

    Color cellColor;
    if (dayRecord?.status == 'Training Course') {
      cellColor = Color(0xFFFFD43B);
    } else if (dayRecord != null && dayRecord.status != 'onDuty') {
      cellColor = Color.fromARGB(211, 218, 33, 0);
    } else {
      cellColor = color.withAlpha(180);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
      width: 40.0,
      height: 40.0,
      alignment: Alignment(0,-0.7),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius:
            BorderRadius.circular(100.0), 
            
            // Full circular radius for today
      ),
      child: Text(
        date.day.toString(),
        style: const TextStyle(
            color:Colors.white   ,fontSize: 11, fontWeight: FontWeight.bold,
            shadows: [Shadow(offset: Offset(-2.0, 2.0),
              blurRadius: 4.0,color: Colors.grey)]),
      ),
    ),
    Positioned(
      bottom: 10,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          'Today'.tr(),
          style: TextStyle(
            color: ui.Color.fromARGB(255, 173, 32, 22),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(offset: Offset(-2.0, 2.0),
              blurRadius: 4.0,color: Colors.grey)]
          ),
        ),
      )
    ),
      ],
    );
  }

  Widget _buildDayCell(DateTime date, bool isSelected, {bool isToday = false}) {
    final formattedDate = date.toIso8601String().split('T').first;
    final shift = _shifts[formattedDate] ?? 'off';
    final color = _getShiftColor(shift);
    final dayRecord = _dayRecordsCache[formattedDate];

    Color cellColor;
    if (dayRecord?.status == 'Training Course') {
      cellColor = Color(0xFFFFD43B);
    } else if (dayRecord != null && dayRecord.status != 'onDuty') {
      cellColor = Color.fromARGB(211, 218, 33, 0); // Special color for off-duty
    } else if (isToday) {
      cellColor = color.withAlpha(180); // Lighter color for today's date
    } else {
      cellColor = color; // Default color based on shift
    }

    return Container(
      margin: const EdgeInsets.all(3.0),
      alignment: Alignment.center,
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: cellColor,
        border: isSelected
            ? Border.all(
                color: Colors.black45, width: 2.5) // Highlight selected day
            : null,
        borderRadius: BorderRadius.circular(100.0),
        
      ),
      child: Text(
        date.day.toString(),
        style:
            const TextStyle(color: Colors.white,fontSize: 18,),
      ),
    );
  }

  Widget _buildShiftGauge(int monthlyDelayMinutes) {
    // Convert monthlyDelay to a percentage of 12 hours (720 minutes)
    double progress = monthlyDelayMinutes / 720; // Allow overflow beyond 1.0

    // Determine gauge color based on the monthly delay ranges
    Color gaugeColor;
    if (monthlyDelayMinutes <= 540) {
      // 0 - 9 hours
      gaugeColor = Theme.of(context).hintColor;
    } else if (monthlyDelayMinutes <= 630) {
      // 9 - 10.5 hours
      gaugeColor = Color(0xFFFFD43B);
    } else {
      // Above 10.5 hours
      gaugeColor = Color.fromARGB(211, 218, 33, 0);
    }

    // Create the gauge with the correct progress and color
    return CircularPercentIndicator(
      radius: 60.0,
      lineWidth: 10.0,
      percent: progress <= 1.0 ? progress : 1.0, // Keep the gauge within bounds
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tr('Month Delay'), // The label text above the time
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4), // Add spacing between label and time
          Text(
            _formatHoursAndMinutes(
                monthlyDelayMinutes), // Display in hh:mm format
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
      progressColor: gaugeColor,
      backgroundColor: Colors.grey,
      circularStrokeCap: CircularStrokeCap.round,
    );
  }

  String _formatHoursAndMinutes(int totalMinutes) {
    int hours = totalMinutes ~/ 60; // Get the hours
    int minutes = totalMinutes % 60; // Get the remaining minutes

    // Format the string to ensure two digits for both hours and minutes
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  double _calculateShiftProgress(DateTime now) {
    if (_currentShift == 'off' || _currentShiftDay == null) {
      return 0.0;
    }

    DateTime shiftStart;
    DateTime shiftEnd;

    if (_currentShift == 'day') {
      shiftStart = DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
              _currentShiftDay!.day, 7, 0)
          .toLocal();
      shiftEnd = shiftStart.add(Duration(hours: 12));
    } else if (_currentShift == 'night') {
      shiftStart = DateTime(_currentShiftDay!.year, _currentShiftDay!.month,
              _currentShiftDay!.day, 19, 0)
          .toLocal();
      shiftEnd = shiftStart.add(Duration(hours: 12));
    } else {
      return 0.0;
    }

    if (now.isBefore(shiftStart)) {
      return 0.0;
    } else if (now.isAfter(shiftEnd)) {
      return 1.0;
    } else {
      return now.difference(shiftStart).inMinutes /
          shiftEnd.difference(shiftStart).inMinutes;
    }
  }

  Color _getShiftColor(String shift) {
    if (shift == 'day' || shift == 'Training Course') {
      return const Color(0xFFFFD43B);
    } else if (shift == 'night') {
      return Theme.of(context).hintColor;
    } else {
      return const Color.fromARGB(170, 158, 158, 158);
    }
  }

  final Map<String, DayRecord> _dayRecordsCache = {}; // Cache for day records

// Method to preload data for three months
  Future<void> _cacheDayRecords() async {
    DatabaseHelper dbHelper = DatabaseHelper();
    DateTime now = DateTime.now();

    // Get the first day of the previous, current, and next months
    DateTime start = DateTime(now.year, now.month - 1, 1);
    DateTime end =
        DateTime(now.year, now.month + 2, 0); // Last day of next month

    // Fetch records for the three-month range
    List<DayRecord> records = await dbHelper.getDayRecordsForRange(start, end);
    for (var record in records) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(
        DateTime(record.year, record.month, record.day),
      );
      _dayRecordsCache[formattedDate] = record;
    }
  }
}
