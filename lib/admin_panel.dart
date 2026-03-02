import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Для serverBaseUrl

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _loading = true;
  List<dynamic> _logs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('permanent_token') ?? '';

      final url = Uri.parse('$serverBaseUrl/admin/activity-log');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _logs = data['logs'] ?? [];
            _loading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Неизвестная ошибка сервера';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Ошибка доступа: ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка подключения к серверу: $e';
        _loading = false;
      });
    }
  }

  Widget _getIconForAction(String action) {
    switch (action) {
      case 'login':
        return const Icon(Icons.login, color: Colors.blue);
      case 'register':
        return const Icon(Icons.person_add, color: Colors.green);
      case 'sync':
        return const Icon(Icons.cloud_sync, color: Colors.purple);
      case 'delete':
        return const Icon(Icons.delete, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      // Формат ДД.ММ.ГГГГ ЧЧ:ММ:СС
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  Future<void> _clearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить все логи?'),
        content: const Text(
            'Все записи активности будут удалены с сервера. Это действие необратимо.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить всё',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('permanent_token') ?? '';
      final url = Uri.parse('$serverBaseUrl/admin/activity-log');
      final response =
          await http.delete(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удалено записей: ${data['deleted']}')),
        );
        _fetchLogs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи активности'),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllLogs,
            tooltip: 'Очистить все логи',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLogs,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchLogs,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _logs.isEmpty
                  ? const Center(
                      child: Text('Событий пока нет',
                          style: TextStyle(fontSize: 16)))
                  : RefreshIndicator(
                      onRefresh: _fetchLogs,
                      child: ListView.separated(
                        itemCount: _logs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final action = log['action'] ?? '';
                          final username = log['username'] ?? 'Неизвестный';
                          final ip = log['ip_address'] ?? 'Неизвестный IP';
                          final actionDisplay = log['action_display'] ?? action;
                          final timestamp = log['timestamp'] ?? '';
                          final extra = log['extra'] ?? '';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              child: _getIconForAction(action),
                            ),
                            title: Text('$actionDisplay ($username)'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(_formatDate(timestamp),
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.computer,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('IP: $ip',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                if (extra.toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(extra,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.blueGrey)),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
                    ),
    );
  }
}
