import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/motion_feedback_sheets.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';

class PermissionRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;
  final String? shiftInstanceId;

  const PermissionRequestForm({
    super.key,
    required this.onSuccess,
    this.shiftInstanceId,
  });

  @override
  State<PermissionRequestForm> createState() => _PermissionRequestFormState();
}

class _PermissionRequestFormState extends State<PermissionRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  String _categoryCode = 'late_arrival';
  String? _selectedShiftId;
  List<EmployeeShiftEntity> _shifts = const [];

  @override
  void initState() {
    super.initState();
    _selectedShiftId = widget.shiftInstanceId;
    if (_selectedShiftId == null) {
      _loadShifts();
    }
  }

  void _loadShifts() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 1));
    final end = today.add(const Duration(days: 14));
    context.read<RequestFormCubit>().loadShiftInstances(
          startDate: DateFormat('yyyy-MM-dd').format(start),
          endDate: DateFormat('yyyy-MM-dd').format(end),
        );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _shiftLabel(EmployeeShiftEntity shift) {
    final startStr =
        '${shift.startsAt.toLocal().hour.toString().padLeft(2, '0')}:${shift.startsAt.toLocal().minute.toString().padLeft(2, '0')}';
    final endStr =
        '${shift.endsAt.toLocal().hour.toString().padLeft(2, '0')}:${shift.endsAt.toLocal().minute.toString().padLeft(2, '0')}';
    return '${shift.businessDate} ($startStr - $endStr)';
  }

  void _selectShift(String? shiftId) {
    if (shiftId == null) return;
    setState(() {
      _selectedShiftId = shiftId;
      final shift = _shifts.cast<EmployeeShiftEntity?>().firstWhere(
            (s) => s?.shiftInstanceId == shiftId,
            orElse: () => null,
          );
      if (shift != null) {
        final shiftLocalStart = shift.startsAt.toLocal();
        final shiftLocalEnd = shift.endsAt.toLocal();
        _selectedDate = shiftLocalStart;
        if (_categoryCode == 'late_arrival') {
          _startTime = TimeOfDay(
              hour: shiftLocalStart.hour, minute: shiftLocalStart.minute);
          _endTime = TimeOfDay(
              hour: (shiftLocalStart.hour + 1) % 24,
              minute: shiftLocalStart.minute);
        } else if (_categoryCode == 'early_departure') {
          _startTime = TimeOfDay(
              hour: (shiftLocalEnd.hour - 1 + 24) % 24,
              minute: shiftLocalEnd.minute);
          _endTime = TimeOfDay(
              hour: shiftLocalEnd.hour, minute: shiftLocalEnd.minute);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestFormCubit, RequestFormState>(
      listener: (context, state) async {
        if (state is RequestFormSuccess) {
          if (!state.isQueuedOffline) {
            await MotionFeedbackSheets.showRequestSubmitted(
              context,
              title: AppStringsAr.requestSubmittedSuccess,
              subtitle: 'تم استلام طلب الإذن بنجاح وسيتم إشعاره للمراجع المختص',
            );
          } else {
            await MotionFeedbackSheets.showOfflineQueued(
              context,
              title: 'حُفظ الطلب للمزامنة لاحقاً',
              subtitle: AppStringsAr.offlineRequestSavedNotice,
            );
          }
          if (mounted) widget.onSuccess();
        } else if (state is RequestFormError) {
          final message = state.isConflict
              ? AppStringsAr.duplicateRequestConflictNotice
              : state.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.coral),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is RequestFormSubmitting;
        String? activeShiftId = widget.shiftInstanceId;
        if (activeShiftId == null) {
          try {
            final attendanceState = context.watch<AttendanceCubit>().state;
            if (attendanceState is AttendanceReady) {
              activeShiftId = attendanceState.shiftContext.shiftInstanceId;
            }
          } catch (_) {}
        }

        if (state is RequestFormInitial) {
          _shifts = state.shifts;
          if (_selectedShiftId == null) {
            if (activeShiftId != null) {
              _selectedShiftId = activeShiftId;
            } else if (_shifts.isNotEmpty) {
              _selectedShiftId = _shifts.first.shiftInstanceId;
              _selectedDate = _shifts.first.startsAt.toLocal();
            }
          }
        }

        final effectiveShiftId = _selectedShiftId ?? activeShiftId;
        final hasShifts = _shifts.isNotEmpty;
        final resourceState = state is RequestFormInitial ? state : null;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (effectiveShiftId == null && !(resourceState?.shiftsLoading ?? false))
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.coral),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.coral),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا توجد وردية عمل مجدولة لهذا الحساب لتقديم طلب الإذن عليها. يرجى مراجعة جدول الورديات.',
                          style:
                              TextStyle(color: AppTheme.darkInk, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                AppStringsAr.permissionTypeTitle,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk),
              ),
              const SizedBox(height: 16),
              if (resourceState?.shiftsLoading ?? false)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (widget.shiftInstanceId == null) ...[
                DropdownButtonFormField<String>(
                  key: const Key('permission-shift-dropdown'),
                  isExpanded: true,
                  dropdownColor: AppTheme.surface01,
                  initialValue: _selectedShiftId,
                  decoration: const InputDecoration(
                    labelText: 'الوردية المجدولة للإذن',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.schedule),
                  ),
                  items: _shifts
                      .map((shift) => DropdownMenuItem(
                            value: shift.shiftInstanceId,
                            child: Text(
                              _shiftLabel(shift),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: hasShifts ? _selectShift : null,
                  validator: (value) => value == null && effectiveShiftId == null
                      ? 'يرجى اختيار الوردية المجدولة'
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: AppTheme.surface01,
                initialValue: _categoryCode,
                decoration: const InputDecoration(
                  labelText: 'نوع الإذن',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'late_arrival',
                      child: Text('إذن تأخير عن العمل (حضور متأخر)',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'early_departure',
                      child: Text('إذن انصراف مبكر',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'personal',
                      child: Text('إذن شخصي أثناء الدوام',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'medical',
                      child: Text('إذن طبي / عيادة',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'official',
                      child: Text('مهمة عمل رسمية',
                          overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _categoryCode = val;
                      if (_selectedShiftId != null) {
                        _selectShift(_selectedShiftId);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الإذن',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                  child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'من الساعة',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _endTime);
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'إلى الساعة',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: AppStringsAr.reasonFieldLabel,
                  hintText: 'اكتب سبب طلب الإذن بالتفصيل...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return AppStringsAr.reasonRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (isLoading || effectiveShiftId == null)
                      ? null
                      : () => _submit(effectiveShiftId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(AppStringsAr.submitRequest,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit(String shiftInstanceId) {
    if (_formKey.currentState?.validate() ?? false) {
      final startsAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endsAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      if (!endsAt.isAfter(startsAt)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('وقت النهاية يجب أن يكون بعد وقت البداية'),
              backgroundColor: AppTheme.coral),
        );
        return;
      }

      context.read<RequestFormCubit>().submitPermissionRequest(
            shiftInstanceId: shiftInstanceId,
            categoryCode: _categoryCode,
            startsAt: startsAt,
            endsAt: endsAt,
            reason: _reasonController.text.trim(),
          );
    }
  }
}
