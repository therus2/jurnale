import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart'; // Добавь в pubspec.yaml: uuid: ^4.5.0
import 'package:http/http.dart' as http; // <<< ДОБАВЬ ЭТО >>>

// ========== Настройки ==========
// <<< ПЕРЕНОСИМ СЮДА ИЗ main.dart >>>
const String serverBaseUrl = 'http://127.0.0.1:8000/api'; // <- поменяй при деплое

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
  bool _userCanDelete = false; // <<< ДОБАВЛЕНО >>>

  String _noteKey(String subject) => 'notes_${subject}';

  @override
  void initState() {
    super.initState();
    _loadUserPermissions(); // <<< ВЫЗОВ НОВОЙ ФУНКЦИИ >>>
    loadNotes();
  }

  // <<< НОВАЯ ФУНКЦИЯ: Загрузка прав пользователя >>>
  Future<void> _loadUserPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userGroup = prefs.getString('user_group') ?? '';

    // Проверяем, есть ли у пользователя право удалять
    setState(() {
      _userCanDelete = userGroup == 'teachers' && token != null;
    });
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


  // <<< ОРИГИНАЛЬНАЯ ФУНКЦИЯ: Локальное удаление >>>
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

  // <<< НОВАЯ ФУНКЦИЯ: Подтверждение и удаление с сервера >>>
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

// <<< НОВАЯ ФУНКЦИЯ: Удаление с сервера и локально >>>
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
        Uri.parse('$serverBaseUrl/notes/$noteId/'), // <<< ОБЯЗАТЕЛЬНО СЛЭШ В КОНЦЕ >>>
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Успешно удалено на сервере
        // Теперь удаляем из SharedPreferences
        // final subject = note.subject ?? ''; // <-- УДАЛИ ЭТУ СТРОКУ
        final subject = widget.pair.subject; // <-- ВОЗЬМИ SUBJECT ИЗ PairItem
        final key = 'notes_$subject';
        List<String> list = prefs.getStringList(key) ?? [];
        list.removeWhere((str) {
          try {
            final localNote = jsonDecode(str) as Map<String, dynamic>;
            return localNote['id'] == noteId;
          } catch (e) {
            return false; // Игнорируем битые строки
          }
        });
        await prefs.setStringList(key, list);

        // Показываем сообщение
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Заметка удалена с сервера и с телефона'))); // <<< Обновлено сообщение

        // Перерисовать список
        await loadNotes(); // <-- Обновляем список заметок

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
                      // <<< ИЗМЕНЕНО: trailing >>>
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_userCanDelete) // <<< УСЛОВИЕ: только если может удалять >>>
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red), // <<< КРАСНЫЙ КРЕСТИК >>>
                              onPressed: () => _confirmAndDeleteNoteFromServer(note), // <<< НОВАЯ ФУНКЦИЯ >>>
                            ),
                          IconButton(
                            icon: Icon(Icons.delete_forever), // <<< ОРИГИНАЛЬНАЯ ЛОКАЛЬНАЯ КНОПКА >>>
                            onPressed: () => deleteNoteAt(i), // <<< ОРИГИНАЛЬНАЯ ФУНКЦИЯ >>>
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