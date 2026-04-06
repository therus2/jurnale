import 'package:flutter/material.dart';

import '../theme_manager.dart';

class AppDrawer extends StatefulWidget {
  final int? currentGroup;
  final String? selectedWeekType;
  final String? weekTypeDisplay;
  final String? username;
  final String? userGroup;
  final Function(int)? onGroupSelect;
  final Function(String)? onWeekTypeSelect;
  final VoidCallback? onLogout;
  final VoidCallback? onReplacementsOpen;
  final String dayTitle;

  const AppDrawer({
    Key? key,
    this.currentGroup,
    this.selectedWeekType,
    this.weekTypeDisplay,
    this.username,
    this.userGroup,
    this.onGroupSelect,
    this.onWeekTypeSelect,
    this.onLogout,
    this.onReplacementsOpen,
    this.dayTitle = 'Меню',
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: ListView(
        // Using ListView fixes overflows
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[900]
                  : const Color.fromARGB(255, 234, 228, 255),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, size: 32, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.dayTitle == 'Меню'
                                ? 'ИП-152 Расписание'
                                : widget.dayTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.username != null)
                      _infoText('Пользователь: ${widget.username}', isDark),
                    _infoText(
                        'Подгруппа: ${widget.currentGroup ?? "-"}', isDark),
                    if (widget.weekTypeDisplay != null)
                      _infoText('Неделя: ${widget.weekTypeDisplay}', isDark),
                    if (widget.userGroup != null)
                      _infoText(
                        'Роль: ${widget.userGroup == 'students' ? 'Студент' : 'Преподаватель'}',
                        isDark,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Выбор подгруппы
          _sectionTitle('Выбери подгруппу:'),
          _groupTile(1, '1 Подгруппа', Colors.blue, widget.currentGroup == 1),
          _groupTile(2, '2 Подгруппа', Colors.green, widget.currentGroup == 2),

          const Divider(),

          // Выбор типа недели
          _sectionTitle('Выбери тип недели:'),
          _weekTypeTile('auto', 'Авто (текущая)', Icons.autorenew, Colors.blue,
              widget.selectedWeekType == null),
          _weekTypeTile('odd', 'Нечётная', Icons.filter_1, Colors.orange,
              widget.selectedWeekType == 'odd'),
          _weekTypeTile('even', 'Чётная', Icons.filter_2, Colors.purple,
              widget.selectedWeekType == 'even'),

          const Divider(),

          if (widget.onReplacementsOpen != null)
            ListTile(
              leading: const Icon(Icons.update, color: Colors.purple),
              title: const Text('Замены расписания'),
              onTap: widget.onReplacementsOpen,
            ),

          const Divider(),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, themeMode, _) {
              final bool localIsDark = themeMode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  localIsDark ? Icons.dark_mode : Icons.light_mode,
                  color: localIsDark ? Colors.amber : Colors.blue,
                ),
                title: const Text('Темная тема'),
                value: localIsDark,
                onChanged: (bool value) async {
                  await ThemeManager.toggleTheme();
                  // For DayScreens that don't listen globally, we might need a callback,
                  // but ValueListenableBuilder usually handles it if they aren't rebuilt.
                  setState(() {});
                },
              );
            },
          ),

          const Divider(),

          if (widget.onLogout != null && widget.username != null)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Выйти из профиля',
                  style: TextStyle(color: Colors.red)),
              onTap: widget.onLogout,
            ),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('О приложении'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('О приложении'),
                  content: const Text('ИП-152 Расписание\nВерсия 2.0'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
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

  Widget _infoText(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _groupTile(
      int group, String label, Color activeColor, bool isSelected) {
    return ListTile(
      leading: Icon(Icons.group, color: isSelected ? activeColor : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? activeColor
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: activeColor) : null,
      onTap: () {
        if (widget.onGroupSelect != null) widget.onGroupSelect!(group);
      },
    );
  }

  Widget _weekTypeTile(String type, String label, IconData icon,
      Color activeColor, bool isSelected) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? activeColor : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? activeColor
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: activeColor) : null,
      onTap: () {
        if (widget.onWeekTypeSelect != null) widget.onWeekTypeSelect!(type);
      },
    );
  }
}
