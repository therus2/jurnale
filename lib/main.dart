// lib/main.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'monday.dart' as monday;
import 'tuesday.dart' as tuesday;
import 'wednesday.dart' as wednesday;
import 'thursday.dart' as thursday;
import 'friday.dart' as friday;
import 'saturday.dart' as saturday;
import 'sunday.dart' as sunday;

// ========== Настройки ==========
const String serverBaseUrl = 'http://127.0.0.1:8000/api'; // <- поменяй при деплое

// ======= Вспомогательные функции =======
int getWeekNumber(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);
  final daysOffset = date.difference(firstDayOfYear).inDays;
  return ((daysOffset + firstDayOfYear.weekday) / 7).ceil();
}

String _fmtDateMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateFormat('dd.MM.yyyy HH:mm').format(dt);
}

String _randomClientId() {
  final r = Random();
  // генерируем случайное число от 0 до 2^32 - 1, но гарантируем max > 0
  final randPart = r.nextInt(1 << 31); // было 1 << 32, теперь 1 << 31 (всё ок)
  return '${DateTime.now().millisecondsSinceEpoch}_$randPart';
}


// ======= Приложение =======
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ИП-152 Расписание (синхрон.)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

// ========= HomePage (главный экран) =========
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String weekType = '';
  String todayName = '';
  int todayWeekday = DateTime.now().weekday;
  String? _token;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _determineWeek();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('jwt_token');
    });
  }

  void _determineWeek() {
    DateTime now = DateTime.now();
    int weekOfYear = getWeekNumber(now);
    weekType = (weekOfYear % 2 == 0) ? 'Чётная неделя' : 'Нечётная неделя';
    todayName = DateFormat.EEEE('ru').format(now);
    setState(() {});
  }

  // ----- Навигация по дню -----
  void openToday() {
    switch (todayWeekday) {
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => monday.DayScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => tuesday.DayScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => wednesday.DayScreen()));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => thursday.DayScreen()));
        break;
      case 5:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => friday.DayScreen()));
        break;
      case 6:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => saturday.DayScreen()));
        break;
      case 7:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => sunday.DayScreen()));
        break;
    }
  }

  void openTomorrow() {
    int tomorrow = todayWeekday + 1;
    if (tomorrow > 7) tomorrow = 1;
    switch (tomorrow) {
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => monday.DayScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => tuesday.DayScreen()));
        break;
      case 3:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => wednesday.DayScreen()));
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => thursday.DayScreen()));
        break;
      case 5:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => friday.DayScreen()));
        break;
      case 6:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => saturday.DayScreen()));
        break;
      case 7:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => sunday.DayScreen()));
        break;
    }
  }

  // ====== UI - build ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ИП-152 — Расписание'),
        actions: [
          IconButton(
            tooltip: 'Авторизация',
            icon: Icon(_token == null ? Icons.login : Icons.verified_user),
            onPressed: _showLoginDialog,
          ),
          IconButton(
            tooltip: 'Получить обновления (сервер → клиент)',
            icon: const Icon(Icons.sync),
            onPressed: _fetchUpdates,
          ),
          IconButton(
            tooltip: 'Отправить мои заметки (клиент → сервер)',
            icon: const Icon(Icons.cloud_upload),
            onPressed: _pushLocalNotes,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color.fromARGB(255, 234, 228, 255),
              child: Column(
                children: [
                  ListTile(
                    title: Text(weekType, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Сегодня: $todayName'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          openToday();
                        },
                        child: const Text('Открыть сегодня'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          openTomorrow();
                        },
                        child: const Text('Открыть завтра'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3 / 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _dayButton('Понедельник', monday.DayScreen()),
                  _dayButton('Вторник', tuesday.DayScreen()),
                  _dayButton('Среда', wednesday.DayScreen()),
                  _dayButton('Четверг', thursday.DayScreen()),
                  _dayButton('Пятница', friday.DayScreen()),
                  _dayButton('Суббота', saturday.DayScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayButton(String label, Widget page) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(const Color.fromARGB(255, 234, 228, 255)),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 17)),
    );
  }

  // ======= Авторизация: диалог и запрос =======
  Future<void> _showLoginDialog() async {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вход'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'username')),
            TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'password'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _login(usernameCtrl.text.trim(), passwordCtrl.text.trim());
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  Future<void> _login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите username и password')));
      return;
    }
    setState(() => _loading = true);
    try {
      final url = Uri.parse('$serverBaseUrl/login');
      final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': username, 'password': password}));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = (data['access'] ?? data['token'] ?? data['access_token']);
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          setState(() => _token = token);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Авторизация успешна')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Токен не найден в ответе')));
        }
      } else {
        String msg = 'Ошибка входа';
        try {
          final err = jsonDecode(res.body);
          msg = (err is Map && err['detail'] != null) ? err['detail'] : res.body;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ======= Сбор локальных заметок из SharedPreferences для отправки =======
  Future<List<Map<String, dynamic>>> _collectLocalNotesForSync() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final notes = <Map<String, dynamic>>[];
    for (final k in keys) {
      if (k.startsWith('notes_')) {
        final subject = k.substring('notes_'.length);
        final list = prefs.getStringList(k) ?? [];
        for (final text in list) {
          // Каждая локальная заметка — формируем объект для отправки
          // создаём уникальный client_id
          notes.add({
            'client_id': _randomClientId(),
            'id': null, // просим сервер сгенерировать id
            'subject': subject,
            'text': text,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'deleted': false
          });
        }
      }
    }
    return notes;
  }

  // ======= Отправка локальных заметок на сервер =======
  Future<void> _pushLocalNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }
    setState(() => _loading = true);
    try {
      final notes = await _collectLocalNotesForSync();
      if (notes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет локальных заметок для отправки')));
        return;
      }
      final url = Uri.parse('$serverBaseUrl/notes/sync');
      final res = await http.post(url, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'notes': notes}));
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Локальные заметки отправлены на сервер')));
      } else {
        String msg = 'Ошибка отправки: ${res.statusCode}';
        try {
          final d = jsonDecode(res.body);
          msg = d.toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ======= Получение обновлений с сервера и merge в локальные заметки =======
  Future<void> _fetchUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }
    setState(() => _loading = true);
    try {
      // можно хранить последний timestamp в prefs, но для удобства пока делаем since=0 (получим все)
      final since = prefs.getInt('notes_last_sync') ?? 0;
      final url = Uri.parse('$serverBaseUrl/notes/updates?since=$since');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> notes = data['notes'] ?? [];
        int cntAdded = 0;
        for (final n in notes) {
          final subject = (n['subject'] ?? '').toString();
          final author = (n['author_display_name'] ?? n['author_username'] ?? 'Автор').toString();
          final created = n['created_at'] is int ? n['created_at'] as int : DateTime.now().millisecondsSinceEpoch;
          final deleted = n['deleted'] == true;
          final text = (n['text'] ?? '').toString();
          final display = '$author [${_fmtDateMs(created)}] — $text';
          final key = 'notes_$subject';
          final list = prefs.getStringList(key) ?? [];

          if (deleted) {
            // удаление: убираем точно совпадающую строку (если есть)
            if (list.remove(display)) {
              await prefs.setStringList(key, list);
            } else {
              // если точной строки нет, попробуем удалить по тексту (после '— ')
              final idx = list.indexWhere((s) => s.split('—').length > 1 && s.split('—').last.trim() == text.trim());
              if (idx >= 0) {
                list.removeAt(idx);
                await prefs.setStringList(key, list);
              }
            }
          } else {
            // добавляем, если нет дубликата
            if (!list.contains(display)) {
              list.add(display);
              await prefs.setStringList(key, list);
              cntAdded++;
            }
          }
        }

        // обновляем since
        final serverTime = data['serverTime'] is int ? data['serverTime'] as int : DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('notes_since', serverTime);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Получено ${notes.length} записей, добавлено $cntAdded новых')));
      } else {
        String msg = 'Ошибка получения обновлений: ${res.statusCode}';
        try {
          final d = jsonDecode(res.body);
          msg = d.toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }
}
