// lib/main.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'monday.dart' as monday;
import 'tuesday.dart' as tuesday;
import 'wednesday.dart' as wednesday;
import 'thursday.dart' as thursday;
import 'friday.dart' as friday;
import 'saturday.dart' as saturday;
import 'sunday.dart' as sunday;

// ========== Настройки ==========
const String serverBaseUrl = 'http://10.0.2.2:8000/api';

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
  int todayWeekday = DateTime
      .now()
      .weekday;
  String? _token;
  bool _loading = false;
  int? _currentGroup;
  String? _selectedWeekType;
  String? _userGroup;
  String? _username;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
    _loadGroupNumber();
    _loadWeekType();
    _determineWeek();
    _repairCorruptedData();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('permanent_token');
    });
  }

  Future<void> _loadGroupNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentGroup = prefs.getInt('groupNumber') ?? 1;
    });
  }

  Future<void> _loadWeekType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedWeekType = prefs.getString('weekType');
    });
  }

  Future<void> _loadUserGroup() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userGroup = prefs.getString('user_group');
    });
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
    });
  }

  // ======= Проверка существующего токена при запуске =======
  Future<void> _checkExistingToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('permanent_token');

    if (token != null) {
      setState(() => _loading = true);
      try {
        final url = Uri.parse('$serverBaseUrl/verify-token');
        final res = await http.post(url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            final username = data['username'];
            setState(() {
              _token = token;
              _username = username;
            });
            await _fetchUserGroup(prefs, token);
            print('Auto-login successful for user: $username');
          } else {
            // Токен невалиден, удаляем его
            await prefs.remove('permanent_token');
            print('Token invalid, removed from storage');
          }
        } else {
          await prefs.remove('permanent_token');
          print('Token verification failed, removed from storage');
        }
      } catch (e) {
        print('Token verification error: $e');
        await prefs.remove('permanent_token');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectGroup(int groupNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('groupNumber', groupNumber);
    setState(() {
      _currentGroup = groupNumber;
    });
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.of(context).pop();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Выбрана подгруппа $groupNumber')),
    );
  }

  Future<void> _selectWeekType(String weekType) async {
    final prefs = await SharedPreferences.getInstance();

    if (weekType == 'auto') {
      await prefs.remove('weekType'); // Удаляем настройку для авторежима
    } else {
      await prefs.setString('weekType', weekType);
    }

    setState(() {
      _selectedWeekType = weekType == 'auto' ? null : weekType;
    });

    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.of(context).pop();
    }

    String message = weekType == 'auto'
        ? 'Режим "Авто" - используется текущая неделя'
        : 'Выбрана ${weekType == 'odd' ? 'нечётная' : 'чётная'} неделя';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ======= Выход из профиля =======
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: Text('Выход из профиля'),
            content: Text('Вы уверены, что хотите выйти?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Выйти'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('permanent_token');
      await prefs.remove('username');
      await prefs.remove('user_group');

      setState(() {
        _token = null;
        _username = null;
        _userGroup = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы вышли из профиля')),
      );
    }
  }

  void _determineWeek() {
    DateTime now = DateTime.now();
    int weekOfYear = getWeekNumber(now);
    weekType = (weekOfYear % 2 == 0) ? 'Чётная неделя' : 'Нечётная неделя';
    todayName = DateFormat.EEEE('ru').format(now);
    setState(() {});
  }

  // ======= открытие в браузире =======
  Future<void> _openReplacementsWebsite() async {
    final url = Uri.parse('https://mkgt.ru/a/mkt-zameny.php');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть в браузере')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  // ====== Drawer (выдвигающаяся панель) ======
  Widget _buildDrawer() {
    // Определяем текущую неделю для отображения в заголовке
    DateTime now = DateTime.now();
    int weekOfYear = getWeekNumber(now);
    String currentWeekType = (weekOfYear % 2 == 0) ? 'Чётная' : 'Нечётная';

    String weekTypeDisplay = _selectedWeekType == null
        ? '$currentWeekType (авто)'
        : _selectedWeekType == 'odd' ? 'Нечётная (ручная)' : 'Чётная (ручная)';

    return Drawer(
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 234, 228, 255),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school, size: 32, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ИП-152 Расписание',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_username != null)
                    Text(
                      'Пользователь: $_username',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 2),
                  Text(
                    'Подгруппа: $_currentGroup',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Неделя: $weekTypeDisplay',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  if (_userGroup != null)
                    Text(
                      'Роль: ${_userGroup == 'students'
                          ? 'Студент'
                          : 'Преподаватель'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Выбор подгруппы
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Выбери подгруппу:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.group,
              color: _currentGroup == 1 ? Colors.blue : Colors.grey,
            ),
            title: Text(
              '1 Подгруппа',
              style: TextStyle(
                fontWeight: _currentGroup == 1 ? FontWeight.bold : FontWeight
                    .normal,
                color: _currentGroup == 1 ? Colors.blue : Colors.black,
              ),
            ),
            trailing: _currentGroup == 1
                ? Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () => _selectGroup(1),
          ),
          ListTile(
            leading: Icon(
              Icons.group,
              color: _currentGroup == 2 ? Colors.green : Colors.grey,
            ),
            title: Text(
              '2 Подгруппа',
              style: TextStyle(
                fontWeight: _currentGroup == 2 ? FontWeight.bold : FontWeight
                    .normal,
                color: _currentGroup == 2 ? Colors.green : Colors.black,
              ),
            ),
            trailing: _currentGroup == 2 ? Icon(
                Icons.check, color: Colors.green) : null,
            onTap: () => _selectGroup(2),
          ),

          Divider(),

          // Выбор типа недели
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Выбери тип недели:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.autorenew,
              color: _selectedWeekType == null ? Colors.blue : Colors.grey,
            ),
            title: Text(
              'Авто (текущая)',
              style: TextStyle(
                fontWeight: _selectedWeekType == null
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _selectedWeekType == null ? Colors.blue : Colors.black,
              ),
            ),
            trailing: _selectedWeekType == null ? Icon(
                Icons.check, color: Colors.blue) : null,
            onTap: () => _selectWeekType('auto'),
          ),
          ListTile(
            leading: Icon(
              Icons.filter_1,
              color: _selectedWeekType == 'odd' ? Colors.orange : Colors.grey,
            ),
            title: Text(
              'Нечётная',
              style: TextStyle(
                fontWeight: _selectedWeekType == 'odd'
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _selectedWeekType == 'odd' ? Colors.orange : Colors
                    .black,
              ),
            ),
            trailing: _selectedWeekType == 'odd' ? Icon(
                Icons.check, color: Colors.orange) : null,
            onTap: () => _selectWeekType('odd'),
          ),
          ListTile(
            leading: Icon(
              Icons.filter_2,
              color: _selectedWeekType == 'even' ? Colors.purple : Colors.grey,
            ),
            title: Text(
              'Чётная',
              style: TextStyle(
                fontWeight: _selectedWeekType == 'even'
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _selectedWeekType == 'even' ? Colors.purple : Colors
                    .black,
              ),
            ),
            trailing: _selectedWeekType == 'even' ? Icon(
                Icons.check, color: Colors.purple) : null,
            onTap: () => _selectWeekType('even'),
          ),

          Divider(),

          ListTile(
            leading: Icon(Icons.update, color: Colors.purple),
            title: Text('Замены расписания'),
            onTap: () {
              Navigator.pop(context);
              _openReplacementsWebsite();
            },
          ),

          Divider(),

          // Выход из профиля в меню
          if (_token != null)
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                  'Выйти из профиля', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),

          ListTile(
            leading: Icon(Icons.info),
            title: Text('О приложении'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) =>
                    AlertDialog(
                      title: Text('О приложении'),
                      content: Text('ИП-152 Расписание\nВерсия 1.0'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
    );
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
    // Определяем текущую неделю
    DateTime now = DateTime.now();
    int weekOfYear = getWeekNumber(now);
    String currentWeekType = (weekOfYear % 2 == 0)
        ? 'Чётная неделя'
        : 'Нечётная неделя';

    // Формируем отображаемый текст
    String displayWeekType;
    if (_selectedWeekType == null) {
      displayWeekType =
          currentWeekType; // Авторежим - показываем текущую неделю
    } else if (_selectedWeekType == 'odd') {
      displayWeekType = 'Нечётная неделя (ручная)';
    } else {
      displayWeekType = 'Чётная неделя (ручная)';
    }

    // Проверяем, является ли пользователь студентом
    bool isStudent = _userGroup == 'students';

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('ИП-152 — Расписание'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState!.openDrawer(),
        ),
        actions: [
          // Если пользователь авторизован - показываем кнопку выхода, иначе - кнопку входа
          if (_token != null)
            IconButton(
              tooltip: 'Выйти из профиля',
              icon: Icon(Icons.logout, color: Colors.red),
              onPressed: _logout,
            )
          else
            IconButton(
              tooltip: 'Авторизация',
              icon: Icon(Icons.login),
              onPressed: _showLoginDialog,
            ),

          IconButton(
            tooltip: 'Получить обновления (сервер → клиент)',
            icon: const Icon(Icons.sync),
            onPressed: _fetchUpdates,
          ),
          // Скрываем кнопку облака для студентов
          if (!isStudent && _token != null)
            IconButton(
              tooltip: 'Отправить мои заметки (клиент → сервер)',
              icon: const Icon(Icons.cloud_upload),
              onPressed: _sendLocalNotes,
            ),
        ],
      ),
      drawer: _buildDrawer(),
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
                    title: Text(displayWeekType,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
      builder: (ctx) =>
          AlertDialog(
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

  // ======= Кастомная авторизация =======
  Future<void> _login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Введите username и password')));
      return;
    }
    setState(() => _loading = true);
    try {
      // Используем кастомный endpoint вместо JWT
      final url = Uri.parse('$serverBaseUrl/custom-login');
      final res = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final token = data['token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'permanent_token', token); // Сохраняем постоянный токен
          await prefs.setString('username', username);

          // Получаем группу пользователя
          await _fetchUserGroup(prefs, token);

          setState(() {
            _token = token;
            _username = username;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Авторизация успешна')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data['error'] ?? 'Ошибка авторизации')));
        }
      } else {
        String msg = 'Ошибка входа';
        try {
          final err = jsonDecode(res.body);
          msg = err['error'] ?? res.body;
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
          setState(() {
            _userGroup = group;
          });
        }
      } else if (response.statusCode == 401) {
        // Токен невалиден, выходим
        await _logout();
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
  Future<List<String>> _getSafeNotesList(SharedPreferences prefs,
      String key) async {
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

  // ======= Сортировка заметок по дате (новые сверху) =======
  Future<void> _sortNotesByDate(SharedPreferences prefs, String key) async {
    try {
      List<String> notes = await _getSafeNotesList(prefs, key);
      if (notes.isNotEmpty) {
        // Преобразуем в объекты Note для сортировки
        List<Map<String, dynamic>> noteObjects = [];
        for (String noteStr in notes) {
          try {
            Map<String, dynamic> noteMap = jsonDecode(noteStr);
            noteObjects.add(noteMap);
          } catch (e) {
            print('Error parsing note for sorting: $e');
          }
        }

        // Сортируем по uploadedAt в порядке убывания (новые сверху)
        noteObjects.sort((a, b) {
          int timeA = a['uploaded_at'] is int ? a['uploaded_at'] : 0;
          int timeB = b['uploaded_at'] is int ? b['uploaded_at'] : 0;
          return timeB.compareTo(timeA);
        });

        // Преобразуем обратно в JSON строки
        List<String> sortedNotes = noteObjects
            .map((note) => jsonEncode(note))
            .toList();
        await prefs.setStringList(key, sortedNotes);
      }
    } catch (e) {
      print('Error sorting notes: $e');
    }
  }

  // ======= Отправка локальных заметок на сервер =======
  Future<void> _sendLocalNotes() async {
    final prefs = await SharedPreferences.getInstance();

    // Проверяем авторизацию через состояние
    if (_token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }

    // Дополнительная проверка - студенты не могут отправлять заметки
    if (_userGroup == 'students') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
          content: Text('Студенты не могут отправлять заметки на сервер')));
      return;
    }

    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> notes = [];
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith('notes_'))
          .toList();
      String currentUsername = _username ?? 'Гость';
      int now = DateTime
          .now()
          .millisecondsSinceEpoch;

      for (String key in keys) {
        // Используем безопасное получение данных
        List<String> saved = await _getSafeNotesList(prefs, key);

        for (String s in saved) {
          try {
            var jsonData = jsonDecode(s);
            String text = jsonData['text'] ?? '';
            String id = jsonData['id'] ?? Uuid().v4();

            // Берем автора из самой заметки, а не текущего пользователя
            String author = jsonData['author'] ?? currentUsername;

            if (jsonData['isServer'] == true) {
              continue;
            }

            notes.add({
              'id': id,
              'client_id': _randomClientId(),
              'subject': key.replaceFirst('notes_', ''),
              'text': text,
              'author': author,
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
        'Authorization': 'Bearer $_token' // Используем _token из состояния
      }, body: jsonEncode({'notes': notes}));

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Локальные заметки отправлены на сервер')));
      } else if (res.statusCode == 401) {
        // Токен истек
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Сессия истекла, войдите снова')));
        await _logout();
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

    // Проверяем авторизацию через состояние
    if (_token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Сначала авторизуйтесь')));
      return;
    }

    setState(() => _loading = true);
    try {
      int since = 0;
      print('Fetching updates with since=$since');

      // Получаем ВСЕ обновления без фильтрации по пользователю
      final url = Uri.parse('$serverBaseUrl/notes/updates?since=$since');
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $_token'
      });

      if (res.statusCode == 200) {
        final dynamic responseData = jsonDecode(res.body);

        // КРИТИЧЕСКАЯ ПРОВЕРКА: убедимся что responseData - Map
        if (responseData is! Map<String, dynamic>) {
          throw Exception(
              'Server returned invalid data type: ${responseData.runtimeType}');
        }

        final List<dynamic> notes = responseData['notes'] ?? [];
        int cntAdded = 0;
        int cntUpdated = 0;

        for (final n in notes) {
          final subject = (n['subject'] ?? '').toString();
          final id = n['id']?.toString() ?? '';

          if (id.isEmpty) continue;

          final text = (n['text'] ?? '').toString();
          final uploaded = n['uploaded_at'] is int ? n['uploaded_at'] : DateTime
              .now()
              .millisecondsSinceEpoch;
          final author = n['author_name']?.toString() ??
              n['author_username']?.toString() ?? 'Unknown';

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
            'author': author,
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

          // Сохраняем обновленный список
          await prefs.setStringList(key, list);

          // СОРТИРУЕМ заметки по дате после добавления/обновления
          await _sortNotesByDate(prefs, key);
        }

        final serverTime = responseData['serverTime'] is int
            ? responseData['serverTime']
            : DateTime
            .now()
            .millisecondsSinceEpoch;
        await prefs.setInt('notes_last_sync', serverTime);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            'Получено ${notes
                .length} записей, добавлено: $cntAdded, обновлено: $cntUpdated')));
      } else if (res.statusCode == 401) {
        // Токен истек
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Сессия истекла, войдите снова')));
        await _logout();
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
}