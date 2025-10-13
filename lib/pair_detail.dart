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
  final String group;

  PairItem(this.index, this.subject, this.timeStart, this.timeEnd, this.teacher, this.room, this.week, this.group);

  factory PairItem.fromMap(Map<String, dynamic> m) {
    return PairItem(
      m['index'],
      m['subject'],
      m['timeStart'],
      m['timeEnd'],
      m['teacher'] ?? '',
      m['room'] ?? '',
      m['week'] ?? 'both',
      m['group'] ?? 'both',
    );
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
  List<String> notes = [];
  bool loading = true;

  String _noteKey(String subject) => 'notes_${subject}';

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    setState(() => loading = true);
    SharedPreferences sp = await SharedPreferences.getInstance();
    String key = _noteKey(widget.pair.subject);
    List<String>? saved = sp.getStringList(key);
    notes = saved ?? [];
    setState(() => loading = false);
  }

  Future<void> addNote() async {
    String text = ctrl.text.trim();
    if (text.isEmpty) return;
    SharedPreferences sp = await SharedPreferences.getInstance();
    String key = _noteKey(widget.pair.subject);
    List<String> saved = sp.getStringList(key) ?? [];
    saved.add(text);
    await sp.setStringList(key, saved);
    ctrl.clear();
    await loadNotes();
  }

  Future<void> deleteNoteAt(int index) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String key = _noteKey(widget.pair.subject);
    List<String> saved = sp.getStringList(key) ?? [];
    if (index < saved.length) saved.removeAt(index);
    await sp.setStringList(key, saved);
    await loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pair.subject)),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'Добавить заметку для ${widget.pair.subject}',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: addNote,
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: notes.isEmpty
                  ? Center(child: Text('Нет заметок'))
                  : ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, i) {
                  return Card(
                    color: Color.fromARGB(255, 234, 228, 255),
                    child: ListTile(
                      title: Text(notes[i]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => deleteNoteAt(i),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
