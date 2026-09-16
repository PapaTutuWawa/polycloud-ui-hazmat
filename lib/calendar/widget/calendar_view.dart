import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:polycloud_ui_hazmat/calendar/widget/calendar_allday_layout.dart';
import 'package:polycloud_ui_hazmat/calendar/widget/calendar_drag_layout.dart';
import 'package:polycloud_ui_hazmat/calendar/models/calendar_event.dart';
import 'package:polycloud_ui_hazmat/calendar/widget/calendar_event_layout.dart';
import 'package:polycloud_ui_hazmat/calendar/widget/calendar_grid_painter.dart';

enum CalendarLayout { day, workWeek, week }

typedef CreateEventCallback = Future<void> Function(CalendarEvent event);

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.date,
    required this.events,
    this.layout = CalendarLayout.week,
    this.increment = const Duration(minutes: 30),
    this.dayStart = Duration.zero,
    this.dayEnd = const Duration(hours: 24),
    this.minCellHeight = 22,
    this.gutterWidth = 56,
    this.now,
    this.onCreateEvent,
    this.onEventTapped,
  });

  final DateTime date;

  final List<CalendarEvent> events;

  final CalendarLayout layout;

  final Duration increment;

  final Duration dayStart;

  final Duration dayEnd;

  final double minCellHeight;

  final double gutterWidth;

  final DateTime? now;

  final CreateEventCallback? onCreateEvent;

  final ValueChanged<CalendarEvent>? onEventTapped;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  Timer? _timer;

  CalendarEvent? _draggingEvent;

  CalendarEvent? _pendingEvent;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateDragPreview(CalendarEvent? event) {
    setState(() => _draggingEvent = event);
  }

  Future<void> _commitDrag(CalendarEvent? event) async {
    final create = widget.onCreateEvent;
    if (event == null || create == null) {
      setState(() => _draggingEvent = null);
      return;
    }
    setState(() {
      _draggingEvent = null;
      _pendingEvent = event;
    });
    await create(event);
    if (!mounted) {
      return;
    }
    setState(() => _pendingEvent = null);
  }

  List<DateTime> get _days {
    final base =
        DateTime(widget.date.year, widget.date.month, widget.date.day);
    final monday = base.subtract(Duration(days: base.weekday - 1));
    switch (widget.layout) {
      case CalendarLayout.day:
        return [base];
      case CalendarLayout.workWeek:
        return List.generate(5, (index) => monday.add(Duration(days: index)));
      case CalendarLayout.week:
        return List.generate(7, (index) => monday.add(Duration(days: index)));
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.dayEnd > widget.dayStart, 'dayEnd must be after dayStart');
    assert(widget.increment > Duration.zero, 'increment must be positive');

    final now = widget.now ?? DateTime.now();
    final days = _days;
    final transient = <CalendarEvent>[
      ?_draggingEvent,
      ?_pendingEvent,
    ];
    final previewEvents = Set<CalendarEvent>.identity()..addAll(transient);
    final allDayEvents = [
      ...widget.events.where((event) => event.allDay),
      ...transient.where((event) => event.allDay),
    ];
    final timedEvents = [
      ...widget.events.where((event) => !event.allDay),
      ...transient.where((event) => !event.allDay),
    ];
    final total = widget.dayEnd - widget.dayStart;
    final cellCount = math.max(
      1,
      (total.inMicroseconds / widget.increment.inMicroseconds).ceil(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CalendarHeader(
          days: days,
          gutterWidth: widget.gutterWidth,
          now: now,
          events: allDayEvents,
          previewEvents: previewEvents,
          enableDrag: widget.onCreateEvent != null,
          onPreview: _updateDragPreview,
          onCommit: _commitDrag,
          onEventTapped: widget.onEventTapped,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fitCellHeight = constraints.maxHeight / cellCount;
              final scrolls = fitCellHeight < widget.minCellHeight;
              final cellHeight =
                  scrolls ? widget.minCellHeight : fitCellHeight;
              final bodyHeight =
                  scrolls ? cellHeight * cellCount : constraints.maxHeight;

              final body = SizedBox(
                height: bodyHeight,
                child: _CalendarBody(
                  days: days,
                  events: timedEvents,
                  dayStart: widget.dayStart,
                  dayEnd: widget.dayEnd,
                  increment: widget.increment,
                  cellCount: cellCount,
                  cellHeight: cellHeight,
                  bodyHeight: bodyHeight,
                  gutterWidth: widget.gutterWidth,
                  now: now,
                  previewEvents: previewEvents,
                  onDragPreview:
                      widget.onCreateEvent == null ? null : _updateDragPreview,
                  onDragCommit:
                      widget.onCreateEvent == null ? null : _commitDrag,
                  onEventTapped: widget.onEventTapped,
                ),
              );

              if (!scrolls) {
                return body;
              }
              return SingleChildScrollView(child: body);
            },
          ),
        ),
      ],
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.days,
    required this.events,
    required this.dayStart,
    required this.dayEnd,
    required this.increment,
    required this.cellCount,
    required this.cellHeight,
    required this.bodyHeight,
    required this.gutterWidth,
    required this.now,
    this.previewEvents = const {},
    this.onDragPreview,
    this.onDragCommit,
    this.onEventTapped,
  });

  final List<DateTime> days;

  final List<CalendarEvent> events;

  final Duration dayStart;

  final Duration dayEnd;

  final Duration increment;

  final int cellCount;

  final double cellHeight;

  final double bodyHeight;

  final double gutterWidth;

  final DateTime now;

  final Set<CalendarEvent> previewEvents;

  final ValueChanged<CalendarEvent?>? onDragPreview;

  final ValueChanged<CalendarEvent?>? onDragCommit;

  final ValueChanged<CalendarEvent>? onEventTapped;

  double? get _nowLineTop {
    final isVisible = days.any(
      (day) =>
          day.year == now.year && day.month == now.month && day.day == now.day,
    );
    if (!isVisible) {
      return null;
    }

    final midnight = DateTime(now.year, now.month, now.day);
    final offset = now.difference(midnight);
    if (offset < dayStart || offset > dayEnd) {
      return null;
    }

    final total = dayEnd - dayStart;
    return (offset - dayStart).inMicroseconds /
        total.inMicroseconds *
        bodyHeight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nowLineTop = _nowLineTop;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimeGutter(
          cellCount: cellCount,
          cellHeight: cellHeight,
          dayStart: dayStart,
          increment: increment,
          width: gutterWidth,
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: _DayColumn(
                          day: day,
                          events: events,
                          dayStart: dayStart,
                          dayEnd: dayEnd,
                          cellCount: cellCount,
                          cellHeight: cellHeight,
                          previewEvents: previewEvents,
                          onEventTapped: onEventTapped,
                        ),
                      ),
                  ],
                ),
              ),
              if (nowLineTop != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: nowLineTop,
                  child: IgnorePointer(
                    child: Container(
                      height: 2,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (onDragPreview != null && onDragCommit != null)
                Positioned.fill(
                  child: _TimedDragLayer(
                    days: days,
                    events: events,
                    dayStart: dayStart,
                    dayEnd: dayEnd,
                    increment: increment,
                    cellCount: cellCount,
                    bodyHeight: bodyHeight,
                    onPreview: onDragPreview!,
                    onCommit: onDragCommit!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.days,
    required this.gutterWidth,
    required this.now,
    required this.events,
    required this.previewEvents,
    required this.enableDrag,
    required this.onPreview,
    required this.onCommit,
    this.onEventTapped,
  });

  final List<DateTime> days;

  final double gutterWidth;

  final DateTime now;

  final List<CalendarEvent> events;

  final Set<CalendarEvent> previewEvents;

  final bool enableDrag;

  final ValueChanged<CalendarEvent?> onPreview;

  final ValueChanged<CalendarEvent?> onCommit;

  final ValueChanged<CalendarEvent>? onEventTapped;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayHeaderRow(days: days, gutterWidth: gutterWidth, now: now),
        _AllDayStrip(
          days: days,
          events: events,
          gutterWidth: gutterWidth,
          previewEvents: previewEvents,
          reserveLane: enableDrag,
          onEventTapped: onEventTapped,
        ),
      ],
    );

    if (!enableDrag) {
      return column;
    }

    return Stack(
      children: [
        column,
        Positioned(
          left: gutterWidth,
          top: 0,
          right: 0,
          bottom: 0,
          child: _AllDayDragLayer(
            days: days,
            onPreview: onPreview,
            onCommit: onCommit,
          ),
        ),
      ],
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.days,
    required this.gutterWidth,
    required this.now,
  });

  final List<DateTime> days;

  final double gutterWidth;

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdayStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final dayStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        SizedBox(width: gutterWidth),
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(_weekdayNames[day.weekday - 1], style: weekdayStyle),
                  const SizedBox(height: 2),
                  _DayBadge(
                    day: day,
                    isToday: day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day,
                    style: dayStyle,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.day,
    required this.isToday,
    required this.style,
  });

  final DateTime day;

  final bool isToday;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: isToday
          ? BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            )
          : null,
      child: Text(
        '${day.day}',
        style: isToday
            ? style?.copyWith(color: theme.colorScheme.onPrimary)
            : style,
      ),
    );
  }
}

