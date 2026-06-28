abstract class AppEvent {
  const AppEvent();
  String get eventName;
  Map<String, dynamic> toJson();
}
