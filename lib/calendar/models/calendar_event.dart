import 'dart:ui';

class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.color,
  });

  final String title;

  final DateTime start;

  final DateTime end;

  final bool allDay;

  final Color? color;

  DateTime get localStart => start.toLocal();

  DateTime get localEnd => end.toLocal();

  bool get hasForeignTimeZone =>
      start.toLocal().timeZoneOffset != start.timeZoneOffset;

  String? get timeZoneLabel => hasForeignTimeZone ? start.timeZoneName : null;
}
