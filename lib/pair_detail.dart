import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart'; // Добавь в pubspec.yaml: uuid: ^4.5.0

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

class Note {
  final String text;
  final int uploadedAt;
  final String author;
  final String? id; // Добавили id

  Note({required this.text, required this.uploadedAt, required this.author, this.id});

  Map<String, dynamic> toJson() => {
    'text': text,
    'uploaded_at': uploadedAt,
    'author': author,
    'id': id,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    text: json['text']?.toString() ?? '',
    uploadedAt: json['uploaded_at'] is int ? json['uploaded_at'] : DateTime.now().millisecondsSinceEpoch,
    author: json['author']?.toString() ?? 'Unknown',
    id: json['id']?.toString(),
  );
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
  List<Note> notes = [];
  bool loading = false;

  String _noteKey(String subject) => 'notes_${subject}';

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    print('Loading notes for ${widget.pair.subject}');
    setState(() => loading = true);
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String key = _noteKey(widget.pair.subject);
      List<String>? saved = sp.getStringList(key);
      print('Raw saved notes: $saved');
      notes = [];
      String username = sp.getString('username') ?? 'Гость';  // Реальный username
      if (saved != null && saved.isNotEmpty) {
        for (var s in saved) {
          try {
            var json = jsonDecode(s);
            notes.add(Note.fromJson(json));
          } catch (e) {
            // Миграция старого формата
            print('Migrating old note: $s, error: $e');
            final parts = s.split(' — ');
            String text = parts.length > 1 ? parts[1].trim() : s.trim();
            notes.add(Note(
              text: text,
              uploadedAt: DateTime.now().millisecondsSinceEpoch,
              author: username,  // Реальный username
              id: Uuid().v4(),
            ));
          }
        }
        await sp.setStringList(key, notes.map((n) => jsonEncode(n.toJson())).toList());
      }
    } catch (e) {
      print('Error loading notes: $e');
    } finally {
      setState(() => loading = false);
      print('Notes loaded: ${notes.length}');
    }
  }

  Future<void> addNote() async {
    String text = ctrl.text.trim();
    if (text.isEmpty) return;
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String key = _noteKey(widget.pair.subject);
      List<String> saved = sp.getStringList(key) ?? [];
      String username = sp.getString('username') ?? 'Гость';  // Реальный username
      Note newNote = Note(
        text: text,
        uploadedAt: DateTime.now().millisecondsSinceEpoch,
        author: username,
        id: Uuid().v4(),
      );
      saved.add(jsonEncode(newNote.toJson()));
      await sp.setStringList(key, saved);
      ctrl.clear();
      await loadNotes();
    } catch (e) {
      print('Error adding note: $e');
    }
  }


  Future<void> deleteNoteAt(int index) async {
    print('Deleting note at index: $index');
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String key = _noteKey(widget.pair.subject);
      List<String> saved = sp.getStringList(key) ?? [];
      if (index < saved.length) {
        saved.removeAt(index);
        await sp.setStringList(key, saved);
        await loadNotes();
      }
    } catch (e) {
      print('Error deleting note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления заметки: $e')),
      );
    }
  }

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
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
                  final note = notes[i];
                  return Card(
                    color: Color.fromARGB(255, 234, 228, 255),
                    child: ListTile(
                      title: Text(note.text),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Автор: ${note.author}'),
                          Text('Добавлено на сервер: ${_formatDateTime(note.uploadedAt)}'),
                        ],
                      ),
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