import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'pair_detail.dart';

int getWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
}


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
    setState(()=>loading=true);
    String raw = await rootBundle.loadString(filename);
    List<dynamic> arr = json.decode(raw);
    DateTime today = DateTime.now();
    int weekOfYear = getWeekNumber(today);
    String weekType = (weekOfYear % 2 == 0) ? 'even' : 'odd';
    pairs = arr.map((e) => PairItem.fromMap(e)).where((p)=> (p.week=='both'||p.week==weekType)).toList();
    setState(()=>loading=false);
    SharedPreferences sp = await SharedPreferences.getInstance();
    int group = sp.getInt('groupNumber') ?? 1;

    pairs = arr.map((e) => PairItem.fromMap(e)).where((p) {
      bool weekMatch = (p.week == 'both' || p.week == weekType);
      bool groupMatch = (p.group == 'both' || p.group == group.toString());
      return weekMatch && groupMatch;
    }).toList();
  }

  void openPair(PairItem p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_)=>PairDetailPage(pair:p, dayFile:'monday.json')));
    await loadDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Понедельник')),
      body: loading ? Center(child:CircularProgressIndicator()) :
        pairs.isEmpty ? Center(child:Text('На этот день пар нет')) :
        ListView.builder(
          itemCount: pairs.length,
          itemBuilder: (context, i) {
            var p = pairs[i];
            return Card(
              color: Color.fromARGB(255, 234, 228, 255),
              margin: EdgeInsets.symmetric(horizontal:12, vertical:6),
              child: ListTile(
                title: Text('${p.index}. ${p.subject}'), // Исправлено
                subtitle: Text('${p.timeStart} — ${p.timeEnd}\n${p.teacher} ${p.room}'),
                isThreeLine: true,
                onTap: (){
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
