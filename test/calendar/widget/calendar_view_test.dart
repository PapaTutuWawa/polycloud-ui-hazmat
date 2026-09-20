import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycloud_ui_hazmat/calendar/widget/calendar_drag_layout.dart';
import 'package:polycloud_ui_hazmat/calendar/models/calendar_event.dart';
import 'package:polycloud_ui_hazmat/calendar/widget/calendar_view.dart';

const _timedLayer = Key('calendar-timed-drag');
const _allDayLayer = Key('calendar-allday-drag');

void main() {
  group('timedDragEvent', () {
    test('snaps a single cell to one increment', () {
      final event = timedDragEvent(
        anchor: const Offset(10, 9.4 * 30),
        current: const Offset(10, 9.6 * 30),
        days: [DateTime(2026, 9, 14)],
        columnWidth: 100,
        bodyHeight: 30 * 24,
        cellCount: 24,
        dayStart: Duration.zero,
        dayEnd: const Duration(hours: 24),
        increment: const Duration(hours: 1),
      );
      expect(event, isNotNull);
      expect(event!.start, DateTime(2026, 9, 14, 9));
      expect(event.end, DateTime(2026, 9, 14, 10));
    });

    test('spans multiple rows and columns', () {
      final event = timedDragEvent(
        anchor: const Offset(10, 9.5 * 30),
        current: const Offset(150, 10.5 * 30),
        days: [DateTime(2026, 9, 14), DateTime(2026, 9, 15)],
        columnWidth: 100,
        bodyHeight: 30 * 24,
        cellCount: 24,
        dayStart: Duration.zero,
        dayEnd: const Duration(hours: 24),
        increment: const Duration(hours: 1),
      );
      expect(event!.start, DateTime(2026, 9, 14, 9));
      expect(event.end, DateTime(2026, 9, 15, 11));
    });

    test('returns null without columns', () {
      expect(
        timedDragEvent(
          anchor: const Offset(10, 10),
          current: const Offset(10, 20),
          days: const [],
          columnWidth: 100,
          bodyHeight: 100,
          cellCount: 4,
          dayStart: Duration.zero,
          dayEnd: const Duration(hours: 24),
          increment: const Duration(hours: 6),
        ),
        isNull,
      );
    });
  });

  group('allDayDragEvent', () {
    test('single day is exclusive of the next midnight', () {
      final event = allDayDragEvent(
        anchor: const Offset(10, 0),
        current: const Offset(20, 0),
        days: List.generate(7, (i) => DateTime(2026, 9, 14 + i)),
        columnWidth: 100,
      );
      expect(event!.start, DateTime(2026, 9, 14));
      expect(event.end, DateTime(2026, 9, 15));
      expect(event.allDay, isTrue);
    });

    test('spans several days', () {
      final event = allDayDragEvent(
        anchor: const Offset(150, 0),
        current: const Offset(350, 0),
        days: List.generate(7, (i) => DateTime(2026, 9, 14 + i)),
        columnWidth: 100,
      );
      expect(event!.start, DateTime(2026, 9, 15));
      expect(event.end, DateTime(2026, 9, 18));
    });
  });

  group('isTimeOccupied', () {
    final events = [
      CalendarEvent(
        id: '',
        title: 'Busy',
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
      ),
    ];

    test('true inside an event', () {
      expect(
        isTimeOccupied(
          events: events,
          day: DateTime(2026, 9, 14),
          dayStart: Duration.zero,
          dayEnd: const Duration(hours: 24),
          at: DateTime(2026, 9, 14, 9, 30),
        ),
        isTrue,
      );
    });

    test('false outside an event', () {
      expect(
        isTimeOccupied(
          events: events,
          day: DateTime(2026, 9, 14),
          dayStart: Duration.zero,
          dayEnd: const Duration(hours: 24),
          at: DateTime(2026, 9, 14, 11),
        ),
        isFalse,
      );
    });
  });

  group('CalendarView create events', () {
    Future<void> pump(
      WidgetTester tester, {
      List<CalendarEvent> events = const [],
      CalendarLayout layout = CalendarLayout.day,
      CreateEventCallback? onCreateEvent,
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarView(
              date: DateTime(2026, 9, 14),
              events: events,
              layout: layout,
              increment: const Duration(hours: 1),
              onCreateEvent: onCreateEvent,
            ),
          ),
        ),
      );
    }

    testWidgets('no drag layer without a callback', (tester) async {
      await pump(tester);
      expect(find.byKey(_timedLayer), findsNothing);
      expect(find.byKey(_allDayLayer), findsNothing);
    });

    testWidgets('body drag previews and reports the transient event',
        (tester) async {
      final completer = Completer<void>();
      CalendarEvent? reported;

      await pump(
        tester,
        onCreateEvent: (event) {
          reported = event;
          return completer.future;
        },
      );

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;
      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 9.5 * cell),
      );
      await gesture.moveTo(Offset(rect.center.dx, rect.top + 10.5 * cell));
      await tester.pump();

      expect(find.text('New event'), findsOneWidget);

      await gesture.up();
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.start, DateTime(2026, 9, 14, 9));
      expect(reported!.end, DateTime(2026, 9, 14, 11));
      expect(reported!.allDay, isFalse);
      expect(find.text('New event'), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsNothing);
    });

    testWidgets('transient is removed after the callback completes',
        (tester) async {
      await pump(tester, onCreateEvent: (event) async {});

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;
      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 12.2 * cell),
      );
      await gesture.moveTo(Offset(rect.center.dx, rect.top + 12.8 * cell));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('New event'), findsNothing);
    });

    testWidgets('cannot start on top of an existing event', (tester) async {
      var called = false;
      await pump(
        tester,
        events: [
          CalendarEvent(
            id: '',
            title: 'Busy',
            start: DateTime(2026, 9, 14, 9),
            end: DateTime(2026, 9, 14, 10),
          ),
        ],
        onCreateEvent: (event) async {
          called = true;
        },
      );

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;
      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 9.3 * cell),
      );
      await gesture.moveTo(Offset(rect.center.dx, rect.top + 11.5 * cell));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('New event'), findsNothing);
    });

    testWidgets('header drag below the day numbers is all-day',
        (tester) async {
      CalendarEvent? reported;

      await pump(
        tester,
        layout: CalendarLayout.week,
        onCreateEvent: (event) async {
          reported = event;
        },
      );

      final rect = tester.getRect(find.byKey(_allDayLayer));
      final column = rect.width / 7;
      final gesture = await tester.startGesture(
        Offset(rect.left + 2.5 * column, rect.bottom - 4),
      );
      await gesture.moveTo(
        Offset(rect.left + 4.5 * column, rect.bottom - 4),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported, isNotNull);
      expect(reported!.allDay, isTrue);
      expect(reported!.start, DateTime(2026, 9, 16));
      expect(reported!.end, DateTime(2026, 9, 19));
    });

    testWidgets('a single tap creates nothing', (tester) async {
      var called = false;

      await pump(tester, onCreateEvent: (event) async => called = true);

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;
      await tester.tapAt(Offset(rect.center.dx, rect.top + 8.5 * cell));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('New event'), findsNothing);
    });

    testWidgets('body double-click creates a single cell event',
        (tester) async {
      final completer = Completer<void>();
      CalendarEvent? reported;

      await pump(
        tester,
        onCreateEvent: (event) {
          reported = event;
          return completer.future;
        },
      );

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;
      final point = Offset(rect.center.dx, rect.top + 9.5 * cell);

      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(point);
      await tester.pump();

      expect(reported, isNotNull);
      expect(reported!.start, DateTime(2026, 9, 14, 9));
      expect(reported!.end, DateTime(2026, 9, 14, 10));
      expect(reported!.allDay, isFalse);
      expect(find.text('New event'), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('New event'), findsNothing);
    });

    testWidgets('header double-click creates a single day all-day event',
        (tester) async {
      CalendarEvent? reported;

      await pump(
        tester,
        layout: CalendarLayout.week,
        onCreateEvent: (event) async {
          reported = event;
        },
      );

      final rect = tester.getRect(find.byKey(_allDayLayer));
      final column = rect.width / 7;
      final point = Offset(rect.left + 2.5 * column, rect.center.dy);

      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(point);
      await tester.pumpAndSettle();

      expect(reported, isNotNull);
      expect(reported!.allDay, isTrue);
      expect(reported!.start, DateTime(2026, 9, 16));
      expect(reported!.end, DateTime(2026, 9, 17));
    });

    testWidgets('double-click triggers on the second release',
        (tester) async {
      CalendarEvent? reported;

      await pump(tester, onCreateEvent: (event) async => reported = event);

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;
      final point = Offset(rect.center.dx, rect.top + 9.5 * cell);

      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));

      final second = await tester.startGesture(point);
      await tester.pump();
      expect(reported, isNull);

      await second.up();
      await tester.pump();
      expect(reported, isNotNull);
      expect(reported!.start, DateTime(2026, 9, 14, 9));
      expect(reported!.end, DateTime(2026, 9, 14, 10));
    });

    testWidgets('a tap then a drag elsewhere does not create twice',
        (tester) async {
      final reported = <CalendarEvent>[];

      await pump(
        tester,
        onCreateEvent: (event) async => reported.add(event),
      );

      final rect = tester.getRect(find.byKey(_timedLayer));
      final cell = rect.height / 24;

      await tester.tapAt(Offset(rect.center.dx, rect.top + 3.5 * cell));
      await tester.pump(const Duration(milliseconds: 50));

      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 9.5 * cell),
      );
      await gesture.moveTo(Offset(rect.center.dx, rect.top + 11.5 * cell));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported, hasLength(1));
      expect(reported.single.start, DateTime(2026, 9, 14, 9));
      expect(reported.single.end, DateTime(2026, 9, 14, 12));
    });

    testWidgets('header drag creates a multi-day all-day event',
        (tester) async {
      CalendarEvent? reported;

      await pump(
        tester,
        layout: CalendarLayout.week,
        onCreateEvent: (event) async {
          reported = event;
        },
      );

      final rect = tester.getRect(find.byKey(_allDayLayer));
      final column = rect.width / 7;
      final gesture = await tester.startGesture(
        Offset(rect.left + 1.5 * column, rect.center.dy),
      );
      await gesture.moveTo(Offset(rect.left + 3.5 * column, rect.center.dy));
      await tester.pump();

      expect(find.text('New event'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(reported, isNotNull);
      expect(reported!.allDay, isTrue);
      expect(reported!.start, DateTime(2026, 9, 15));
      expect(reported!.end, DateTime(2026, 9, 18));
    });
  });

  group('CalendarView event interaction', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<CalendarEvent> events,
      CalendarLayout layout = CalendarLayout.day,
      ValueChanged<CalendarEvent>? onEventTapped,
      CreateEventCallback? onCreateEvent,
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarView(
              date: DateTime(2026, 9, 14),
              events: events,
              layout: layout,
              increment: const Duration(hours: 1),
              onEventTapped: onEventTapped,
              onCreateEvent: onCreateEvent,
            ),
          ),
        ),
      );
    }

    testWidgets('tapping a timed event reports it', (tester) async {
      CalendarEvent? tapped;
      var created = false;
      final event = CalendarEvent(
        id: '',
        title: 'Meeting',
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
      );

      await pump(
        tester,
        events: [event],
        onCreateEvent: (event) async => created = true,
        onEventTapped: (value) => tapped = value,
      );

      await tester.tap(find.text('Meeting'));
      await tester.pump();

      expect(tapped, same(event));
      expect(created, isFalse);

      final regions = tester.widgetList<MouseRegion>(
        find.ancestor(
          of: find.text('Meeting'),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(
        regions.any((region) => region.cursor == SystemMouseCursors.click),
        isTrue,
      );
    });

    testWidgets('tapping an all-day event reports it', (tester) async {
      CalendarEvent? tapped;
      final event = CalendarEvent(
        id: '',
        title: 'Holiday',
        start: DateTime(2026, 9, 15),
        end: DateTime(2026, 9, 16),
        allDay: true,
      );

      await pump(
        tester,
        events: [event],
        layout: CalendarLayout.week,
        onCreateEvent: (event) async {},
        onEventTapped: (value) => tapped = value,
      );

      await tester.tap(find.text('Holiday'));
      await tester.pump();

      expect(tapped, same(event));
    });

    testWidgets('uses the color configured on the DTO', (tester) async {
      const custom = Color(0xFF123456);
      final event = CalendarEvent(
        id: '',
        title: 'Custom',
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
        color: custom,
      );

      await pump(tester, events: [event]);

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == custom,
        ),
        findsOneWidget,
      );
    });

    testWidgets('left border is 4px and a lighter shade of the event color',
        (tester) async {
      const custom = Color(0xFF123456);
      final event = CalendarEvent(
        id: '',
        title: 'Bordered',
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
        color: custom,
      );

      await pump(tester, events: [event]);

      final lighter = Color.lerp(custom, const Color(0xFFFFFFFF), 0.5)!;
      final border = find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == lighter,
      );
      expect(border, findsOneWidget);

      final sized = tester.widget<SizedBox>(
        find.ancestor(of: border, matching: find.byType(SizedBox)).first,
      );
      expect(sized.width, 4);
    });

    testWidgets('falls back to the palette color without a DTO color',
        (tester) async {
      final event = CalendarEvent(
        id: '',
        title: 'Default',
        start: DateTime(2026, 9, 14, 9),
        end: DateTime(2026, 9, 14, 10),
      );

      await pump(tester, events: [event]);

      expect(event.color, isNull);
      expect(find.text('Default'), findsOneWidget);
    });
  });
}
