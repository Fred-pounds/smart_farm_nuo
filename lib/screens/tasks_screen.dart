import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/planting.dart';
import '../providers/planting_provider.dart';
import 'add_planting_screen.dart';
import '../theme/theme.dart';

/// The farm calendar, generated from each planting's growth stage.
///
/// Two views of the same list, and the strip at the top switches between
/// them:
///
/// * **No day selected** — everything ahead, bucketed by urgency. This is the
///   default because the question a farmer opens this screen with is "what is
///   late and what is today", not "what happens on the 14th".
/// * **A day selected** — just that day, as a timeline.
///
/// Nothing here is manually scheduled. Tasks come from what has been planted
/// and where each crop is in its growth stages, so an empty screen means an
/// empty log, and the empty state says exactly that.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantingProvider>();
    final tasks = provider.tasks;

    return GlassScaffold(
      title: 'Farm Tasks',
      subtitle: tasks.isEmpty ? null : '${tasks.length} scheduled',
      builder: (context, contentPadding) {
        if (!provider.isLoaded) {
          return ListView(
            padding: contentPadding,
            children: const [ListSkeleton(count: 5, thumbSize: 44)],
          );
        }

        if (tasks.isEmpty) {
          return ListView(
            padding: contentPadding,
            children: [
              EmptyState(
                art: FarmArt.calendar,
                title: 'No tasks scheduled',
                message:
                    'Tasks are generated from what you have planted. Log a '
                    'planting and its calendar appears here.',
                action: FilledButton.icon(
                  onPressed: () {
                    Haptics.selection();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddPlantingScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Log a planting'),
                ),
              ),
            ],
          );
        }

        final forDay = _selected == null
            ? const <FarmTask>[]
            : tasks.where((t) => _isSameDay(t.dueDate, _selected!)).toList();

        return ListView(
          padding: contentPadding,
          children: [
            CalendarStrip(
              tasks: tasks,
              selected: _selected,
              onSelect: (day) => setState(
                () => _selected = _isSameDay(day, _selected ?? _never)
                    ? null
                    : day,
              ),
            ),
            const SizedBox(height: Tokens.space6),
            if (_selected != null) ...[
              SectionHeader(
                title: DateFormat('EEEE d MMMM').format(_selected!),
                trailing: 'Show all',
                onTap: () => setState(() => _selected = null),
              ),
              if (forDay.isEmpty)
                Panel(
                  child: Row(
                    children: [
                      const FarmIllustration(
                        art: FarmArt.calendar,
                        size: 52,
                        showBackdrop: false,
                      ),
                      const SizedBox(width: Tokens.space4),
                      Expanded(
                        child: Text(
                          'Nothing scheduled for this day.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _Timeline(tasks: forDay),
            ] else
              ..._grouped(tasks),
          ],
        );
      },
    );
  }

  /// Every bucket that has anything in it, as a titled timeline.
  List<Widget> _grouped(List<FarmTask> tasks) {
    final groups = <String, List<FarmTask>>{};
    for (final task in tasks) {
      groups.putIfAbsent(_bucketFor(task.daysUntilDue), () => []).add(task);
    }

    // Fixed urgency order, regardless of the order tasks arrived in.
    const order = ['Overdue', 'Today', 'This week', 'This month', 'Later'];

    return [
      for (final key in order)
        if (groups[key] != null) ...[
          SectionHeader(title: key, trailing: '${groups[key]!.length}'),
          _Timeline(tasks: groups[key]!),
          const SizedBox(height: Tokens.space5),
        ],
    ];
  }

  static String _bucketFor(int days) => switch (days) {
    < 0 => 'Overdue',
    0 => 'Today',
    <= 7 => 'This week',
    <= 30 => 'This month',
    _ => 'Later',
  };

  /// A date no task can match, so `_isSameDay` against it is always false.
  static final DateTime _never = DateTime.fromMillisecondsSinceEpoch(0);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A fortnight of days, scrollable, with a load dot under each.
///
/// Two weeks rather than a month grid: the tasks this app generates are
/// agronomic, so they cluster within days of each other, and a full month
/// view would be mostly empty cells. The dot count is capped at three — past
/// that the number stops being countable at a glance and the exact figure is
/// in the list below anyway.
class CalendarStrip extends StatelessWidget {
  final List<FarmTask> tasks;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  const CalendarStrip({
    super.key,
    required this.tasks,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: Tokens.space2),
        itemBuilder: (context, i) {
          final day = today.add(Duration(days: i));
          final count = tasks
              .where(
                (t) =>
                    t.dueDate.year == day.year &&
                    t.dueDate.month == day.month &&
                    t.dueDate.day == day.day,
              )
              .length;

          return _DayCell(
            day: day,
            isToday: i == 0,
            count: count,
            selected:
                selected != null &&
                selected!.year == day.year &&
                selected!.month == day.month &&
                selected!.day == day.day,
            onTap: () {
              Haptics.selection();
              onSelect(day);
            },
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    final fg = selected
        ? Theme.of(context).colorScheme.onPrimary
        : isToday
        ? colors.growth
        : colors.inkPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tokens.motionFast,
        curve: Tokens.curveStandard,
        width: 52,
        decoration: BoxDecoration(
          color: selected ? colors.growth : colors.panel,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(
            color: selected
                ? colors.growth
                : isToday
                ? colors.growth.withValues(alpha: 0.45)
                : colors.panelBorder,
          ),
          boxShadow: Tokens.restingShadow(colors.panelShadow),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(day).substring(0, 2).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : colors.inkTertiary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: theme.textTheme.titleMedium?.copyWith(color: fg),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count.clamp(0, 3); i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : colors.growth,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<FarmTask> tasks;

  const _Timeline({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Column(
      children: [
        for (var i = 0; i < tasks.length; i++)
          TimelineEntry(
            isFirst: i == 0,
            isLast: i == tasks.length - 1,
            filled: tasks[i].isOverdue || tasks[i].isDueToday,
            accent: _accentFor(tasks[i], colors),
            child: _TaskCard(task: tasks[i]),
          ),
      ],
    );
  }

  static Color _accentFor(FarmTask task, FarmColors c) => task.isOverdue
      ? c.alert
      : task.isDueToday
      ? c.sun
      : c.growth;
}

class _TaskCard extends StatelessWidget {
  final FarmTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final accent = _Timeline._accentFor(task, colors);

    return Panel(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(task.title), size: 17, color: accent),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.35),
                ),
              ),
              const SizedBox(width: Tokens.space2),
              Text(
                _dueLabel(task),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          Row(
            children: [
              Text(task.cropEmoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${task.cropName} · ${task.fieldName} · ${task.stageName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkTertiary,
                  ),
                ),
              ),
              Text(
                DateFormat('d MMM').format(task.dueDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkTertiary,
                  fontFeatures: Tokens.tabular,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The kind of work, inferred from the generated title.
  ///
  /// The task model carries no type field — titles come from each crop's
  /// growth stages in the crop database. Matching on the verb is a small
  /// cheat, but a watering can and a harvest basket are recognised faster
  /// than any wording, and an unmatched title falls back to a neutral mark
  /// rather than a wrong one.
  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('water') || t.contains('irrigat')) {
      return Icons.water_drop_rounded;
    }
    if (t.contains('harvest')) return Icons.agriculture_rounded;
    if (t.contains('plant') || t.contains('sow') || t.contains('transplant')) {
      return Icons.eco_rounded;
    }
    if (t.contains('weed') || t.contains('thin')) return Icons.grass_rounded;
    if (t.contains('fertil') || t.contains('manure')) {
      return Icons.science_rounded;
    }
    if (t.contains('pest') || t.contains('spray') || t.contains('scout')) {
      return Icons.pest_control_rounded;
    }
    if (t.contains('stake') || t.contains('prune') || t.contains('mulch')) {
      return Icons.content_cut_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  static String _dueLabel(FarmTask task) {
    final days = task.daysUntilDue;
    if (days < 0) return '${-days}d late';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'in ${days}d';
  }
}
