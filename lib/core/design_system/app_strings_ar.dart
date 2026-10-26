class AppStringsAr {
  // Brand & App Identity (Feature 003 Pilot)
  static const String appName = 'العبقري HR';
  static const String appNameSpoken = 'العبقري إتش آر';
  static const String appTitle = 'العبقري HR — نظام إدارة الحضور والطلبات';

  // Feature 003 Pilot Guidance
  static const String pilotGuidanceTitle =
      'دليل المشارك في الفترة التجريبية (Pilot)';
  static const String pilotLocationNotice =
      'تحديد الموقع الجغرافي: يُطلب إذن الموقع فقط للتحقق من التواجد داخل النطاق المعتمد للفرع عند الضغط على تسجيل الحضور أو الانصراف، ولا يتم التتبع أو استخدام الموقع في الخلفية مطلقاً.';
  static const String pilotOfflineNotice =
      'العمل دون اتصال (أوفلاين): يتيح التطبيق تسجيل البصمة وتقديم الطلبات حتى عند انقطاع الإنترنت؛ حيث تُحفظ البيانات محلياً بأمان تام وتتم مزامنتها مع الخادم تلقائياً فور توفر الاتصال.';
  static const String pilotPrivacyNotice =
      'إشعار الخصوصية والبيانات التجريبية: هذه النسخة تعمل ضمن الفترة التجريبية المصرح بها وتخضع لسياسات حماية البيانات وحصر الوصول المصرح به للبيانات الوظيفية.';
  static const String pilotSupportRoute =
      'قناة الدعم الفني: في حال مواجهة أي صعوبة فنية أو استفسار، يرجى إخطار مسؤول الموارد البشرية بالشركة أو التواصل عبر قناة الدعم المعتمدة للفترة التجريبية.';
  static const String pilotEmergencyWorkaround =
      'إجراء الطوارئ البديل: إذا تعذر استخدام التطبيق بسبب عطل فني في الهاتف أو نفاد البطارية، يرجى إخطار المشرف المباشر فوراً لتوثيق الحضور والطلبات بالطريقة البديلة المعتمدة.';
  static const String pilotLimitationsNotice =
      'محددات الفترة التجريبية: التطبيق في مرحلة الإطلاق التجريبي بهدف التقييم وضمان الجودة، وتخضع جميع العمليات للمراجعة والتدقيق الإداري.';

  // Auth
  static const String loginTitle = 'تسجيل الدخول';
  static const String emailLabel = 'البريد الإلكتروني';
  static const String passwordLabel = 'كلمة المرور';
  static const String loginButton = 'دخول';

  // Shift & Attendance
  static const String currentShift = 'الوردية الحالية';
  static const String checkIn = 'تسجيل حضور';
  static const String checkOut = 'تسجيل انصراف';
  static const String branch = 'الفرع';
  static const String shiftTime = 'وقت الوردية';
  static const String status = 'الحالة';

  // States (T035 complete terminal and offline states)
  static const String statusPresent = 'حاضر الآن (تم التحقق)';
  static const String statusNotStarted = 'لم تبدأ الوردية';
  static const String statusCompleted = 'تم الانصراف بنجاح';
  static const String statusPendingReview = 'قيد المراجعة الإدارية';
  static const String statusPendingSync =
      'محفوظ محلياً (في انتظار الاتصال بالمزامنة)';
  static const String statusRejected = 'تم رفض الطلب من الخادم';
  static const String statusConflict = 'تعارض: تم تسجيل هذا الإجراء مسبقاً';
  static const String statusOffline = 'العمل في وضع عدم الاتصال (أوفلاين)';

  // Terminal reasons
  static const String reasonOutOfRadius =
      'الموقع الجغرافي خارج نطاق العمل المسموح به';
  static const String reasonStaleLocation = 'بيانات الموقع قديمة أو غير دقيقة';
  static const String reasonShiftExpired = 'انتهت نافذة تسجيل الوردية';
  static const String reasonDuplicate = 'تم تسجيل الحضور بالفعل لهذه الوردية';

  // Location
  static const String locationWaiting = 'جاري التحقق من الموقع الجغرافي...';
  static const String locationReady = 'أنت داخل نطاق موقع العمل المعتمد';
  static const String locationOutOfRange = 'أنت خارج نطاق موقع العمل المعتمد';
  static const String locationPermissionRequired =
      'يرجى تفعيل صلاحية الموقع للمتابعة';
  static const String locationPermissionPermanentlyDenied =
      'تم رفض إذن الموقع بشكل دائم، يرجى تفعيله من إعدادات التطبيق';
  static const String locationServiceDisabled =
      'خدمات الموقع الجغرافي (GPS) غير مفعلة، يرجى تشغيلها';
  static const String locationTimeout =
      'تعذر الحصول على الموقع الجغرافي في الوقت المحدد، يرجى المحاولة مجدداً';
  static const String locationIntegrityFailed =
      'تعذر التحقق من سلامة الموقع. أوقف تطبيقات الموقع الوهمي ثم حاول مجدداً.';

  // Feedback
  static const String syncSuccess = 'تمت مزامنة الحضور بنجاح';
  static const String offlineSaved =
      'تم حفظ تسجيلك على الهاتف وسيرفع فور توفر الاتصال';
  static const String retrySync = 'إعادة المحاولة';

  // Feature 002: Requests & Approvals
  static const String requestsNav = 'الطلبات';
  static const String myRequestsTitle = 'طلباتي';
  static const String newRequest = 'طلب جديد';
  static const String requestHistory = 'سجل الطلبات';
  static const String requestDetails = 'تفاصيل الطلب';
  static const String approvalTimeline = 'مسار الموافقات';
  static const String approvalInboxTitle = 'صندوق اعتمادات المدير';

  // Request Types
  static const String typeLeave = 'إجازة';
  static const String typePermission = 'إذن عمل';
  static const String typeCorrection = 'تصحيح حضور';

  // Leave Form
  static const String leaveCategory = 'نوع الإجازة';
  static const String leaveAnnual = 'إجازة اعتيادية (سنوية)';
  static const String leaveCasual = 'إجازة عارضة';
  static const String leaveSick = 'إجازة مرضية';
  static const String leaveUnpaid = 'إجازة بدون راتب';
  static const String startDate = 'تاريخ البدء';
  static const String endDate = 'تاريخ الانتهاء';
  static const String requestedAmount = 'المدة المطلوبة';
  static const String availableBalance = 'الرصيد المتاح حالياً';
  static const String projectedBalance = 'الرصيد التقديري بعد الطلب';
  static const String insufficientBalanceWarning =
      'تنبيه: الرصيد المتوفر قد لا يكفي لاعتماد هذا الطلب';

  // Permission Form
  static const String permissionCategory = 'نوع الإذن';
  static const String permissionEarlyLeave = 'انصراف مبكر';
  static const String permissionLateArrival = 'حضور متأخر';
  static const String permissionBusinessMission = 'مهمة عمل خارجية';
  static const String affectedShift = 'الوردية المتأثرة';
  static const String startTime = 'من الساعة';
  static const String endTime = 'إلى الساعة';
  static const String permissionDuration = 'مدة الإذن';

  // Attendance Correction Form
  static const String correctionTarget = 'سجل الحضور المراد تصحيحه';
  static const String missingCheckIn = 'تسجيل حضور مفقود';
  static const String missingCheckOut = 'تسجيل انصراف مفقود';
  static const String wrongTime = 'تعديل وقت التسجيل';
  static const String originalRecord = 'السجل الأصلي';
  static const String proposedTime = 'الوقت المقترح الصحيح';
  static const String correctionReason = 'سبب التصحيح';

  // Actions & Dialogs
  static const String submit = 'تقديم الطلب';
  static const String cancel = 'إلغاء';
  static const String cancelRequestAction = 'إلغاء الطلب';
  static const String confirmCancelTitle = 'تأكيد إلغاء الطلب';
  static const String confirmCancelMessage =
      'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.';
  static const String reasonLabel = 'سبب الطلب أو الملاحظات';
  static const String requiredField = 'هذا الحقل مطلوب';

  // Reviewer Decisions (T035-T036)
  static const String approveAction = 'اعتماد الطلب';
  static const String rejectAction = 'رفض الطلب';
  static const String decisionReasonPrompt = 'يرجى ذكر سبب الرفض (إلزامي):';
  static const String decisionCommentPrompt = 'ملاحظات الاعتماد (اختياري):';
  static const String decisionConflict =
      'تعارض: تم اتخاذ قرار في هذه المرحلة مسبقاً أو تم إلغاء الطلب';
  static const String decisionSuccess = 'تم تسجيل القرار بنجاح';

  // Filters & Tabs
  static const String filterAll = 'الكل';
  static const String filterPending = 'قيد الانتظار';
  static const String filterApproved = 'معتمدة';
  static const String filterRejected = 'مرفوضة';
  static const String filterCancelled = 'ملغاة';

  // Status Labels
  static const String stateSubmitted = 'تم التقديم';
  static const String statePendingApproval = 'بانتظار الاعتماد';
  static const String stateApproved = 'معتمد';
  static const String stateRejected = 'مرفوض';
  static const String stateCancelled = 'ملغى من الموظف';
  static const String statePendingSync = 'في انتظار المزامنة';
  static const String stateConflict = 'تعارض';
  static const String statusError = 'حدث خطأ أثناء المعالجة';
  static const String noRequestsFound = 'لا توجد طلبات في هذا القسم حالياً';

  // Navigation & Tabs
  static const String requestsManagementTitle = 'إدارة الطلبات والموافقات';
  static const String attendanceTab = 'الحضور';
  static const String requestsTab = 'طلباتي';
  static const String myRequestsTab = 'طلباتي';
  static const String newRequestTab = 'تقديم طلب';
  static const String reviewerInboxTitle = 'صندوق اعتمادات المدير';

  // Titles & Labels
  static const String leaveTypeTitle = 'طلب إجازة';
  static const String permissionTypeTitle = 'إذن انصراف / تأخير';
  static const String attendanceCorrectionTitle = 'تصحيح بصمة حضور';
  static const String leaveBalance = 'رصيد الإجازات المتاح';
  static const String reasonFieldLabel = 'سبب الطلب';
  static const String reasonRequired =
      'يرجى كتابة سبب الطلب (على الأقل 3 أحرف)';
  static const String submitRequest = 'إرسال الطلب';
  static const String requestSubmittedSuccess =
      'تم إرسال الطلب بنجاح وهو قيد الاعتماد';
  static const String offlineRequestSavedNotice =
      'تم حفظ الطلب محلياً بنجاح وسيرسل تلقائياً فور توفر الاتصال';
  static const String duplicateRequestConflictNotice =
      'تعارض: تم تقديم طلب مشابه مسبقاً لنفس الفترة';

  // Cancellation & Dialogs
  static const String cancelRequest = 'إلغاء الطلب';
  static const String confirmCancelRequest = 'تأكيد إلغاء الطلب';
  static const String confirmCancelRequestMessage =
      'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟';
  static const String cancelReasonLabel = 'سبب الإلغاء';
  static const String requestCancelledSuccess = 'تم إلغاء الطلب بنجاح';

  // Roles & Reviewer
  static const String managerRole = 'المدير المباشر';
  static const String hrRole = 'الموارد البشرية';
  static const String confirmApproveTitle = 'تأكيد اعتماد الطلب';
  static const String confirmRejectTitle = 'تأكيد رفض الطلب';
  static const String reviewerCommentLabel = 'ملاحظات المراجع';

  // Feature 012 US5: Password Recovery
  static const String forgotPassword = 'نسيت كلمة المرور؟';
  static const String passwordRecoveryTitle = 'استعادة كلمة المرور';
  static const String passwordRecoverySubtitle =
      'أدخل بريدك الإلكتروني لتلقي تعليمات إعادة تعيين كلمة المرور.';
  static const String passwordResetTitle = 'تعيين كلمة المرور الجديدة';
  static const String passwordResetSubtitle =
      'أدخل رمز التحقق وكلمة المرور الجديدة لإعادة تعيين حسابك.';
  static const String requestResetButton = 'إرسال تعليمات الاستعادة';
  static const String confirmResetButton = 'تأكيد كلمة المرور الجديدة';
  static const String resetTokenLabel = 'رمز التحقق (الرمز المؤقت)';
  static const String newPasswordLabel = 'كلمة المرور الجديدة';
  static const String confirmNewPasswordLabel = 'تأكيد كلمة المرور الجديدة';
  static const String passwordResetRequestSuccess =
      'إذا كان الحساب مسجلاً لدينا، فستصلك رسالة تحتوي على تعليمات إعادة تعيين كلمة المرور.';
  static const String passwordResetSuccess =
      'تم تغيير كلمة المرور بنجاح. تم إنهاء كافة الجلسات السابقة، يرجى تسجيل الدخول بكلمة المرور الجديدة.';
  static const String haveResetTokenPrompt = 'لديك رمز التحقق بالفعل؟ اضغط هنا';
  static const String requestNewTokenPrompt = 'لم يصلك الرمز؟ طلب رمز جديد';
  static const String backToLogin = 'العودة لتسجيل الدخول';
  static const String enterResetTokenAction = 'إدخال رمز التحقق';
  static const String tokenRequired = 'يرجى إدخال رمز التحقق';
  static const String tokenLengthNotice = 'يجب ألا يقل الرمز عن 10 أحرف';
  static const String passwordLengthNotice = 'يجب ألا تقل كلمة المرور عن 12 حرفاً';
  static const String passwordsMismatch = 'كلمتا المرور غير متطابقتين';
}

