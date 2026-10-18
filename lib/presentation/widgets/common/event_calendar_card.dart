import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Lifecycle state supplied by the caller; the widget does not derive dates
/// or convert timezones.
enum EventCalendarStatus { upcoming, active, ended }

/// One event on a caller-authored calendar.
@immutable
class EventCalendarItem {
  const EventCalendarItem({
    required this.id,
    required this.dayLabel,
    required this.title,
    required this.timeLabel,
    required this.status,
    this.icon = Icons.event_rounded,
  });

  final String id;
  final String dayLabel;
  final String title;
  final String timeLabel;
  final EventCalendarStatus status;
  final IconData icon;
}

/// Week event calendar with caller-supplied labels, status and ordering.
///
/// Date/time interpretation and event data fetching remain the caller's job.
class EventCalendarCard extends StatelessWidget {
  EventCalendarCard({
    super.key,
    required this.events,
    required this.onOpen,
    this.title = 'Event Calendar',
    this.emptyMessage = 'No events scheduled.',
    this.semanticLabel,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    if (emptyMessage.trim().isEmpty) {
      throw ArgumentError.value(
        emptyMessage,
        'emptyMessage',
        'must not be empty',
      );
    }
    final ids = <String>{};
    for (final event in events) {
      if (event.id.trim().isEmpty ||
          event.dayLabel.trim().isEmpty ||
          event.title.trim().isEmpty ||
          event.timeLabel.trim().isEmpty) {
        throw ArgumentError.value(
          event,
          'events',
          'id, dayLabel, title and timeLabel must not be empty',
        );
      }
      if (!ids.add(event.id)) {
        throw ArgumentError.value(
          event.id,
          'events',
          'duplicate event id: ${event.id}',
        );
      }
    }
  }

  final List<EventCalendarItem> events;
  final ValueChanged<String> onOpen;
  final String title;
  final String emptyMessage;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final semantics = semanticLabel ?? '$title. ${events.length} events.';
    return Semantics(
      key: const ValueKey('eventCalendarSemantics'),
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.all(NeonTheme.s16),
        decoration: BoxDecoration(
          color: NeonTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NeonTheme.cyan.withValues(alpha: 0.35),
            width: 2,
          ),
          boxShadow: NeonTheme.drop(y: 4, blur: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: NeonTheme.cyan),
                const SizedBox(width: NeonTheme.s8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: NeonTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NeonTheme.s8),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: NeonTheme.s16),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NeonTheme.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ListView.builder(
                key: const ValueKey('eventCalendarList'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _EventRow(event: events[index], onOpen: onOpen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onOpen});

  final EventCalendarItem event;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final active = event.status == EventCalendarStatus.active;
    final ended = event.status == EventCalendarStatus.ended;
    final color = ended
        ? NeonTheme.muted
        : active
        ? NeonTheme.gold
        : NeonTheme.cyan;
    final statusLabel = switch (event.status) {
      EventCalendarStatus.upcoming => 'Upcoming',
      EventCalendarStatus.active => 'Live',
      EventCalendarStatus.ended => 'Ended',
    };

    return Container(
      key: ValueKey('eventCalendar_${event.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.10) : NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: active ? 0.7 : 0.25)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(event.icon, size: 20, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.dayLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: NeonTheme.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        event.timeLabel,
                        style: TextStyle(
                          color: NeonTheme.inkSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                statusLabel,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!ended) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey('eventCalendarOpen_${event.id}'),
                  tooltip: 'Open ${event.title}',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: color,
                  ),
                  onPressed: () => onOpen(event.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
