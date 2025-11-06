import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ReplacementsPage extends StatefulWidget {
  @override
  _ReplacementsPageState createState() => _ReplacementsPageState();
}

class _ReplacementsPageState extends State<ReplacementsPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  int _loadingProgress = 0;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
            // Если прогресс пошел, отменяем таймер
            if (progress > 10) {
              _timeoutTimer?.cancel();
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
              _loadingProgress = 0;
            });
            // Запускаем таймер на 30 секунд
            _timeoutTimer = Timer(Duration(seconds: 30), () {
              if (mounted && _isLoading) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _timeoutTimer?.cancel();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
            _timeoutTimer?.cancel();
          },
          onNavigationRequest: (NavigationRequest request) {
            // Разрешаем все навигационные запросы
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://mkgt.ru/a/mkt-zameny.php'));
  }

  void _reloadPage() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _loadingProgress = 0;
    });
    _timeoutTimer?.cancel();
    _controller.reload();
  }

  void _tryAlternativeUrls() {
    final alternativeUrls = [
      'https://mkgt.ru',
      'https://www.google.com',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Попробовать другой URL'),
        content: Text('Выберите альтернативный адрес для загрузки:'),
        actions: [
          for (final url in alternativeUrls)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _controller.loadRequest(Uri.parse(url));
              },
              child: Text(url),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Замены расписания'),
        backgroundColor: Color.fromARGB(255, 234, 228, 255),
        actions: [
          if (_hasError)
            IconButton(
              icon: Icon(Icons.alternate_email),
              onPressed: _tryAlternativeUrls,
              tooltip: 'Другие URL',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reloadPage,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          // Индикатор прогресса
          if (_isLoading && _loadingProgress < 100)
            LinearProgressIndicator(
              value: _loadingProgress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          Expanded(
            child: _hasError
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить замены',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Проверьте подключение к интернету',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reloadPage,
                    child: Text('Повторить'),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _tryAlternativeUrls,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: Text('Попробовать другой URL'),
                  ),
                ],
              ),
            )
                : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading && _loadingProgress < 100)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Загрузка замен расписания...'),
                          SizedBox(height: 8),
                          Text(
                            '$_loadingProgress%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}