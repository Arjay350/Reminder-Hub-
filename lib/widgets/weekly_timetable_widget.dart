import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../widgets/school_class_dialog.dart';

class WeeklySchoolTimetableWidget extends StatefulWidget {
  const WeeklySchoolTimetableWidget({
    super.key,
    required this.classes,
    this.dayModes,
    required this.onScheduleChanged,
  });

  final List<SchoolClass> classes;
  final Map<int, String>? dayModes;
  final VoidCallback onScheduleChanged;

  @override
  State<WeeklySchoolTimetableWidget> createState() =>
      _WeeklySchoolTimetableWidgetState();
}

class _WeeklySchoolTimetableWidgetState
    extends State<WeeklySchoolTimetableWidget> {
  // Synchronized controllers for 2D scrolling
  late ScrollController _headerHorizontalController;
  late ScrollController _gridHorizontalController;
  late ScrollController _timeVerticalController;
  late ScrollController _gridVerticalController;

  bool _isSyncingHorizontal = false;
  bool _isSyncingVertical = false;

  // Grid dimensional constants
  static const double kTimeGutterWidth = 56.0;
  static const double kDayColumnWidth = 120.0;
  static const double kHourHeight = 64.0;
  static const double kHeaderHeight = 56.0;

  static const List<Map<String, dynamic>> _days = [
    {'day': 1, 'name': 'Monday', 'short': 'Mon'},
    {'day': 2, 'name': 'Tuesday', 'short': 'Tue'},
    {'day': 3, 'name': 'Wednesday', 'short': 'Wed'},
    {'day': 4, 'name': 'Thursday', 'short': 'Thu'},
    {'day': 5, 'name': 'Friday', 'short': 'Fri'},
    {'day': 6, 'name': 'Saturday', 'short': 'Sat'},
    {'day': 7, 'name': 'Sunday', 'short': 'Sun'},
  ];

  @override
  void initState() {
    super.initState();
    _headerHorizontalController = ScrollController();
    _gridHorizontalController = ScrollController();
    _timeVerticalController = ScrollController();
    _gridVerticalController = ScrollController();

    // Link horizontal controllers
    _headerHorizontalController.addListener(_syncHeaderToGrid);
    _gridHorizontalController.addListener(_syncGridToHeader);

    // Link vertical controllers
    _timeVerticalController.addListener(_syncTimeToGrid);
    _gridVerticalController.addListener(_syncGridToTime);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialPosition();
    });
  }

  void _syncHeaderToGrid() {
    if (_isSyncingHorizontal) return;
    if (_gridHorizontalController.hasClients) {
      _isSyncingHorizontal = true;
      _gridHorizontalController.jumpTo(_headerHorizontalController.offset);
      _isSyncingHorizontal = false;
    }
  }

  void _syncGridToHeader() {
    if (_isSyncingHorizontal) return;
    if (_headerHorizontalController.hasClients) {
      _isSyncingHorizontal = true;
      _headerHorizontalController.jumpTo(_gridHorizontalController.offset);
      _isSyncingHorizontal = false;
    }
  }

  void _syncTimeToGrid() {
    if (_isSyncingVertical) return;
    if (_gridVerticalController.hasClients) {
      _isSyncingVertical = true;
      _gridVerticalController.jumpTo(_timeVerticalController.offset);
      _isSyncingVertical = false;
    }
  }

  void _syncGridToTime() {
    if (_isSyncingVertical) return;
    if (_timeVerticalController.hasClients) {
      _isSyncingVertical = true;
      _timeVerticalController.jumpTo(_gridVerticalController.offset);
      _isSyncingVertical = false;
    }
  }

  @override
  void dispose() {
    _headerHorizontalController.removeListener(_syncHeaderToGrid);
    _gridHorizontalController.removeListener(_syncGridToHeader);
    _timeVerticalController.removeListener(_syncTimeToGrid);
    _gridVerticalController.removeListener(_syncGridToTime);

    _headerHorizontalController.dispose();
    _gridHorizontalController.dispose();
    _timeVerticalController.dispose();
    _gridVerticalController.dispose();
    super.dispose();
  }

  int _parseTimeToMinutes(String timeStr) {
    int hour = 8;
    int minute = 0;
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final numPart = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = numPart.split(':');
      hour = int.parse(parts[0]);
      if (parts.length > 1) {
        minute = int.parse(parts[1]);
      }
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
    } catch (_) {
      hour = 8;
      minute = 0;
    }
    return (hour * 60 + minute).clamp(0, 24 * 60 - 1);
  }

  int _getStartHour() {
    int minHour = 7; // Default start at 7:00 AM
    for (final c in widget.classes) {
      final startMin = _parseTimeToMinutes(c.startTime);
      final hour = startMin ~/ 60;
      if (hour < minHour) minHour = hour;
    }
    return math.max(0, minHour);
  }

  int _getEndHour() {
    int maxHour = 21; // Default end at 9:00 PM (21:00)
    for (final c in widget.classes) {
      final endMin = _parseTimeToMinutes(c.endTime);
      final hour = (endMin + 59) ~/ 60;
      if (hour > maxHour) maxHour = hour;
    }
    return math.min(24, math.max(maxHour, _getStartHour() + 10));
  }

  void _scrollToInitialPosition() {
    final todayWeekday = DateTime.now().weekday; // 1 to 7
    final startHour = _getStartHour();

    // Horizontal scroll to today (or near today)
    if (_gridHorizontalController.hasClients) {
      final targetX = ((todayWeekday - 1) * kDayColumnWidth - 10.0).clamp(
        0.0,
        _gridHorizontalController.position.maxScrollExtent,
      );
      _gridHorizontalController.animateTo(
        targetX,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }

    // Vertical scroll to current hour or earliest class
    if (_gridVerticalController.hasClients) {
      final now = DateTime.now();
      int scrollTargetHour = now.hour;
      if (scrollTargetHour < startHour || scrollTargetHour > _getEndHour()) {
        scrollTargetHour = startHour;
      }
      final targetY = ((scrollTargetHour - startHour) * kHourHeight - 20.0)
          .clamp(0.0, _gridVerticalController.position.maxScrollExtent);
      _gridVerticalController.animateTo(
        targetY,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _formatHourLabel(int hour) {
    if (hour == 0 || hour == 24) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  // Calculate non-overlapping layout positions (lanes) for classes occurring on the given day
  List<_PositionedClass> _calculateDayLayout(int dayNumber, int startHour) {
    final dayClasses = widget.classes
        .where((c) => c.occursOnDay(dayNumber))
        .toList();
    if (dayClasses.isEmpty) return [];

    // Map each class to start and end minutes from the schedule start time
    final items = dayClasses.map((c) {
      final sMin = _parseTimeToMinutes(c.startTime);
      var eMin = _parseTimeToMinutes(c.endTime);
      if (eMin <= sMin) eMin = sMin + 60; // Fallback 1 hr if invalid
      return _ClassTimeItem(schoolClass: c, startMin: sMin, endMin: eMin);
    }).toList();

    // Sort by start time ascending, duration descending
    items.sort((a, b) {
      final cmp = a.startMin.compareTo(b.startMin);
      if (cmp != 0) return cmp;
      return (b.endMin - b.startMin).compareTo(a.endMin - a.startMin);
    });

    // Group overlapping classes into clusters
    final List<List<_ClassTimeItem>> clusters = [];
    List<_ClassTimeItem> currentCluster = [];
    int currentClusterEnd = -1;

    for (final item in items) {
      if (currentCluster.isEmpty) {
        currentCluster.add(item);
        currentClusterEnd = item.endMin;
      } else {
        if (item.startMin < currentClusterEnd) {
          // Overlaps with current cluster
          currentCluster.add(item);
          currentClusterEnd = math.max(currentClusterEnd, item.endMin);
        } else {
          // New cluster
          clusters.add(currentCluster);
          currentCluster = [item];
          currentClusterEnd = item.endMin;
        }
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<_PositionedClass> positionedClasses = [];

    for (final cluster in clusters) {
      // Assign lanes inside each cluster
      final List<int> laneEndTimes = [];
      final List<int> itemLanes = [];

      for (final item in cluster) {
        int assignedLane = -1;
        for (int l = 0; l < laneEndTimes.length; l++) {
          if (laneEndTimes[l] <= item.startMin) {
            assignedLane = l;
            laneEndTimes[l] = item.endMin;
            break;
          }
        }
        if (assignedLane == -1) {
          assignedLane = laneEndTimes.length;
          laneEndTimes.add(item.endMin);
        }
        itemLanes.add(assignedLane);
      }

      final totalLanes = laneEndTimes.length;

      for (int i = 0; i < cluster.length; i++) {
        final item = cluster[i];
        final laneIndex = itemLanes[i];

        final top = ((item.startMin - (startHour * 60)) / 60.0) * kHourHeight;
        final durationMin = item.endMin - item.startMin;
        final height = math.max(
          28.0,
          ((durationMin / 60.0) * kHourHeight) - 2.0,
        );

        final width = (kDayColumnWidth - 4.0) / totalLanes;
        final left = 2.0 + (laneIndex * width);

        positionedClasses.add(
          _PositionedClass(
            schoolClass: item.schoolClass,
            top: top,
            left: left,
            width: width,
            height: height,
          ),
        );
      }
    }

    return positionedClasses;
  }

  Future<void> _openAddClassForSlot(int dayNumber, int tappedHour) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchoolClassDialog(
        initialDay: dayNumber,
        initialStartTime: TimeOfDay(hour: tappedHour, minute: 0),
        initialEndTime: TimeOfDay(
          hour: (tappedHour + 1).clamp(0, 23),
          minute: 0,
        ),
      ),
    );
    if (result != null) widget.onScheduleChanged();
  }

  Future<void> _openEditClass(SchoolClass schoolClass) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchoolClassDialog(schoolClass: schoolClass),
    );
    if (result != null) widget.onScheduleChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final todayWeekday = DateTime.now().weekday; // 1 = Mon ... 7 = Sun

    final startHour = _getStartHour();
    final endHour = _getEndHour();
    final totalHours = endHour - startHour;
    final totalGridHeight = totalHours * kHourHeight;
    final totalGridWidth = _days.length * kDayColumnWidth;

    final gridBorderColor = isDark
        ? const Color(0xFF1E294B)
        : const Color(0xFFE2E8F0);
    final gridSubLineColor = isDark
        ? const Color(0xFF161E36)
        : const Color(0xFFF1F5F9);
    final timeTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final isCurrentTimeVisible =
        nowMinutes >= (startHour * 60) && nowMinutes <= (endHour * 60);
    final currentTimeTop =
        ((nowMinutes - (startHour * 60)) / 60.0) * kHourHeight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gridBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── STICKY TOP ROW (Time Corner + Day Column Headers) ───────────────
          Container(
            height: kHeaderHeight,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141A2E) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: gridBorderColor, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                // Top-Left Corner (Time Column Header)
                Container(
                  width: kTimeGutterWidth,
                  height: kHeaderHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: gridBorderColor, width: 1.0),
                    ),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),

                // Horizontally Scrollable Day Column Headers
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: totalGridWidth,
                      child: Row(
                        children: _days.map((d) {
                          final int dayNumber = d['day'] as int;
                          final String shortName = d['short'] as String;
                          final bool isToday = dayNumber == todayWeekday;
                          final int dayClassCount = widget.classes
                              .where((c) => c.occursOnDay(dayNumber))
                              .length;
                          final bool hasClasses = dayClassCount > 0;
                          final mode =
                              widget.dayModes?[dayNumber] ?? DayClassMode.f2f;
                          final modeShort = DayClassMode.getShortName(mode);

                          Color modeBadgeColor;
                          switch (mode) {
                            case DayClassMode.asyncModule:
                              modeBadgeColor = const Color(0xFF8B5CF6);
                              break;
                            case DayClassMode.syncOnline:
                              modeBadgeColor = const Color(0xFF3B82F6);
                              break;
                            case DayClassMode.f2f:
                            default:
                              modeBadgeColor = const Color(0xFF10B981);
                              break;
                          }

                          return Container(
                            width: kDayColumnWidth,
                            height: kHeaderHeight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(
                                      0xFF14B8A6,
                                    ).withValues(alpha: isDark ? 0.18 : 0.1)
                                  : (hasClasses &&
                                            mode == DayClassMode.asyncModule
                                        ? modeBadgeColor.withValues(
                                            alpha: isDark ? 0.05 : 0.03,
                                          )
                                        : Colors.transparent),
                              border: Border(
                                right: BorderSide(
                                  color: gridBorderColor,
                                  width: 1.0,
                                ),
                                bottom: isToday
                                    ? const BorderSide(
                                        color: Color(0xFF14B8A6),
                                        width: 2.5,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      shortName.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: isToday
                                            ? const Color(0xFF14B8A6)
                                            : (isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                    if (isToday) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF14B8A6),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: const Text(
                                          'TODAY',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Mode Badge & Class count (or No Classes)
                                if (hasClasses)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: modeBadgeColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: modeBadgeColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          modeShort,
                                          style: TextStyle(
                                            color: modeBadgeColor,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$dayClassCount',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    'No Classes',
                                    style: TextStyle(
                                      fontSize: 9.0,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── MAIN TIMETABLE BODY (Sticky Time Gutter + 2D Scrollable Grid) ──
          Expanded(
            child: Row(
              children: [
                // Sticky Time Gutter (Scrolls Vertically with Grid)
                Container(
                  width: kTimeGutterWidth,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141A2E).withValues(alpha: 0.5)
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      right: BorderSide(color: gridBorderColor, width: 1.0),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: _timeVerticalController,
                    scrollDirection: Axis.vertical,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      height: totalGridHeight,
                      child: Stack(
                        children: List.generate(totalHours + 1, (index) {
                          final hour = startHour + index;
                          return Positioned(
                            top: (index * kHourHeight) - 8.0,
                            left: 0,
                            right: 6,
                            child: Text(
                              _formatHourLabel(hour),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: timeTextColor,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                // 2D Scrollable Timetable Grid
                Expanded(
                  child: SingleChildScrollView(
                    controller: _gridHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: totalGridWidth,
                      child: SingleChildScrollView(
                        controller: _gridVerticalController,
                        scrollDirection: Axis.vertical,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: totalGridWidth,
                          height: totalGridHeight,
                          child: Stack(
                            children: [
                              // 1. Grid Background (Horizontal Hour Lines & Half-Hour Lines)
                              CustomPaint(
                                size: Size(totalGridWidth, totalGridHeight),
                                painter: _TimetableGridPainter(
                                  startHour: startHour,
                                  totalHours: totalHours,
                                  hourHeight: kHourHeight,
                                  columnWidth: kDayColumnWidth,
                                  daysCount: _days.length,
                                  borderColor: gridBorderColor,
                                  subLineColor: gridSubLineColor,
                                  todayIndex: todayWeekday - 1,
                                  todayColumnColor: const Color(
                                    0xFF14B8A6,
                                  ).withValues(alpha: isDark ? 0.05 : 0.03),
                                ),
                              ),

                              // 2. Interactive Column Slots for Tapping Empty Time Areas
                              Row(
                                children: _days.map((d) {
                                  final int dayNumber = d['day'] as int;
                                  return SizedBox(
                                    width: kDayColumnWidth,
                                    height: totalGridHeight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapUp: (details) {
                                        final double y =
                                            details.localPosition.dy;
                                        final int clickedHour =
                                            (startHour + (y / kHourHeight))
                                                .floor()
                                                .clamp(startHour, endHour - 1);
                                        _openAddClassForSlot(
                                          dayNumber,
                                          clickedHour,
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),

                              // 3. Positioned Class Event Blocks (per Day Column)
                              ...List.generate(_days.length, (dIdx) {
                                final dayNumber = _days[dIdx]['day'] as int;
                                final positionedItems = _calculateDayLayout(
                                  dayNumber,
                                  startHour,
                                );
                                final columnLeft = dIdx * kDayColumnWidth;

                                return Positioned(
                                  left: columnLeft,
                                  top: 0,
                                  width: kDayColumnWidth,
                                  height: totalGridHeight,
                                  child: Stack(
                                    children: positionedItems.map((pClass) {
                                      final c = pClass.schoolClass;
                                      return Positioned(
                                        top: pClass.top,
                                        left: pClass.left,
                                        width: pClass.width,
                                        height: pClass.height,
                                        child: _ClassEventCard(
                                          schoolClass: c,
                                          height: pClass.height,
                                          width: pClass.width,
                                          isDark: isDark,
                                          onTap: () => _openEditClass(c),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }),

                              // 4. Current Time Indicator (Red/Teal Horizontal Line on Today)
                              if (isCurrentTimeVisible &&
                                  todayWeekday >= 1 &&
                                  todayWeekday <= 7)
                                Positioned(
                                  top: currentTimeTop - 1.0,
                                  left: (todayWeekday - 1) * kDayColumnWidth,
                                  width: kDayColumnWidth,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 2,
                                          color: const Color(
                                            0xFFEF4444,
                                          ).withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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

// ── Custom Painter for the Timetable Grid Lines ─────────────────────────────
class _TimetableGridPainter extends CustomPainter {
  _TimetableGridPainter({
    required this.startHour,
    required this.totalHours,
    required this.hourHeight,
    required this.columnWidth,
    required this.daysCount,
    required this.borderColor,
    required this.subLineColor,
    required this.todayIndex,
    required this.todayColumnColor,
  });

  final int startHour;
  final int totalHours;
  final double hourHeight;
  final double columnWidth;
  final int daysCount;
  final Color borderColor;
  final Color subLineColor;
  final int todayIndex;
  final Color todayColumnColor;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final subLinePaint = Paint()
      ..color = subLineColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final todayPaint = Paint()
      ..color = todayColumnColor
      ..style = PaintingStyle.fill;

    // 1. Highlight today's column background
    if (todayIndex >= 0 && todayIndex < daysCount) {
      canvas.drawRect(
        Rect.fromLTWH(todayIndex * columnWidth, 0, columnWidth, size.height),
        todayPaint,
      );
    }

    // 2. Horizontal Hour & Half-Hour Grid Lines
    for (int i = 0; i <= totalHours; i++) {
      final y = i * hourHeight;
      // Hour line
      canvas.drawLine(Offset(0, y), Offset(size.width, y), borderPaint);

      // Half-hour line (if not at bottom edge)
      if (i < totalHours) {
        final halfY = y + (hourHeight / 2.0);
        canvas.drawLine(
          Offset(0, halfY),
          Offset(size.width, halfY),
          subLinePaint,
        );
      }
    }

    // 3. Vertical Column Dividers between days
    for (int i = 1; i <= daysCount; i++) {
      final x = i * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimetableGridPainter oldDelegate) {
    return oldDelegate.totalHours != totalHours ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.todayIndex != todayIndex ||
        oldDelegate.subLineColor != subLineColor;
  }
}

// ── Positioned Event Block Widget ───────────────────────────────────────────
class _ClassEventCard extends StatelessWidget {
  const _ClassEventCard({
    required this.schoolClass,
    required this.height,
    required this.width,
    required this.isDark,
    required this.onTap,
  });

  final SchoolClass schoolClass;
  final double height;
  final double width;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final classColor = schoolClass.color;
    final isCompact = height < 50.0;
    final isVeryCompact = height < 36.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: classColor.withValues(alpha: 0.2),
        highlightColor: classColor.withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Color.alphaBlend(
                    classColor.withValues(alpha: 0.25),
                    const Color(0xFF1E293B),
                  )
                : Color.alphaBlend(
                    classColor.withValues(alpha: 0.16),
                    Colors.white,
                  ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: classColor.withValues(alpha: isDark ? 0.7 : 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Color Stripe
              Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: classColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(7),
                  ),
                ),
              ),

              // Event Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: isVeryCompact ? 2 : 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isVeryCompact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      // Course Code (if available)
                      if (schoolClass.courseCode.isNotEmpty) ...[
                        Text(
                          schoolClass.courseCode,
                          style: TextStyle(
                            fontSize: isVeryCompact ? 8.5 : 9.5,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? classColor.withValues(alpha: 0.95)
                                : classColor,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isVeryCompact) const SizedBox(height: 1),
                      ],

                      // Subject Code / Name
                      Text(
                        schoolClass.subject,
                        style: TextStyle(
                          fontSize: isVeryCompact ? 9.5 : 11.0,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          height: 1.15,
                        ),
                        maxLines: isCompact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Time range
                      if (!isVeryCompact) ...[
                        const SizedBox(height: 2),
                        Text(
                          schoolClass.timeRange,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? classColor.withValues(alpha: 0.95)
                                : classColor,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Room
                      if (!isCompact && schoolClass.room.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.meeting_room_outlined,
                              size: 10,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                schoolClass.room,
                                style: TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Instructor / Teacher
                      if (height >= 68.0 && schoolClass.teacher.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 10,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                schoolClass.teacher,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

// ── Internal Helper Classes ─────────────────────────────────────────────────
class _ClassTimeItem {
  _ClassTimeItem({
    required this.schoolClass,
    required this.startMin,
    required this.endMin,
  });

  final SchoolClass schoolClass;
  final int startMin;
  final int endMin;
}

class _PositionedClass {
  _PositionedClass({
    required this.schoolClass,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
  });

  final SchoolClass schoolClass;
  final double top;
  final double left;
  final double width;
  final double height;
}
