// app_session.dart
class AppSession {
  static final AppSession _instance = AppSession._();
  factory AppSession() => _instance;
  AppSession._();

  final Map<String, dynamic> scores = {};
}