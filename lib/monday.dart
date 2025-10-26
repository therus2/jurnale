import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'pair_detail.dart';
import 'dart:math' as math;

class DayScreen extends StatefulWidget {
  @override
  _DayScreenState createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  bool loading = true;
  List<PairItem> pairs = [];
  final String filename = 'assets/data/monday.json';

  @override
  void initState() {
    super.initState();
    loadDay();
  }

  Future<void> loadDay() async {
    print('=== loadDay() called ===');
    setState(() => loading = true);

    try {
      String raw = await rootBundle.loadString(filename);
      print('File loaded, length: ${raw.length}');

      // КРИТИЧЕСКАЯ ПРОВЕРКА: убедимся, что это не число
      if (raw.trim().isEmpty) {
        print('File is empty');
        pairs = [];
        return;
      }

      // ПРОВЕРКА: если это число, выбросим ошибку
      if (int.tryParse(raw.trim()) != null) {
        throw Exception('File contains number instead of JSON: $raw');
      }

      dynamic decoded = json.decode(raw);
      print('Decoded type: ${decoded.runtimeType}');

      // КРИТИЧЕСКАЯ ПРОВЕРКА: что декодированный объект - список
      if (decoded is! List) {
        throw Exception('Expected List but got: ${decoded.runtimeType}');
      }

      List<dynamic> arr = decoded;
      print('Decoded array length: ${arr.length}');

      DateTime today = DateTime.now();
      int weekOfYear = getWeekNumber(today);
      String weekType = (weekOfYear % 2 == 0) ? 'even' : 'odd';
      print('Current week type: $weekType');

      SharedPreferences sp = await SharedPreferences.getInstance();
      int group = sp.getInt('groupNumber') ?? 1;
      print('User group number: $group');

      pairs = arr
          .map((e) {
        try {
          return PairItem.fromMap(e);
        } catch (e) {
          print('Error creating PairItem from map: $e');
          return null;
        }
      })
          .where((p) => p != null)
          .cast<PairItem>()
          .where((p) {
        bool weekMatch = (p.week == 'both' || p.week == weekType);
        bool groupMatch = (p.group == 'both' || p.group == group.toString());
        bool matches = weekMatch && groupMatch;
        return matches;
      })
          .toList();

      print('Filtered pairs count: ${pairs.length}');

    } catch (e) {
      print('Error in loadDay: $e');
      pairs = [];
    }

    setState(() {
      loading = false;
    });
  }

  void openPair(PairItem p) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PairDetailPage(pair: p, dayFile: 'monday.json')));
    await loadDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Понедельник')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : pairs.isEmpty
          ? Center(child: Text('На этот день пар нет'))
          : ListView.builder(
        itemCount: pairs.length,
        itemBuilder: (context, i) {
          var p = pairs[i];
          return Card(
            color: Color.fromARGB(255, 234, 228, 255),
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text('${p.index}. ${p.subject}'),
              subtitle: Text('${p.timeStart} — ${p.timeEnd}\n${p.teacher} ${p.room}'),
              isThreeLine: true,
              onTap: () {
                HapticFeedback.selectionClick();
                openPair(p);
              },
            ),
          );
        },
      ),
    );
  }
}

// Добавьте функцию getWeekNumber если её нет в импортированных файлах
int getWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
}