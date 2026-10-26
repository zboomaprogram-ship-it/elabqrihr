import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'attachment_picker_service.dart';

class DynamicFormBuilder extends StatefulWidget {
  final List<RequestFieldDefinition> fields;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final bool isSubmitting;
  final AttachmentPickerService? attachmentPicker;
  final ApiClient? apiClient;
  final String? definitionVersionId;
  final DynamicRequestRepository? dynamicRequestRepository;

  const DynamicFormBuilder({
    super.key,
    required this.fields,
    required this.onSubmit,
    this.isSubmitting = false,
    this.attachmentPicker,
    this.apiClient,
    this.definitionVersionId,
    this.dynamicRequestRepository,
  });

  @override
  State<DynamicFormBuilder> createState() => _DynamicFormBuilderState();
}

class _DynamicFormBuilderState extends State<DynamicFormBuilder> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, RequestAttachment> _uploadedAttachments = {};
  final Set<String> _uploadingFields = {};
  final Map<String, String> _uploadErrors = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, dynamic> _values = {};
  final Map<String, String> _selectedOptionLabels = {};

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    for (final field in widget.fields) {
      if (field.kind == FieldKind.shortText ||
          field.kind == FieldKind.longText ||
          field.kind == FieldKind.integer ||
          field.kind == FieldKind.decimal) {
        final controller = TextEditingController();
        controller.addListener(() {
          if (mounted) setState(() {});
        });
        _textControllers[field.key] = controller;
      } else if (field.kind == FieldKind.boolean) {
        _values[field.key] = false;
      } else if (field.kind == FieldKind.multipleChoice) {
        _values[field.key] = <String>[];
      }
    }
  }

  bool _isFieldVisible(RequestFieldDefinition field) {
    if (field.conditionalVisibility == null) return true;
    final currentValues = <String, dynamic>{};
    for (final f in widget.fields) {
      if (_textControllers.containsKey(f.key)) {
        currentValues[f.key] = _textControllers[f.key]!.text;
      } else {
        currentValues[f.key] = _values[f.key];
      }
    }
    return field.conditionalVisibility!.evaluate(currentValues);
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields stored in _values (e.g. date, choice, attachment)
    for (final field in widget.fields) {
      if (!_isFieldVisible(field)) continue;
      if (field.required) {
        if (field.dataSource != null) {
          final val = _values[field.key];
          if (val == null || val.toString().trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('حقل ${field.labelAr} مطلوب'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            return;
          }
        } else if (field.kind == FieldKind.date ||
            field.kind == FieldKind.time ||
            field.kind == FieldKind.dateTime ||
            field.kind == FieldKind.singleChoice ||
            field.kind == FieldKind.employeeReference ||
            field.kind == FieldKind.attachment) {
          if (_values[field.key] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('حقل ${field.labelAr} مطلوب'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            return;
          }
        } else if (field.kind == FieldKind.multipleChoice) {
          final list = _values[field.key] as List<String>?;
          if (list == null || list.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('حقل ${field.labelAr} مطلوب'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            return;
          }
        }
      }
    }

    final result = <String, dynamic>{};
    for (final field in widget.fields) {
      if (!_isFieldVisible(field)) continue;
      if (field.dataSource != null) {
        final val = _values[field.key];
        if (val != null) result[field.key] = val;
      } else if (field.kind == FieldKind.shortText ||
          field.kind == FieldKind.longText) {
        final text = _textControllers[field.key]?.text.trim() ?? '';
        if (text.isNotEmpty || field.required) {
          result[field.key] = text;
        }
      } else if (field.kind == FieldKind.integer) {
        final text = _textControllers[field.key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          result[field.key] = int.tryParse(text) ?? 0;
        }
      } else if (field.kind == FieldKind.decimal) {
        final text = _textControllers[field.key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          result[field.key] = double.tryParse(text) ?? 0.0;
        }
      } else if (field.kind == FieldKind.date) {
        final val = _values[field.key];
        if (val is String) {
          result[field.key] = val;
        } else if (val is DateTime) {
          result[field.key] = DateFormat('yyyy-MM-dd').format(val);
        }
      } else if (field.kind == FieldKind.time) {
        final val = _values[field.key];
        if (val != null) result[field.key] = val.toString();
      } else if (field.kind == FieldKind.dateTime) {
        final val = _values[field.key];
        if (val is String) {
          result[field.key] = val;
        } else if (val is DateTime) {
          result[field.key] = val.toUtc().toIso8601String();
        }
      } else if (field.kind == FieldKind.boolean) {
        result[field.key] = _values[field.key] as bool? ?? false;
      } else if (field.kind == FieldKind.singleChoice) {
        final val = _values[field.key] as String?;
        if (val != null) result[field.key] = val;
      } else if (field.kind == FieldKind.employeeReference) {
        final val = _values[field.key] as String?;
        if (val != null) result[field.key] = val;
      } else if (field.kind == FieldKind.multipleChoice) {
        final val = _values[field.key] as List<String>?;
        if (val != null) result[field.key] = val;
      } else if (field.kind == FieldKind.attachment) {
        final val = _values[field.key];
        if (val is String && val.isNotEmpty) {
          result[field.key] = val;
        } else if (val is RequestAttachment) {
          result[field.key] = val.id;
        }
      }
    }

    widget.onSubmit(result);
  }

  @override
  Widget build(BuildContext context) {
    final sortedFields = List<RequestFieldDefinition>.from(widget.fields)
      ..sort((a, b) => a.position.compareTo(b.position));

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sortedFields.map((field) => _buildFieldWidget(field)),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('dynamic_form_submit_button'),
            onPressed: widget.isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: widget.isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'إرسال الطلب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(RequestFieldDefinition field) {
    if (!_isFieldVisible(field)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: AttendCard(
        hasBorderGlow: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  field.labelAr,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (field.required)
                  const Text(' *',
                      style:
                          TextStyle(color: AppTheme.errorColor, fontSize: 16)),
              ],
            ),
            if (field.helpTextAr != null && field.helpTextAr!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                field.helpTextAr!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            _buildInputControl(field),
          ],
        ),
      ),
    );
  }

  Widget _buildInputControl(RequestFieldDefinition field) {
    if (field.dataSource != null) {
      return _buildSearchableSelector(field);
    }

    switch (field.kind) {
      case FieldKind.shortText:
        return TextFormField(
          key: Key('dynamic_field_${field.key}'),
          controller: _textControllers[field.key],
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'أدخل ${field.labelAr}',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          validator: (v) {
            if (field.required && (v == null || v.trim().isEmpty)) {
              return 'هذا الحقل مطلوب';
            }
            if (field.validation != null && v != null && v.trim().isNotEmpty) {
              final val = field.validation!;
              if (val.minLength != null && v.trim().length < val.minLength!) {
                return 'يجب ألا يقل النص عن ${val.minLength} أحرف';
              }
              if (val.maxLength != null && v.trim().length > val.maxLength!) {
                return 'يجب ألا يتجاوز النص ${val.maxLength} أحرف';
              }
              if (val.pattern != null &&
                  !RegExp(val.pattern!).hasMatch(v.trim())) {
                return 'القيمة المدخلة غير مطابقة للنمط المطلوب';
              }
            }
            return null;
          },
        );

      case FieldKind.longText:
        return TextFormField(
          key: Key('dynamic_field_${field.key}'),
          controller: _textControllers[field.key],
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'اكتب التفاصيل هنا...',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          validator: (v) {
            if (field.required && (v == null || v.trim().isEmpty)) {
              return 'هذا الحقل مطلوب';
            }
            if (field.validation != null && v != null && v.trim().isNotEmpty) {
              final val = field.validation!;
              if (val.minLength != null && v.trim().length < val.minLength!) {
                return 'يجب ألا يقل النص عن ${val.minLength} أحرف';
              }
              if (val.maxLength != null && v.trim().length > val.maxLength!) {
                return 'يجب ألا يتجاوز النص ${val.maxLength} أحرف';
              }
              if (val.pattern != null &&
                  !RegExp(val.pattern!).hasMatch(v.trim())) {
                return 'القيمة المدخلة غير مطابقة للنمط المطلوب';
              }
            }
            return null;
          },
        );

      case FieldKind.integer:
      case FieldKind.decimal:
        return TextFormField(
          key: Key('dynamic_field_${field.key}'),
          controller: _textControllers[field.key],
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          validator: (v) {
            if (field.required && (v == null || v.trim().isEmpty)) {
              return 'هذا الحقل مطلوب';
            }
            if (v != null && v.isNotEmpty) {
              final parsed = num.tryParse(v.trim());
              if (parsed == null) {
                return 'يرجى إدخال رقم صحيح';
              }
              if (field.validation != null) {
                final val = field.validation!;
                if (val.min != null && parsed < val.min!) {
                  return 'القيمة يجب ألا تقل عن ${val.min}';
                }
                if (val.max != null && parsed > val.max!) {
                  return 'القيمة يجب ألا تتجاوز ${val.max}';
                }
              }
            }
            return null;
          },
        );

      case FieldKind.employeeReference:
        if (field.choiceOptions.isEmpty && field.dataSource == null) {
          return Semantics(
            label: '${field.labelAr}: لا توجد خيارات مخولة',
            child: Container(
              key: Key('dynamic_field_${field.key}_unavailable'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface02,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.surface03),
              ),
              child: const Row(
                children: [
                  Icon(Icons.people_outline, color: AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لا توجد خيارات موظفين مخولة لهذا الحقل. راجع إعدادات نوع الطلب.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildSearchableSelector(field);

      case FieldKind.date:
        final dateVal = _values[field.key] as String?;
        return InkWell(
          key: Key('dynamic_field_${field.key}'),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 90)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              final formatted = DateFormat('yyyy-MM-dd').format(picked);
              setState(() => _values[field.key] = formatted);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface02,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surface03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dateVal ?? 'اختر التاريخ',
                    style: TextStyle(
                      color: dateVal != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today,
                    size: 18, color: AppTheme.primaryColor),
              ],
            ),
          ),
        );

      case FieldKind.time:
        final timeVal = _values[field.key] as String?;
        return InkWell(
          key: Key('dynamic_field_${field.key}'),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              final formatted =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              setState(() => _values[field.key] = formatted);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface02,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surface03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    timeVal ?? 'اختر الوقت (ساعة:دقيقة)',
                    style: TextStyle(
                      color: timeVal != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.access_time,
                    size: 18, color: AppTheme.primaryColor),
              ],
            ),
          ),
        );

      case FieldKind.dateTime:
        final dtVal = _values[field.key] as String?;
        return InkWell(
          key: Key('dynamic_field_${field.key}'),
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 90)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null && mounted) {
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              final time = pickedTime ?? const TimeOfDay(hour: 9, minute: 0);
              final fullDt = DateTime.utc(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                time.hour,
                time.minute,
              );
              setState(() => _values[field.key] = fullDt.toIso8601String());
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface02,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surface03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dtVal ?? 'اختر التاريخ والوقت',
                    style: TextStyle(
                      color: dtVal != null
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.event, size: 18, color: AppTheme.primaryColor),
              ],
            ),
          ),
        );

      case FieldKind.singleChoice:
        return DropdownButtonFormField<String>(
          key: Key('dynamic_field_${field.key}'),
          isExpanded: true,
          dropdownColor: Colors.white,
          initialValue: _values[field.key] as String?,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          hint: const Text('اختر من القائمة',
              style: TextStyle(color: AppTheme.textMuted)),
          items: field.choiceOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.code,
              child: Text(opt.labelAr, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (v) => setState(() => _values[field.key] = v),
          validator: (v) {
            if (field.required && (v == null || v.isEmpty)) {
              return 'يرجى اختيار قيمة من القائمة';
            }
            return null;
          },
        );

      case FieldKind.multipleChoice:
        final selectedList = (_values[field.key] as List<String>?) ?? [];
        return Column(
          key: Key('dynamic_field_${field.key}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: field.choiceOptions.map((opt) {
                final isSelected = selectedList.contains(opt.code);
                return FilterChip(
                  key: Key('choice_${field.key}_${opt.code}'),
                  label: Text(opt.labelAr),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedList.add(opt.code);
                      } else {
                        selectedList.remove(opt.code);
                      }
                      _values[field.key] = List<String>.from(selectedList);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );

      case FieldKind.boolean:
        final currentVal = _values[field.key] as bool? ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentVal ? 'نعم' : 'لا',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
            Switch(
              key: Key('dynamic_field_${field.key}'),
              value: currentVal,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (val) => setState(() => _values[field.key] = val),
            ),
          ],
        );

      case FieldKind.attachment:
        final isUploading = _uploadingFields.contains(field.key);
        final uploadError = _uploadErrors[field.key];
        final uploadedAttachment = _uploadedAttachments[field.key];

        if (isUploading) {
          return Container(
            key: Key('dynamic_field_${field.key}_uploading'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface02,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surface03),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'جاري رفع المرفق الخاص...',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        if (uploadedAttachment != null) {
          return Container(
            key: Key('dynamic_field_${field.key}'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface02,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.surface03),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_file, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uploadedAttachment.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${(uploadedAttachment.sizeBytes / 1024).toStringAsFixed(1)} ك.ب • ${uploadedAttachment.state}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('remove_attachment_${field.key}'),
                  icon:
                      const Icon(Icons.close, size: 18, color: AppTheme.coral),
                  onPressed: () {
                    setState(() {
                      _uploadedAttachments.remove(field.key);
                      _values.remove(field.key);
                    });
                  },
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              key: Key('dynamic_field_${field.key}_btn'),
              onPressed: () => _pickAndUploadAttachment(field),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('إرفاق ملف خاص'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            if (uploadError != null) ...[
              const SizedBox(height: 6),
              Text(
                uploadError,
                style: const TextStyle(color: AppTheme.coral, fontSize: 12),
              ),
            ],
          ],
        );
    }
  }

  Future<void> _pickAndUploadAttachment(RequestFieldDefinition field) async {
    final picker = widget.attachmentPicker ?? const PlatformAttachmentPicker();
    final client = widget.apiClient ?? context.read<ApiClient>();

    PickedFileResult? file;
    try {
      file = await picker.pickFile();
    } on AttachmentPickerUnavailableException catch (e) {
      if (mounted) {
        setState(() {
          _uploadErrors[field.key] = e.message;
        });
      }
      return;
    } on AttachmentPickerException catch (e) {
      if (mounted) {
        setState(() {
          _uploadErrors[field.key] = e.message;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadErrors[field.key] =
              'خدمة اختيار الملفات غير متوفرة على هذا الجهاز';
        });
      }
      return;
    }

    if (file == null) return;

    if (!mounted) return;
    setState(() {
      _uploadingFields.add(field.key);
      _uploadErrors.remove(field.key);
    });

    try {
      final attachment = await client.uploadRequestAttachment(
        bytes: file.bytes,
        filename: file.filename,
        mediaType: file.mediaType,
      );
      if (mounted) {
        setState(() {
          _uploadedAttachments[field.key] = attachment;
          // Store ONLY the returned authorized attachment ID
          _values[field.key] = attachment.id;
          _uploadingFields.remove(field.key);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingFields.remove(field.key);
          _uploadErrors[field.key] = AppFailureMapper.fromGeneric(e).message;
        });
      }
    }
  }

  Widget _buildSearchableSelector(RequestFieldDefinition field) {
    final selectedValue = _values[field.key]?.toString();
    final selectedLabel = _selectedOptionLabels[field.key] ??
        field.choiceOptions
            .where((c) => c.code == selectedValue)
            .map((c) => c.labelAr)
            .firstOrNull ??
        selectedValue;

    return FormField<String>(
      initialValue: selectedValue,
      validator: (v) {
        if (field.required &&
            (selectedValue == null || selectedValue.isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('dynamic_field_${field.key}'),
              onTap: () => _openSearchableSelectorModal(field, formFieldState),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface02,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: formFieldState.hasError
                        ? AppTheme.errorColor
                        : AppTheme.surface03,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      field.kind == FieldKind.employeeReference
                          ? Icons.badge_outlined
                          : Icons.list_alt_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (selectedLabel != null && selectedLabel.isNotEmpty)
                            ? selectedLabel
                            : (field.kind == FieldKind.employeeReference
                                ? 'اختر الموظف'
                                : 'اختر ${field.labelAr}...'),
                        style: TextStyle(
                          color: (selectedLabel != null &&
                                  selectedLabel.isNotEmpty)
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selectedValue != null && selectedValue.isNotEmpty)
                      IconButton(
                        key: Key('dynamic_selector_clear_${field.key}'),
                        icon: const Icon(Icons.close,
                            size: 18, color: AppTheme.steel),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _values[field.key] = null;
                            _selectedOptionLabels.remove(field.key);
                          });
                          formFieldState.didChange(null);
                        },
                      )
                    else
                      const Icon(Icons.arrow_drop_down, color: AppTheme.steel),
                  ],
                ),
              ),
            ),
            if (formFieldState.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  formFieldState.errorText!,
                  style:
                      const TextStyle(color: AppTheme.errorColor, fontSize: 12),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openSearchableSelectorModal(
    RequestFieldDefinition field,
    FormFieldState<String> formFieldState,
  ) async {
    DynamicRequestRepository? repo = widget.dynamicRequestRepository;
    if (repo == null && mounted) {
      try {
        repo = context.read<DynamicRequestRepository>();
      } catch (_) {}
    }

    final selected = await showModalBottomSheet<RequestSelectorOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalCtx) {
        return _SearchSelectorBottomSheet(
          field: field,
          definitionVersionId: widget.definitionVersionId ?? '',
          repository: repo,
          initialSelectedValue: _values[field.key]?.toString(),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _values[field.key] = selected.value;
        _selectedOptionLabels[field.key] = selected.label;
      });
      formFieldState.didChange(selected.value);
    }
  }
}

