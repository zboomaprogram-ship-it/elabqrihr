import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

class PickedFileResult {
  final List<int> bytes;
  final String filename;
  final String? mediaType;

  const PickedFileResult({
    required this.bytes,
    required this.filename,
    this.mediaType,
  });
}

class AttachmentPickerException implements Exception {
  final String message;
  const AttachmentPickerException(this.message);

  @override
  String toString() => message;
}

class AttachmentPickerUnavailableException implements Exception {
  final String message;
  const AttachmentPickerUnavailableException(this.message);

  @override
  String toString() => message;
}

abstract class AttachmentPickerService {
  Future<PickedFileResult?> pickFile();
}

class PlatformAttachmentPicker implements AttachmentPickerService {
  final AttachmentPickerService? _delegate;

  const PlatformAttachmentPicker([this._delegate]);

  @override
  Future<PickedFileResult?> pickFile() async {
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.pickFile();
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled selection
        return null;
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      final ext = (file.extension ?? '').toLowerCase();
      String mediaType = 'application/octet-stream';
      if (ext == 'pdf') {
        mediaType = 'application/pdf';
      } else if (ext == 'png') {
        mediaType = 'image/png';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        mediaType = 'image/jpeg';
      } else if (ext == 'docx') {
        mediaType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (ext == 'xlsx') {
        mediaType =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }

      return PickedFileResult(
        bytes: bytes,
        filename: file.name,
        mediaType: mediaType,
      );
    } on MissingPluginException {
      throw const AttachmentPickerUnavailableException(
        'خدمة اختيار الملفات غير متوفرة على هذا الجهاز',
      );
    } on PlatformException catch (e) {
      throw AttachmentPickerException(
        e.message != null && e.message!.isNotEmpty
            ? 'فشل اختيار الملف: ${e.message}'
            : 'فشل اختيار الملف من الجهاز',
      );
    } catch (e) {
      if (e is AttachmentPickerUnavailableException ||
          e is AttachmentPickerException) {
        rethrow;
      }
      throw const AttachmentPickerException('حدث خطأ أثناء اختيار الملف');
    }
  }
}
