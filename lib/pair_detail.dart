import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

// ========== Настройки ==========
const String serverBaseUrl = 'http://127.0.0.1:8000/api';

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
  final String? id;
  final String subject;
  final bool isServer;

  Note({
    required this.text,
    required this.uploadedAt,
    required this.author,
    required this.subject,
    required this.isServer,
    this.id,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'uploaded_at': uploadedAt,
    'author': author,
    'subject': subject,
    'isServer': isServer,
    'id': id,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    text: json['text']?.toString() ?? '',
    uploadedAt: json['uploaded_at'] is int ? json['uploaded_at'] : DateTime.now().millisecondsSinceEpoch,
    author: json['author']?.toString() ?? 'Unknown',
    subject: json['subject']?.toString() ?? '',
    isServer: json['isServer'] == true,
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
  bool _userCanDelete = false;
  String? _userGroup;

  String _noteKey(String subject) => 'notes_${subject}';

  Future<List<String>> _getSafeNotesList(SharedPreferences prefs, String key) async {
    try {
      final data = prefs.get(key);
      if (data is List<String>) {
        return data;
      } else {
        print('Invalid data type for key $key: ${data.runtimeType}');
        await prefs.remove(key);
        return [];
      }
    } catch (e) {
      print('Error reading notes for key $key: $e');
      await prefs.remove(key);
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserPermissions();
    loadNotes();
  }

  Future<void> _loadUserPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userGroup = prefs.getString('user_group') ?? '';

    setState(() {
      _userGroup = userGroup;
      // Студенты не могут удалять заметки с сервера
      _userCanDelete = (userGroup == 'teachers') && token != null;
    });
  }

  Future<void> loadNotes() async {
    print('Loading notes for ${widget.pair.subject}');
    setState(() => loading = true);
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String key = _noteKey(widget.pair.subject);

      List<String> saved = await _getSafeNotesList(sp, key);

      print('Raw saved notes: $saved');
      List<Note> loadedNotes = [];
      String username = sp.getString('username') ?? 'Гость';

      if (saved.isNotEmpty) {
        for (var s in saved) {
          try {
            var jsonData = jsonDecode(s);
            if (jsonData['subject'] == null) {
              jsonData['subject'] = widget.pair.subject;
            }
            if (jsonData['isServer'] == null) {
              jsonData['isServer'] = false;
            }
            loadedNotes.add(Note.fromJson(jsonData));
          } catch (e) {
            print('Migrating old note: $s, error: $e');
            final parts = s.split(' — ');
            String text = parts.length > 1 ? parts[1].trim() : s.trim();
            loadedNotes.add(Note(
              text: text,
              uploadedAt: DateTime.now().millisecondsSinceEpoch,
              author: username,
              subject: widget.pair.subject,
              isServer: false,
              id: Uuid().v4(),
            ));
          }
        }

        loadedNotes.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        await sp.setStringList(key, loadedNotes.map((n) => jsonEncode(n.toJson())).toList());

        setState(() {
          notes = loadedNotes;
        });
      } else {
        setState(() {
          notes = [];
        });
      }
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        notes = [];
      });
    } finally {
      setState(() => loading = false);
      print('Notes loaded: ${notes.length}');
    }
  }

  Future<void> addNote() async {
    // Студенты могут добавлять локальные заметки, но не могут отправлять на сервер
    String text = ctrl.text.trim();
    if (text.isEmpty) return;
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String key = _noteKey(widget.pair.subject);

      List<String> saved = await _getSafeNotesList(sp, key);

      String username = sp.getString('username') ?? 'Гость';
      Note newNote = Note(
        text: text,
        uploadedAt: DateTime.now().millisecondsSinceEpoch,
        author: username,
        subject: widget.pair.subject,
        isServer: false,
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

      List<String> saved = await _getSafeNotesList(sp, key);

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

  Future<void> _confirmAndDeleteNoteFromServer(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить заметку?'),
        content: Text('Вы уверены, что хотите удалить эту заметку?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Да, удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteNoteFromServerAndLocal(note);
    }
  }

  Future<void> _deleteNoteFromServerAndLocal(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final noteId = note.id;

    if (token == null || noteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: токен или ID заметки отсутствует')));
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('$serverBaseUrl/notes/$noteId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final subject = widget.pair.subject;
        final key = 'notes_$subject';

        List<String> list = await _getSafeNotesList(prefs, key);

        list.removeWhere((str) {
          try {
            final localNote = jsonDecode(str) as Map<String, dynamic>;
            return localNote['id'] == noteId;
          } catch (e) {
            return false;
          }
        });
        await prefs.setStringList(key, list);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Заметка удалена с сервера и с телефона')));

        await loadNotes();
      } else {
        String errorMsg = 'Ошибка: ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          errorMsg = body['error'] ?? body.toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка соединения: $e')));
    }
  }

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    bool isStudent = _userGroup == 'students';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pair.subject} ${isStudent ? '(Студент)' : ''}'),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            // Студенты могут добавлять локальные заметки
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
            if (isStudent) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Режим студента: вы можете добавлять локальные заметки и получать обновления с сервера',
                    style: TextStyle(color: Colors.blue[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
            Expanded(
              child: notes.isEmpty
                  ? Center(child: Text('Нет заметок'))
                  : ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, i) {
                  final note = notes[i];
                  return Card(
                    color: Color.fromARGB(255, 234, 228, 255),
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        note.text,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text('Автор: ${note.author}'),
                          SizedBox(height: 2),
                          Text('Добавлено: ${_formatDateTime(note.uploadedAt)}'),
                          SizedBox(height: 2),
                          Text(
                            'Тип: ${note.isServer ? "Серверная" : "Локальная"}',
                            style: TextStyle(
                              color: note.isServer ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Скрываем кнопку удаления с сервера для студентов
                          if (_userCanDelete && !isStudent)
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmAndDeleteNoteFromServer(note),
                            ),
                          // Локальное удаление доступно всем
                          IconButton(
                            icon: Icon(Icons.delete_forever, color: Colors.grey),
                            onPressed: () => deleteNoteAt(i),
                          ),
                        ],
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