class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({
    required this.days,
    required this.events,
    required this.gutterWidth,
    this.previewEvents = const {},
    this.reserveLane = false,
    this.onEventTapped,
  });

  final List<DateTime> days;

  final List<CalendarEvent> events;

  final double gutterWidth;

  final Set<CalendarEvent> previewEvents;

  final bool reserveLane;

  final ValueChanged<CalendarEvent>? onEventTapped;

  static const double _rowHeight = 22;

  @override
  Widget build(BuildContext context) {
    final laidOut = layoutAllDayEvents(events: events, days: days);
    final laneCount =
        laidOut.isEmpty ? (reserveLane ? 1 : 0) : laidOut.first.laneCount;
    if (laneCount == 0) {
      return const SizedBox.shrink();
    }

    final height = laneCount * _rowHeight + 6;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: gutterWidth),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = constraints.maxWidth / days.length;
                return Stack(
                  children: [
                    for (final item in laidOut)
                      Positioned(
                        left: item.startIndex * columnWidth + 1,
                        top: item.lane * _rowHeight + 3,
                        width: math.max(
                          0.0,
                          (item.endIndex - item.startIndex) * columnWidth - 2,
                        ),
                        height: _rowHeight - 2,
                        child: _EventBox(
                          event: item.event,
                          color: _eventFill(item.event),
                          showTime: false,
                          preview: previewEvents.contains(item.event),
                          onTap: previewEvents.contains(item.event)
                              ? null
                              : onEventTapped,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter({
    required this.cellCount,
    required this.cellHeight,
    required this.dayStart,
    required this.increment,
    required this.width,
  });

  final int cellCount;

  final double cellHeight;

  final Duration dayStart;

  final Duration increment;

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cellCount; index++)
            SizedBox(
              height: cellHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text(
                      _formatTime(dayStart + increment * index),
                      style: style,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.events,
    required this.dayStart,
    required this.dayEnd,
    required this.cellCount,
    required this.cellHeight,
    this.previewEvents = const {},
    this.onEventTapped,
  });

  final DateTime day;

  final List<CalendarEvent> events;

  final Duration dayStart;

  final Duration dayEnd;

  final int cellCount;

  final double cellHeight;

  final Set<CalendarEvent> previewEvents;

  final ValueChanged<CalendarEvent>? onEventTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final laidOut = layoutDayEvents(
      events: events,
      day: day,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
    final midnight = DateTime(day.year, day.month, day.day);
    final totalMicros = (dayEnd - dayStart).inMicroseconds;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bodyHeight = constraints.maxHeight;
          final columnWidth = constraints.maxWidth;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CalendarGridPainter(
                    cellCount: cellCount,
                    cellHeight: cellHeight,
                    columnCount: 1,
                    color: theme.dividerColor,
                  ),
                ),
              ),
              for (final item in laidOut)
                _positionedEvent(
                  item: item,
                  midnight: midnight,
                  totalMicros: totalMicros,
                  bodyHeight: bodyHeight,
                  columnWidth: columnWidth,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedEvent({
    required LaidOutEvent item,
    required DateTime midnight,
    required int totalMicros,
    required double bodyHeight,
    required double columnWidth,
  }) {
    final startMicros = item.start.difference(midnight).inMicroseconds;
    final endMicros = item.end.difference(midnight).inMicroseconds;
    final rangeStartMicros = dayStart.inMicroseconds;
    final fractionTop = (startMicros - rangeStartMicros) / totalMicros;
    final fractionHeight = (endMicros - startMicros) / totalMicros;

    final laneWidth = columnWidth / item.laneCount;
    final top = fractionTop * bodyHeight;
    final height = fractionHeight * bodyHeight;
    final left = item.lane * laneWidth;

    return Positioned(
      top: top + 1,
      left: left + 1,
      width: math.max(0.0, laneWidth - 2),
      height: math.max(14.0, height - 2),
      child: _EventBox(
        event: item.event,
        color: _eventFill(item.event),
        preview: previewEvents.contains(item.event),
        onTap: previewEvents.contains(item.event) ? null : onEventTapped,
      ),
    );
  }
}

class _TimedDragLayer extends StatefulWidget {
  const _TimedDragLayer({
    required this.days,
    required this.events,
    required this.dayStart,
    required this.dayEnd,
    required this.increment,
    required this.cellCount,
    required this.bodyHeight,
    required this.onPreview,
    required this.onCommit,
  });

  final List<DateTime> days;

  final List<CalendarEvent> events;

  final Duration dayStart;

  final Duration dayEnd;

  final Duration increment;

  final int cellCount;

  final double bodyHeight;

  final ValueChanged<CalendarEvent?> onPreview;

  final ValueChanged<CalendarEvent?> onCommit;

  @override
  State<_TimedDragLayer> createState() => _TimedDragLayerState();
}

class _TimedDragLayerState extends State<_TimedDragLayer> {
  Offset? _anchor;

  Offset? _current;

  Offset? _tapPosition;

  Offset? _doubleTapCommitPosition;

  Timer? _doubleTapTimer;

  bool _active = false;

  bool _dragged = false;

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  double get _columnWidth {
    final size = context.size;
    if (size == null || widget.days.isEmpty) {
      return 0;
    }
    return size.width / widget.days.length;
  }

  CalendarEvent? _eventFor(Offset anchor, Offset current) {
    return timedDragEvent(
      anchor: anchor,
      current: current,
      days: widget.days,
      columnWidth: _columnWidth,
      bodyHeight: widget.bodyHeight,
      cellCount: widget.cellCount,
      dayStart: widget.dayStart,
      dayEnd: widget.dayEnd,
      increment: widget.increment,
    );
  }

  CalendarEvent? _selection() {
    final anchor = _anchor;
    final current = _current;
    if (anchor == null || current == null) {
      return null;
    }
    return _eventFor(anchor, current);
  }

  void _handleDown(DragDownDetails details) {
    final position = details.localPosition;
    final previousTap = _tapPosition;
    if (_doubleTapTimer != null &&
        previousTap != null &&
        (position - previousTap).distance <= kDoubleTapSlop) {
      _cancelDoubleTapTimer();
      _reset();
      _doubleTapCommitPosition = position;
      widget.onPreview(_eventFor(position, position));
      return;
    }
    _doubleTapCommitPosition = null;
    _tapPosition = position;
    _cancelDoubleTapTimer();
    _doubleTapTimer = Timer(kDoubleTapTimeout, () => _doubleTapTimer = null);

    final width = _columnWidth;
    if (width <= 0) {
      _active = false;
      return;
    }
    _active = _isFreeAt(position);
    _dragged = false;
    _anchor = position;
    _current = position;
  }

  bool _isFreeAt(Offset position) {
    final day = dayAt(widget.days, position.dx, _columnWidth);
    final fraction = (position.dy / widget.bodyHeight).clamp(0.0, 1.0);
    final at =
        day.add(widget.dayStart + (widget.dayEnd - widget.dayStart) * fraction);
    return !isTimeOccupied(
      events: widget.events,
      day: day,
      dayStart: widget.dayStart,
      dayEnd: widget.dayEnd,
      at: at,
    );
  }

  void _handleUpdate(DragUpdateDetails details) {
    final pending = _doubleTapCommitPosition;
    if (pending != null) {
      if ((details.localPosition - pending).distance > kTouchSlop) {
        _doubleTapCommitPosition = null;
        widget.onPreview(null);
      }
      return;
    }
    if (!_active) {
      return;
    }
    final anchor = _anchor;
    _current = details.localPosition;
    if (anchor != null &&
        (details.localPosition - anchor).distance > kTouchSlop) {
      _dragged = true;
      _cancelDoubleTapTimer();
    }
    widget.onPreview(_selection());
  }

  void _handleEnd(DragEndDetails details) {
    final pending = _doubleTapCommitPosition;
    if (pending != null) {
      _doubleTapCommitPosition = null;
      _reset();
      widget.onCommit(_eventFor(pending, pending));
      return;
    }
    if (!_active || !_dragged) {
      _reset();
      return;
    }
    _cancelDoubleTapTimer();
    final selection = _selection();
    _reset();
    widget.onPreview(null);
    widget.onCommit(selection);
  }

  void _handleCancel() {
    if (_doubleTapCommitPosition != null) {
      _doubleTapCommitPosition = null;
      widget.onPreview(null);
    }
    if (_active && _dragged) {
      widget.onPreview(null);
    }
    _reset();
  }

  void _cancelDoubleTapTimer() {
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
  }

  void _reset() {
    _active = false;
    _dragged = false;
    _anchor = null;
    _current = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('calendar-timed-drag'),
      behavior: HitTestBehavior.translucent,
      onPanDown: _handleDown,
      onPanUpdate: _handleUpdate,
      onPanEnd: _handleEnd,
      onPanCancel: _handleCancel,
    );
  }
}

class _AllDayDragLayer extends StatefulWidget {
  const _AllDayDragLayer({
    required this.days,
    required this.onPreview,
    required this.onCommit,
  });

  final List<DateTime> days;

  final ValueChanged<CalendarEvent?> onPreview;

  final ValueChanged<CalendarEvent?> onCommit;

  @override
  State<_AllDayDragLayer> createState() => _AllDayDragLayerState();
}

class _AllDayDragLayerState extends State<_AllDayDragLayer> {
  Offset? _anchor;

  Offset? _current;

  Offset? _tapPosition;

  Offset? _doubleTapCommitPosition;

  Timer? _doubleTapTimer;

  bool _active = false;

  bool _dragged = false;

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  CalendarEvent? _eventFor(Offset anchor, Offset current) {
    final size = context.size;
    if (size == null) {
      return null;
    }
    return allDayDragEvent(
      anchor: anchor,
      current: current,
      days: widget.days,
      columnWidth: widget.days.isEmpty ? 0 : size.width / widget.days.length,
    );
  }

  CalendarEvent? _selection() {
    final anchor = _anchor;
    final current = _current;
    if (anchor == null || current == null) {
      return null;
    }
    return _eventFor(anchor, current);
  }

  void _handleDown(DragDownDetails details) {
    final position = details.localPosition;
    final previousTap = _tapPosition;
    if (_doubleTapTimer != null &&
        previousTap != null &&
        (position - previousTap).distance <= kDoubleTapSlop) {
      _cancelDoubleTapTimer();
      _reset();
      _doubleTapCommitPosition = position;
      widget.onPreview(_eventFor(position, position));
      return;
    }
    _doubleTapCommitPosition = null;
    _tapPosition = position;
    _cancelDoubleTapTimer();
    _doubleTapTimer = Timer(kDoubleTapTimeout, () => _doubleTapTimer = null);

    _anchor = position;
    _current = position;
    _active = true;
    _dragged = false;
  }

  void _handleUpdate(DragUpdateDetails details) {
    final pending = _doubleTapCommitPosition;
    if (pending != null) {
      if ((details.localPosition - pending).distance > kTouchSlop) {
        _doubleTapCommitPosition = null;
        widget.onPreview(null);
      }
      return;
    }
    if (!_active) {
      return;
    }
    final anchor = _anchor;
    _current = details.localPosition;
    if (anchor != null &&
        (details.localPosition - anchor).distance > kTouchSlop) {
      _dragged = true;
      _cancelDoubleTapTimer();
    }
    widget.onPreview(_selection());
  }

  void _handleEnd(DragEndDetails details) {
    final pending = _doubleTapCommitPosition;
    if (pending != null) {
      _doubleTapCommitPosition = null;
      _reset();
      widget.onCommit(_eventFor(pending, pending));
      return;
    }
    if (!_active || !_dragged) {
      _reset();
      return;
    }
    _cancelDoubleTapTimer();
    final selection = _selection();
    _reset();
    widget.onPreview(null);
    widget.onCommit(selection);
  }

  void _handleCancel() {
    if (_doubleTapCommitPosition != null) {
      _doubleTapCommitPosition = null;
      widget.onPreview(null);
    }
    if (_active && _dragged) {
      widget.onPreview(null);
    }
    _reset();
  }

  void _cancelDoubleTapTimer() {
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
  }

  void _reset() {
    _active = false;
    _dragged = false;
    _anchor = null;
    _current = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('calendar-allday-drag'),
      behavior: HitTestBehavior.translucent,
      onPanDown: _handleDown,
      onPanUpdate: _handleUpdate,
      onPanEnd: _handleEnd,
      onPanCancel: _handleCancel,
    );
  }
}

