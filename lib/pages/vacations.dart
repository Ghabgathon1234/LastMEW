import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import 'dart:convert';
import 'dart:ui' as ui;

class VacationsPage extends StatefulWidget {
  const VacationsPage({super.key});

  @override
  _VacationsPageState createState() => _VacationsPageState();
}

class _VacationsPageState extends State<VacationsPage> {
  @override
  void initState() {
    super.initState();
    _loadShiftsFromPrefs(); // Load shifts when the page is initialized
  }

  String _selectedVacationType = 'Sick Leave';
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  Map<String, String> _shifts = {};
  final List<String> _vacationTypes = [
    'Sick Leave',
    'Vacation',
    'Casual Leave',
    'Training Course',
    'OFF (before/after training)',
    'Remove Vacation',
  ];
  Future<void> _loadShiftsFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? shiftsJson = prefs.getString('shifts');
    DatabaseHelper dbHelper = DatabaseHelper();
    DateTime today = DateTime.now();
    
    if (shiftsJson != null) {
      setState(() {
        _shifts = Map<String, String>.from(jsonDecode(shiftsJson));
        //print('shift color is loaded: $_shifts');
      });
    }
    for(int i=-360;i<360;i++){
      DateTime currentDay = today.add(Duration(days: i));
      String formattedDate = currentDay.toIso8601String().split('T').first;
      DayRecord? existingRecord = await dbHelper.getDayRecord(currentDay.year, currentDay.month,  currentDay.day);
      if(existingRecord!=null){
        setState(() {
        if(existingRecord.status!='onDuty'){ 
            _shifts[formattedDate]='vacation';
        }
        if(existingRecord.status=='Training Course'){
          _shifts[formattedDate]='Training Course';
        }
      });
        
      }
    }
  }
  
    

  Future<void> _saveVacation() async {
    if (_rangeStart == null){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a valid date range!').tr()),
      );
      return;
    }
    else if(_rangeEnd == null){
      setState(() {
        _rangeEnd=_rangeStart;
      });
    }

    DatabaseHelper dbHelper = DatabaseHelper();

    for (DateTime date = _rangeStart!;
        !date.isAfter(_rangeEnd!);
        date = date.add(const Duration(days: 1))) {
      DayRecord? existingRecord =
          await dbHelper.getDayRecord(date.year, date.month, date.day);

      if (existingRecord != null) {
        String status = _selectedVacationType == 'Remove Vacation'
            ? 'onDuty'
            : _selectedVacationType;
        if(status=='Training Course'){
          DayRecord updatedRecord = DayRecord(
          year: existingRecord.year,
          month: existingRecord.month,
          day: existingRecord.day,
          status: status,
          shift: status,
          attend1: status == 'onDuty' ? existingRecord.attend1 : null,
          attend2: status == 'onDuty' ? existingRecord.attend2 : null,
          attend3: status == 'onDuty' ? existingRecord.attend3 : null,
          leave1: status == 'onDuty' ? existingRecord.leave1 : null,
          leave2: status == 'onDuty' ? existingRecord.leave2 : null,
          delayMinutes: status == 'onDuty' ? existingRecord.delayMinutes : 0,
        );
        await dbHelper.insertOrUpdateDayRecord(updatedRecord);
        }
        else if (existingRecord.status=='Training Course' && status=='onDuty'){
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          final String? shiftsJson = prefs.getString('shifts');
          String formattedDate = date.toIso8601String().split('T').first;
          if (shiftsJson != null) {
            setState(() {
              _shifts = Map<String, String>.from(jsonDecode(shiftsJson));
              //print('shift color is loaded: $_shifts');
            });
            
          }
          DayRecord updatedRecord = DayRecord(
          year: existingRecord.year,
          month: existingRecord.month,
          day: existingRecord.day,
          status: status,
          shift: _shifts[formattedDate]!,
          attend1: status == 'onDuty' ? existingRecord.attend1 : null,
          attend2: status == 'onDuty' ? existingRecord.attend2 : null,
          attend3: status == 'onDuty' ? existingRecord.attend3 : null,
          leave1: status == 'onDuty' ? existingRecord.leave1 : null,
          leave2: status == 'onDuty' ? existingRecord.leave2 : null,
          delayMinutes: status == 'onDuty' ? existingRecord.delayMinutes : 0,
        );
        await dbHelper.insertOrUpdateDayRecord(updatedRecord);
        }
        
        else{
          DayRecord updatedRecord = DayRecord(
            year: existingRecord.year,
            month: existingRecord.month,
            day: existingRecord.day,
            status: status,
            shift: existingRecord.shift,
            attend1: status == 'onDuty' ? existingRecord.attend1 : null,
            attend2: status == 'onDuty' ? existingRecord.attend2 : null,
            attend3: status == 'onDuty' ? existingRecord.attend3 : null,
            leave1: status == 'onDuty' ? existingRecord.leave1 : null,
            leave2: status == 'onDuty' ? existingRecord.leave2 : null,
            delayMinutes: status == 'onDuty' ? existingRecord.delayMinutes : 0,
          );
          await dbHelper.insertOrUpdateDayRecord(updatedRecord);
        }
        
      }
      _loadShiftsFromPrefs();
      setState(() {
        
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('vacation is updated'.tr()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Vacations'.tr(),
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
                'Add/Remove Vacations'.tr(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007aFF),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Vacation Type Card
            _buildCard(
              child: Column(
                children: [
                  Text(
                    'Vacation Type'.tr(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: _selectedVacationType,
                    focusColor: Theme.of(context).textTheme.bodyLarge?.color,
                    items: _vacationTypes.map((String vacationType) {
                      return DropdownMenuItem<String>(
                        value: vacationType,
                        child: Text(vacationType.tr()),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedVacationType = newValue!;
                      });
                    },
                    isExpanded: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Date Range Picker Card
            //_buildCard(
              Directionality(textDirection: ui.TextDirection.ltr, 
              child: _buildDateRangePicker(),
            ),
            const SizedBox(height: 10),

            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _saveVacation,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  backgroundColor: Theme.of(context).hintColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Save'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    )),
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
        padding: const EdgeInsets.all(10.0),
        child: child,
      ),
    );
  }
  
  // Helper widget to create a date range picker
  Widget _buildDateRangePicker() {
    
      return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Select Date Range'.tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,)
        ),
        //const SizedBox(height: 5),
        TableCalendar(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          rangeStartDay: _rangeStart,
          rangeEndDay: _rangeEnd,
          rangeSelectionMode: RangeSelectionMode.toggledOn,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            leftChevronIcon: Icon(Icons.chevron_left,color: Color(0xFF007AFF),),
            rightChevronIcon: Icon(Icons.chevron_right,color: Color(0xFF007AFF),)
          ),
          onRangeSelected: (start, end, focusedDay) {
            setState(() {
              _rangeStart = start;
              _rangeEnd = end;
              _focusedDay = focusedDay;
            });
          },
          calendarBuilders: CalendarBuilders(
            rangeStartBuilder: (context, day, _) {
              final formattedDate = day.toIso8601String().split('T').first;
              
              final shift = _shifts[formattedDate] ?? 'off';
              final color = _getShiftColor(shift);
              return Container(
                alignment: Alignment.center,
                width: 40.0,
                height: 40.0,
                
                decoration: BoxDecoration(
                  color: color, // Unique color for _rangeStart
                  shape: BoxShape.circle, // Circular shape for the start day
                ),
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            },
            rangeEndBuilder: (context, day, _) {
              final formattedDate = day.toIso8601String().split('T').first;
              final shift = _shifts[formattedDate] ?? 'off';
              final color = _getShiftColor(shift);
              return Container(
                alignment: Alignment.center,
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: color, // Unique color for _rangeStart
                  shape: BoxShape.circle, // Circular shape for the start day
                ),
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            },
            withinRangeBuilder: (context, day, _) {
              final formattedDate = day.toIso8601String().split('T').first;
              final shift = _shifts[formattedDate] ?? 'off';
              final color = _getShiftColor(shift);
              return Container(
                alignment: Alignment.center,
                width: 50.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: color, // Unique color for _rangeStart
                  // Circular shape for the start day
                ),
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            },
            rangeHighlightBuilder: (context, day, isWithinRange) {
              final formattedDate = day.toIso8601String().split('T').first;
              final shift = _shifts[formattedDate] ?? 'off';
              final color = _getShiftColor(shift);
              bool isStart = day == _rangeStart;
              bool isEnd = day == _rangeEnd;
              if (isWithinRange) {
                return Container(
                  width: 50,
                  height: 40,
                  margin: const EdgeInsets.all(0.0),
                  decoration: BoxDecoration(
                    color: isStart
                        ? color // Color for _rangeStart
                        : isEnd
                            ? color // Color for _rangeEnd
                            : color, // Default range color// Highlight color
                    borderRadius: BorderRadius.horizontal(
                      left:
                          isStart ? const Radius.circular(100.0) : Radius.zero,
                      right: isEnd ? const Radius.circular(100.0) : Radius.zero,
                    ),
                  ),
                  alignment: Alignment.center,
                  // child: Text(
                  //   day.day.toString(),
                  //   style: const TextStyle(color: Colors.black),
                  // ),
                );
              }
              return null;
            },
            defaultBuilder: (context, day, _) {
              final formattedDate = day.toIso8601String().split('T').first;
              
              final shift = _shifts[formattedDate] ?? 'off';
              
            final color = _getShiftColor(shift);
             
              return Container(
                margin: const EdgeInsets.all(0.0),
                alignment: Alignment.center,
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(100.0),
                ),
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            },
            todayBuilder: (context, day, _) {
              final formattedDate = day.toIso8601String().split('T').first;
              final shift = _shifts[formattedDate] ?? 'off';
              final color = _getShiftColor(shift);
              return Container(
                margin: const EdgeInsets.all(0.0),
                alignment: Alignment.center,
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(100.0),
                  border: Border.all(
                    color: Color.fromARGB(211, 218, 33, 0),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            },
            selectedBuilder: (context, day, _) {
              final formattedDate = day.toIso8601String().split('T').first;
              final shift = _shifts[formattedDate] ?? 'off';
              final color = _getShiftColor(shift);
              return Container(
                margin: const EdgeInsets.all(0.0),
                alignment: Alignment.center,
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(100.0),
                ),
                child: Text(
                  day.day.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getShiftColor(String shift) {
    
    if (shift == 'day' || shift == 'Training Course') {
      return const Color(0xFFFFD43B);
    } else if (shift == 'night') {
      return Color(0xFF007AFF);
    }
    else if(shift == 'vacation')
    {
      return  Colors.red;
    }     
    else {
      return const Color.fromARGB(170, 158, 158, 158);
    }
  }
}
