import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../database_helper.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<YearRecord> _yearRecords = [];
  Map<int, List<MonthRecord>> _monthRecords = {};

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    DatabaseHelper dbHelper = DatabaseHelper();

    List<Map<String, dynamic>> yearRecordsMap =
        await dbHelper.getAllYearRecords();
    List<YearRecord> yearRecords =
        yearRecordsMap.map((e) => YearRecord.fromMap(e)).toList();

    Map<int, List<MonthRecord>> monthRecords = {};
    for (var yearRecord in yearRecords) {
      int year = yearRecord.year;
      List<Map<String, dynamic>> monthsMap =
          await dbHelper.getMonthRecordsForYear(year);
      List<MonthRecord> months =
          monthsMap.map((e) => MonthRecord.fromMap(e)).toList();
      monthRecords[year] = months;
    }

    setState(() {
      _yearRecords = yearRecords;
      _monthRecords = monthRecords;
    });
  }

  String _formatDelay(int delayMinutes) {
    int hours = delayMinutes ~/ 60;
    int minutes = delayMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Records'.tr(),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        backgroundColor: Theme.of(context).primaryColor ,
      ),
      body:
      Padding(
        padding: const EdgeInsets.all(24.0),
        
        child: _yearRecords.isEmpty
            ? Center(
                child: Text(
                  'no_records_found'.tr(),
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: _yearRecords.length,
                itemBuilder: (context, index) {
                  YearRecord yearRecord = _yearRecords[index];
                  int year = yearRecord.year;
                  int workedDays = yearRecord.workedDays;
                  int delayMinutes = yearRecord.delay;
                  String formattedDelay = _formatDelay(delayMinutes);
                  List<MonthRecord> months = _monthRecords[year] ?? [];

                  return _buildYearCard(
                    year: year,
                    delay: formattedDelay,
                    workedDays: workedDays,
                    months: months,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildYearCard({
    required int year,
    required String delay,
    required int workedDays,
    required List<MonthRecord> months,
  }) {
    return Card(
      elevation: 4,
      color: Theme.of(context).cardColor,
      shadowColor: Theme.of(context).shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'Year'.tr()}: $year',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF)),
            ),
            const SizedBox(height: 8),
            Text(
              '${'Delay'.tr()}: $delay',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${'Worked Days'.tr()}: $workedDays',
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(height: 20, thickness: 1.5),
            Column(
              children: months.map((monthRecord) {
                String monthName = getMonthName(monthRecord.month).tr();
                String formattedMonthDelay =
                    _formatDelay(monthRecord.monthlyDelay);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        monthName,
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        '${'Delay'.tr()}: $formattedMonthDelay',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String getMonthName(int month) {
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
