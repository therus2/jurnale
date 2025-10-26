// lib/main.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'monday.dart' as monday;
import 'tuesday.dart' as tuesday;
import 'wednesday.dart' as wednesday;
import 'thursday.dart' as thursday;
import 'friday.dart' as friday;
import 'saturday.dart' as saturday;
import 'sunday.dart' as sunday;

// ========== Настройки ==========
const String serverBaseUrl = 'http://127.0.0.1:8000/api';

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
  final randPart = r.nextInt(1 << 31);
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
    _repairCorruptedData();
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
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => monday.DayScreen()));
        break;
      case 2:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => tuesday.DayScreen()));
        break;
      case 3:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => wednesday.DayScreen()));
        break;
      case 4:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => thursday.DayScreen()));
        break;
      case 5:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => friday.DayScreen()));
        break;
      case 6:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => saturday.DayScreen()));
        break;
      case 7:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => sunday.DayScreen()));
        break;
    }
  }

  void openTomorrow() {
    int tomorrow = todayWeekday + 1;
    if (tomorrow > 7) tomorrow = 1;
    switch (tomorrow) {
      case 1:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => monday.DayScreen()));
        break;
      case 2:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => tuesday.DayScreen()));
        break;
      case 3:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => wednesday.DayScreen()));
        break;
      case 4:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => thursday.DayScreen()));
        break;
      case 5:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => friday.DayScreen()));
        break;
      case 6:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => saturday.DayScreen()));
        break;
      case 7:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => sunday.DayScreen()));
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
            tooltip: 'Синхронизировать заметки с сервера',
            icon: const Icon(Icons.refresh),
            onPressed: _token != null ? _syncServerNotes : null,
          ),
          IconButton(
            tooltip: 'Отправить мои заметки (клиент → сервер)',
            icon: const Icon(Icons.cloud_upload),
            onPressed: _sendLocalNotes,
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
                    title: Text(weekType,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
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
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => page));
      },
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(
            const Color.fromARGB(255, 234, 228, 255)),
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
            TextField(
                controller: usernameCtrl,
                decoration:
                const InputDecoration(labelText: 'username')),
            TextField(
                controller: passwordCtrl,
                decoration:
                const InputDecoration(labelText: 'password'),
                obscureText: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Введите username и password')));
      return;
    }
    setState(() => _loading = true);
    try {
      final url = Uri.parse('$serverBaseUrl/login');
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = (data['access'] ?? data['token'] ?? data['access_token']);
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          await prefs.setString('username', username);
          await _fetchUserGroup(prefs, token);
          setState(() => _token = token);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Авторизация успешна')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Токен не найден в ответе')));
        }
      } else {
        String msg = 'Ошибка входа';
        try {
          final err = jsonDecode(res.body);
          msg = (err is Map && err['detail'] != null) ? err['detail'] : res.body;
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchUserGroup(SharedPreferences prefs, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$serverBaseUrl/user/group'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final group = data['group'] as String?;
        if (group != null) {
          await prefs.setString('user_group', group);
        }
      }
    } catch (e) {
      print('Error fetching user group: $e');
    }
  }

  // ======= Восстановление поврежденных данных =======
  Future<void> _repairCorruptedData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('notes_')).toList();
    print('Checking for corrupted data in ${keys.length} keys');

    for (final key in keys) {
      final data = prefs.get(key);
      if (data is! List<String>) {
        print('Repairing corrupted key: $key, type: ${data.runtimeType}');
        await prefs.remove(key);
      }
    }
  }

  // ======= Безопасное получение заметок из SharedPreferences =======
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

  // ======= Отправка локальных заметок на сервер =======
  Future<void> _sendLocalNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> notes = [];
      final keys = prefs.getKeys().where((k) => k.startsWith('notes_')).toList();
      String username = prefs.getString('username') ?? 'Гость';
      int now = DateTime.now().millisecondsSinceEpoch;

      for (String key in keys) {
        // Используем безопасное получение данных
        List<String> saved = await _getSafeNotesList(prefs, key);

        for (String s in saved) {
          try {
            var jsonData = jsonDecode(s);
            String text = jsonData['text'] ?? '';
            String id = jsonData['id'] ?? Uuid().v4();

            if (jsonData['isServer'] == true) {
              continue;
            }

            notes.add({
              'id': id,
              'client_id': _randomClientId(),
              'subject': key.replaceFirst('notes_', ''),
              'text': text,
              'author': username,
              'uploaded_at': jsonData['uploaded_at'] ?? now,
              'isServer': jsonData['isServer'] == true,
              'created_at': jsonData['created_at'] ?? now,
              'updated_at': jsonData['updated_at'] ?? now,
              'deleted': false,
            });
          } catch (e) {
            print('Error parsing local note: $e');
          }
        }
      }

      if (notes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Нет локальных заметок для отправки')));
        return;
      }

      final url = Uri.parse('$serverBaseUrl/notes/sync');
      final res = await http.post(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      }, body: jsonEncode({'notes': notes}));

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Локальные заметки отправлены на сервер')));
      } else {
        String msg = 'Ошибка отправки: ${res.statusCode}';
        try {
          final d = jsonDecode(res.body);
          msg = d.toString();
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ======= Получение обновлений с сервера =======
  Future<void> _fetchUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }
    setState(() => _loading = true);
    try {
      int since = 0;
      print('Fetching updates with since=$since');
      final url = Uri.parse('$serverBaseUrl/notes/updates?since=$since');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (res.statusCode == 200) {
        final dynamic responseData = jsonDecode(res.body);

        // КРИТИЧЕСКАЯ ПРОВЕРКА: убедимся что responseData - Map
        if (responseData is! Map<String, dynamic>) {
          throw Exception('Server returned invalid data type: ${responseData.runtimeType}');
        }

        final List<dynamic> notes = responseData['notes'] ?? [];
        int cntAdded = 0;
        int cntUpdated = 0;

        for (final n in notes) {
          final subject = (n['subject'] ?? '').toString();
          final id = n['id']?.toString() ?? '';

          if (id.isEmpty) continue;

          final text = (n['text'] ?? '').toString();
          final uploaded = n['uploaded_at'] is int ? n['uploaded_at'] : DateTime.now().millisecondsSinceEpoch;

          final key = 'notes_$subject';

          // Используем безопасное получение данных
          List<String> list = await _getSafeNotesList(prefs, key);

          int? existingIndex;
          for (int i = 0; i < list.length; i++) {
            try {
              final localNote = jsonDecode(list[i]) as Map<String, dynamic>;
              if (localNote['id']?.toString() == id) {
                existingIndex = i;
                break;
              }
            } catch (e) {
              continue;
            }
          }

          final noteJson = jsonEncode({
            'id': id,
            'text': text,
            'uploaded_at': uploaded,
            'author': n['author']?.toString() ?? 'Unknown',
            'subject': subject,
            'isServer': true,
            'created_at': n['created_at'] ?? uploaded,
            'updated_at': n['updated_at'] ?? uploaded,
          });

          if (existingIndex != null) {
            list[existingIndex] = noteJson;
            cntUpdated++;
          } else {
            list.add(noteJson);
            cntAdded++;
          }

          // Безопасное сохранение
          await prefs.setStringList(key, list);
        }

        final serverTime = responseData['serverTime'] is int
            ? responseData['serverTime']
            : DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('notes_last_sync', serverTime);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            'Получено ${notes.length} записей, добавлено: $cntAdded, обновлено: $cntUpdated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка получения обновлений: ${res.statusCode}')));
      }
    } catch (e) {
      print('Fetch updates error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка синхронизации: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ======= Функция синхронизации =======
  Future<void> _syncServerNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }
    setState(() => _loading = true);

    try {
      final keys = prefs.getKeys().where((k) => k.startsWith('notes_')).toList();
      print('Found ${keys.length} note keys to sync');

      for (final key in keys) {
        // Используем безопасное получение данных
        List<String> list = await _getSafeNotesList(prefs, key);
        List<String> updatedList = [];

        for (final noteStr in list) {
          try {
            final noteMap = jsonDecode(noteStr) as Map<String, dynamic>;
            final isServer = noteMap['isServer'] == true;

            if (isServer) {
              continue;
            } else {
              updatedList.add(noteStr);
            }
          } catch (e) {
            print('Error parsing note: $e, note: $noteStr');
            updatedList.add(noteStr);
          }
        }

        await prefs.setStringList(key, updatedList);
      }

      await _fetchUpdates();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Синхронизация завершена')));

    } catch (e) {
      print('Sync error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка синхронизации: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }
}