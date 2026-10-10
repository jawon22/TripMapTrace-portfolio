import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/holiday_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import 'trip_detail_screen.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final ApiService _api = ApiService();
  final _titleController = TextEditingController();
  final _nameFocusNode = FocusNode();

  bool _ready = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _submitting = false;

  bool get _hasName => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      initializeDateFormatting('ko_KR'),
      HolidayService.instance.ensureLoaded(),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_hasName) return;
    setState(() => _submitting = true);
    try {
      final trip = await _api.createTrip(
        _titleController.text.trim(),
        startDate: _rangeStart,
        endDate: _rangeEnd,
      );
      tripListRefreshNotifier.value++;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, '생성 실패: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Color? _dayTextColor(DateTime day) {
    if (HolidayService.instance.isHoliday(day) ||
        day.weekday == DateTime.sunday) {
      return Colors.red.shade400;
    }
    if (day.weekday == DateTime.saturday) return Colors.blue.shade400;
    return null;
  }

  Widget _buildRangeEdgeCell(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildWithinRangeCell(DateTime day) {
    final color = _dayTextColor(day) ?? AppColors.textOnLight;
    return Center(
      child: Text('${day.day}', style: TextStyle(color: color, fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 여행 만들기')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 여행 이름 ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: TextField(
              controller: _titleController,
              focusNode: _nameFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _nameFocusNode.unfocus(),
              decoration: const InputDecoration(
                hintText: '여행 이름 (예: 제주도 여름 여행)',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ),

          // ── 달력 영역 (이름 입력 후 표시) ───────────────────────────────────
          if (_hasName) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
              child: Row(
                children: [
                  const Text('여행 기간',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const Text('  (선택)',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textSub)),
                  const Spacer(),
                  if (_rangeStart != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _rangeStart = null;
                        _rangeEnd = null;
                      }),
                      style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('초기화'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: _buildRangeStatus(),
            ),
            if (_ready)
              Expanded(child: _buildCalendar())
            else
              const Expanded(
                  child: Center(child: CircularProgressIndicator())),
          ] else
            const Spacer(),

          // ── 만들기 버튼 ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_hasName && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('만들기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeStatus() {
    if (_rangeStart == null) {
      return const Text(
        '달력에서 날짜를 선택하세요',
        style: TextStyle(fontSize: 13, color: AppColors.textSub),
      );
    }
    if (_rangeEnd == null) {
      return Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            _formatDate(_rangeStart!),
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.accent,
                fontWeight: FontWeight.w500),
          ),
          const Text('  · 종료일을 선택하거나 바로 만들기',
              style: TextStyle(fontSize: 12, color: AppColors.textSub)),
        ],
      );
    }
    final isSameDay = _rangeStart!.isAtSameMomentAs(_rangeEnd!);
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined,
            size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          isSameDay
              ? _formatDate(_rangeStart!)
              : '${_formatDate(_rangeStart!)}  ~  ${_formatDate(_rangeEnd!)}',
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.accent,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'ko_KR',
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      rangeStartDay: _rangeStart,
      rangeEndDay: _rangeEnd,
      rangeSelectionMode: RangeSelectionMode.toggledOn,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: ''},
      onRangeSelected: (start, end, focused) => setState(() {
        _rangeStart = start;
        _rangeEnd = end;
        _focusedDay = focused;
      }),
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        rangeHighlightColor: AppColors.accent.withValues(alpha: 0.12),
        rangeStartDecoration: const BoxDecoration(
            color: Colors.transparent, shape: BoxShape.circle),
        rangeEndDecoration: const BoxDecoration(
            color: Colors.transparent, shape: BoxShape.circle),
        todayDecoration: const BoxDecoration(),
        todayTextStyle: const TextStyle(
            fontWeight: FontWeight.bold, color: AppColors.textOnLight),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        // 헤더 타이틀 + 오늘 버튼
        headerTitleBuilder: (context, focusedDay) => Stack(
          alignment: Alignment.center,
          children: [
            Text(
              DateFormat('yyyy년 MM월', 'ko_KR').format(focusedDay),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            Positioned(
              right: 0,
              child: TextButton(
                onPressed: () =>
                    setState(() => _focusedDay = DateTime.now()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('오늘',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.accent)),
              ),
            ),
          ],
        ),
        // 요일 헤더
        dowBuilder: (context, day) {
          const labels = ['월', '화', '수', '목', '금', '토', '일'];
          final label = labels[day.weekday - 1];
          Color color = AppColors.textSub;
          if (day.weekday == DateTime.saturday) color = Colors.blue.shade400;
          if (day.weekday == DateTime.sunday) color = Colors.red.shade400;
          return Center(
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          );
        },
        // 일반 날짜
        defaultBuilder: (context, day, _) {
          final color = _dayTextColor(day);
          if (color == null) return null;
          return Center(
              child: Text('${day.day}',
                  style: TextStyle(color: color, fontSize: 14)));
        },
        rangeStartBuilder: (context, day, _) => _buildRangeEdgeCell(day),
        rangeEndBuilder: (context, day, _) => _buildRangeEdgeCell(day),
        withinRangeBuilder: (context, day, _) => _buildWithinRangeCell(day),
        todayBuilder: (context, day, _) {
          final color = _dayTextColor(day);
          // 날짜 범위가 선택된 경우 오늘 강조 제거
          if (_rangeStart != null) {
            return Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: color ?? AppColors.textOnLight,
                  fontSize: 14,
                ),
              ),
            );
          }
          return Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: color ?? AppColors.textOnLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
