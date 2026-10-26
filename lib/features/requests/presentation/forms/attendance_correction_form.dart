import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/motion_feedback_sheets.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';

class AttendanceCorrectionForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const AttendanceCorrectionForm({super.key, required this.onSuccess});

  @override
  State<AttendanceCorrectionForm> createState() =>
      _AttendanceCorrectionFormState();
}

class _AttendanceCorrectionFormState extends State<AttendanceCorrectionForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _selectedCheckOutTime = const TimeOfDay(hour: 17, minute: 0);
  String _correctionKind = 'add_check_in';
  String? _selectedShiftId;
  List<EmployeeShiftEntity> _shifts = const [];

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _loadShifts() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 30));
    context.read<RequestFormCubit>().loadShiftInstances(
          startDate: DateFormat('yyyy-MM-dd').format(start),
          endDate: DateFormat('yyyy-MM-dd').format(today),
        );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
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
              subtitle:
                  'تم استلام طلب تصحيح البصمة بنجاح وسيتم إشعاره للمراجع المختص',
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
        if (state is RequestFormInitial) {
          _shifts = state.shifts;
          if (_selectedShiftId != null &&
              !_shifts
                  .any((shift) => shift.shiftInstanceId == _selectedShiftId)) {
            _selectedShiftId = null;
          }
        }
        final resourceState = state is RequestFormInitial ? state : null;
        final hasShifts = _shifts.isNotEmpty;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                AppStringsAr.attendanceCorrectionTitle,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk),
              ),
              const SizedBox(height: 16),
              if (resourceState?.shiftsLoading ?? false)
                const LinearProgressIndicator(),
              if (!(resourceState?.shiftsLoading ?? false) && !hasShifts)
                _buildMissingShifts(resourceState?.shiftError),
              DropdownButtonFormField<String>(
                key: const Key('attendance-correction-shift'),
                isExpanded: true,
                dropdownColor: AppTheme.surface01,
                initialValue: _selectedShiftId,
                decoration: const InputDecoration(
                  labelText: 'الوردية المطلوب تصحيحها',
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
                validator: (value) => value == null
                    ? 'يرجى اختيار وردية مصرح بها من سجل الورديات'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: AppTheme.surface01,
                initialValue: _correctionKind,
                decoration: const InputDecoration(
                  labelText: 'نوع التصحيح المطلوب',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_calendar),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'add_check_in',
                      child: Text('إضافة بصمة حضور منسية',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'change_check_in',
                      child: Text('تعديل توقيت بصمة حضور',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'add_check_out',
                      child: Text('إضافة بصمة انصراف منسية',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'change_check_out',
                      child: Text('تعديل توقيت بصمة انصراف',
                          overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(
                      value: 'both',
                      child: Text('تصحيح الحضور والانصراف معاً',
                          overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _correctionKind = val);
                },
              ),
              if (_correctionKind == 'both') ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedCheckOutTime,
                    );
                    if (picked != null) {
                      setState(() => _selectedCheckOutTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'توقيت الانصراف الفعلي',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      '${_selectedCheckOutTime.hour.toString().padLeft(2, '0')}:${_selectedCheckOutTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ البصمة',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _selectedTime);
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'التوقيت الفعلي',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
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
                  hintText: 'اكتب سبب نسيان البصمة أو الخطأ...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'يرجى كتابة سبب واضح لا يقل عن 10 أحرف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading || !hasShifts ? null : _submit,
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

  String _shiftLabel(EmployeeShiftEntity shift) {
    final start = DateFormat('HH:mm').format(shift.startsAt.toLocal());
    final end = DateFormat('HH:mm').format(shift.endsAt.toLocal());
    return '${shift.businessDate} • ${shift.branchName} • $start–$end';
  }

  void _selectShift(String? shiftId) {
    if (shiftId == null) return;
    final shift = _shifts.firstWhere((item) => item.shiftInstanceId == shiftId);
    final businessDate = DateTime.parse(shift.businessDate);
    final localStart = shift.startsAt.toLocal();
    final localEnd = shift.endsAt.toLocal();
    setState(() {
      _selectedShiftId = shiftId;
      _selectedDate = businessDate;
      _selectedTime =
          TimeOfDay(hour: localStart.hour, minute: localStart.minute);
      _selectedCheckOutTime =
          TimeOfDay(hour: localEnd.hour, minute: localEnd.minute);
    });
  }

  Widget _buildMissingShifts(String? error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            error ?? 'لا توجد ورديات سابقة متاحة للتصحيح خلال آخر 30 يوماً.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadShifts,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة تحميل الورديات'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if ((_formKey.currentState?.validate() ?? false) &&
        _selectedShiftId != null) {
      final proposedAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final proposedCheckOutAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedCheckOutTime.hour,
        _selectedCheckOutTime.minute,
      );
      if (_correctionKind == 'both' &&
          !proposedCheckOutAt.isAfter(proposedAt)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب أن يكون الانصراف بعد الحضور')),
        );
        return;
      }

      context.read<RequestFormCubit>().submitAttendanceCorrection(
            shiftInstanceId: _selectedShiftId!,
            correctionKind: _correctionKind,
            proposedAt: _correctionKind == 'both' ? null : proposedAt,
            proposedCheckInAt: _correctionKind == 'both' ? proposedAt : null,
            proposedCheckOutAt:
                _correctionKind == 'both' ? proposedCheckOutAt : null,
            reason: _reasonController.text.trim(),
          );
    }
  }
}