class _SearchSelectorBottomSheet extends StatefulWidget {
  final RequestFieldDefinition field;
  final String definitionVersionId;
  final DynamicRequestRepository? repository;
  final String? initialSelectedValue;

  const _SearchSelectorBottomSheet({
    required this.field,
    required this.definitionVersionId,
    required this.repository,
    this.initialSelectedValue,
  });

  @override
  State<_SearchSelectorBottomSheet> createState() =>
      _SearchSelectorBottomSheetState();
}

class _SearchSelectorBottomSheetState
    extends State<_SearchSelectorBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<RequestSelectorOption> _options = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _searchDebounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadOptions('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<RequestSelectorOption> fetched = [];

      // If repository exists, fetch remote options
      if (widget.repository != null &&
          (widget.field.dataSource != null ||
              widget.field.kind == FieldKind.employeeReference)) {
        try {
          fetched = await widget.repository!.getFieldOptions(
            definitionVersionId: widget.definitionVersionId,
            fieldKey: widget.field.key,
            search: query.isNotEmpty ? query : null,
          );
        } catch (_) {
          // If remote options fail, fallback to choices
        }
      }

      // If remote returned empty and choice options exist, search locally
      if (fetched.isEmpty && widget.field.choiceOptions.isNotEmpty) {
        final localChoices = widget.field.choiceOptions
            .where((c) {
              if (query.isEmpty) return true;
              return c.labelAr.toLowerCase().contains(query.toLowerCase()) ||
                  c.code.toLowerCase().contains(query.toLowerCase());
            })
            .map((c) => RequestSelectorOption(
                  value: c.code,
                  label: c.labelAr,
                ))
            .toList();
        fetched = localChoices;
      }

      if (mounted && generation == _searchGeneration) {
        setState(() {
          _options = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppFailureMapper.fromGeneric(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.field.labelAr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('selector_search_input'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث في الخيارات...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _loadOptions('');
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: _scheduleSearch,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleSearch(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadOptions(text.trim());
    });
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: AppTheme.errorColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_options.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد خيارات مطابقة للبحث',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _options.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        final option = _options[index];
        final isSelected = option.value == widget.initialSelectedValue;

        return ListTile(
          key: Key('option_${option.value}'),
          title: Text(
            option.label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
            ),
          ),
          subtitle: option.subtitle != null && option.subtitle!.isNotEmpty
              ? Text(
                  option.subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                )
              : null,
          trailing: isSelected
              ? const Icon(Icons.check, color: AppTheme.primaryColor)
              : null,
          onTap: () => Navigator.of(context).pop(option),
        );
      },
    );
  }
}