class _EventBox extends StatelessWidget {
  const _EventBox({
    required this.event,
    required this.color,
    this.showTime,
    this.preview = false,
    this.onTap,
  });

  final CalendarEvent event;

  final Color color;

  final bool? showTime;

  final bool preview;

  final ValueChanged<CalendarEvent>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.85),
    );
    final zone = event.timeZoneLabel;
    final timeLabel =
        '${_formatClock(event.start)} - ${_formatClock(event.end)}'
        '${zone == null ? '' : ' ($zone)'}';
    final title = event.title.isEmpty ? 'New event' : event.title;
    final tapHandler = onTap;
    final fill = preview ? color.withValues(alpha: 0.5) : color;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Material(
        color: fill,
        child: InkWell(
          onTap: tapHandler == null ? null : () => tapHandler(event),
          mouseCursor:
              tapHandler == null ? MouseCursor.defer : SystemMouseCursors.click,
          splashColor: Colors.white.withValues(alpha: 0.28),
          highlightColor: Colors.white.withValues(alpha: 0.14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 4,
                child: ColoredBox(color: _lighten(color)),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final withTime =
                          showTime ?? constraints.maxHeight >= 30;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          if (withTime)
                            Text(
                              timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: timeStyle,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _eventPalette = [
  Color(0xFF4C6EF5),
  Color(0xFF12B886),
  Color(0xFFF76707),
  Color(0xFF7048E8),
  Color(0xFFE8590C),
  Color(0xFF1098AD),
  Color(0xFFD6336C),
  Color(0xFF37B24D),
];

Color _eventFill(CalendarEvent event) =>
    event.color ?? _eventColor(event.title);

Color _lighten(Color color) => Color.lerp(color, const Color(0xFFFFFFFF), 0.5)!;

Color _eventColor(String name) {
  var hash = 0;
  for (final code in name.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _eventPalette[hash % _eventPalette.length];
}

String _formatTime(Duration offset) {
  final hours = offset.inHours;
  final minutes = offset.inMinutes.remainder(60);
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

String _formatClock(DateTime time) {
  final local = time.toLocal();
  return _formatTime(
    Duration(hours: local.hour, minutes: local.minute),
  );
}
