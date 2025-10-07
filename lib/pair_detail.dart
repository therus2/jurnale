import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

int getWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
}


class PairItem {
  final int index;
  final String subject;
  final String timeStart;
  final String timeEnd;
  final String teacher;
  final String room;
  final String week;

  PairItem(this.index, this.subject, this.timeStart, this.timeEnd, this.teacher, this.room, this.week);

  factory PairItem.fromMap(Map<String, dynamic> m) {
    return PairItem(m['index'], m['subject'], m['timeStart'], m['timeEnd'], m['teacher'] ?? '', m['room'] ?? '', m['week'] ?? 'both');
  }
}

class PairDetailPage extends StatefulWidget {
  final PairItem pair;
  final String dayFile;
  PairDetailPage({required this.pair, required this.dayFile});
  @override
  _PairDetailPageState createState() => _PairDetailPageState();
}

class _PairDetailPageState extends State<PairDetailPage> {
  TextEditingController ctrl = TextEditingController();
  List<Map<String,String>> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  String _noteKey(String dateStr, int idx) => 'note_{dateStr}_{idx}';

  Future<void> loadNotes() async {
    setState(()=>loading=true);
    SharedPreferences sp = await SharedPreferences.getInstance();
    notes = [];
    for (String k in sp.getKeys()) {
      if (k.startsWith('note_')) {
        String v = sp.getString(k) ?? '';
        notes.add({'key':k,'text':v});
      }
    }
    setState(()=>loading=false);
  }

  Future<List<DateTime>> _findNextOccurrences(String subject, DateTime fromDate, int maxDays) async {
    List<DateTime> found = [];
    for (int d=1; d<=maxDays; d++) {
      DateTime check = fromDate.add(Duration(days: d));
      String fname = ['','monday.json','tuesday.json','wednesday.json','thursday.json','friday.json','saturday.json','sunday.json'][check.weekday];
      String raw = await rootBundle.loadString('assets/data/' + fname);
      List<dynamic> arr = json.decode(raw);
      int weekOfYear = getWeekNumber(check);
      String weekType = (weekOfYear % 2 == 0) ? 'even' : 'odd';
      for (var item in arr) {
        String wk = item['week'] ?? 'both';
        if ((wk=='both' || wk==weekType) && (item['subject'] == subject)) {
          found.add(check);
          break;
        }
      }
      if (found.isNotEmpty) break;
    }
    return found;
  }

  Future<void> addNoteForNext() async {
    String subj = widget.pair.subject;
    DateTime now = DateTime.now();
    var nexts = await _findNextOccurrences(subj, now, 30);
    if (nexts.isEmpty) nexts = [now.add(Duration(days:1))];
    DateTime target = nexts.first;
    String dateStr = DateFormat('yyyy-MM-dd').format(target);
    SharedPreferences sp = await SharedPreferences.getInstance();
    String key = _noteKey(dateStr, widget.pair.index);
    await sp.setString(key, ctrl.text.trim());
    ctrl.clear();
    await loadNotes();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Заметка сохранена для {dateStr}')));
  }

  Future<void> deleteNote(String key) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.remove(key);
    await loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.pair.index}. ${widget.pair.subject}')),
      body: loading ? Center(child:CircularProgressIndicator()) : Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Время: ${widget.pair.timeStart} — ${widget.pair.timeEnd}'),
            SizedBox(height:10),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'Заметка для ближайшей пары этого предмета',
                suffixIcon: IconButton(icon: Icon(Icons.send), onPressed: addNoteForNext),
              ),
            ),
            SizedBox(height: 16),
            Text('Сохранённые заметки (всего ${notes.length})', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: notes.isEmpty ? Center(child: Text('Нет заметок')) : ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, i) {
                  var n = notes[i];
                  return ListTile(
                    title: Text(n['text'] ?? ''),
                    subtitle: Text(n['key'] ?? ''),
                    trailing: IconButton(icon: Icon(Icons.delete), onPressed: ()=>deleteNote(n['key']!)),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
