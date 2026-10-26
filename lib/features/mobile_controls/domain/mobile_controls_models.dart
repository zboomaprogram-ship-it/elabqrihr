/// Pure domain models for mobile emergency operational controls.
///
/// Bounded by the contract: controls can only restrict fixed allow-listed action keys.
/// Hardware trust, GPS, Play Integrity, and local keys are strictly never configurable remotely.
library;

enum MobileControlKey {
  requestsSubmit('requests.submit'),
  attendanceSubmit('attendance.submit'),
  advancesSubmit('advances.submit'),
  passwordRecovery('password-recovery'),
  notificationsRegistration('notifications.registration');

  const MobileControlKey(this.apiKey);
  final String apiKey;

  static MobileControlKey? tryParse(String key) {
    for (final val in values) {
      if (val.apiKey == key) return val;
    }
    return null;
  }
}

enum MobileControlState {
  normal,
  restricted,
  maintenance;

  static MobileControlState parse(String value) {
    return switch (value.toLowerCase()) {
      'restricted' => MobileControlState.restricted,
      'maintenance' => MobileControlState.maintenance,
      _ => MobileControlState.normal,
    };
  }

  bool get isAllowed => this == MobileControlState.normal;
}

enum MobileAllowedDestination {
  notificationCenter('notification_center'),
  requestHistory('request_history'),
  attendance('attendance');

  const MobileAllowedDestination(this.apiKey);
  final String apiKey;

  static MobileAllowedDestination? tryParse(String key) {
    for (final val in values) {
      if (val.apiKey == key) return val;
    }
    return null;
  }
}

final class MobileBuildPolicy {
  final int minimumBuild;
  final int recommendedBuild;

  const MobileBuildPolicy({
    required this.minimumBuild,
    required this.recommendedBuild,
  });

  bool isUpdateRequired(int currentBuild) => currentBuild < minimumBuild;
  bool isUpdateRecommended(int currentBuild) =>
      currentBuild < recommendedBuild && !isUpdateRequired(currentBuild);

  factory MobileBuildPolicy.fromMap(Map<String, dynamic> json) {
    return MobileBuildPolicy(
      minimumBuild: (json['minimumBuild'] as num?)?.toInt() ?? 1,
      recommendedBuild: (json['recommendedBuild'] as num?)?.toInt() ?? 19,
    );
  }

  Map<String, dynamic> toMap() => {
        'minimumBuild': minimumBuild,
        'recommendedBuild': recommendedBuild,
      };
}

final class MobileControlEntry {
  final MobileControlKey controlKey;
  final MobileControlState state;
  final String outcomeCode;
  final String? messageAr;
  final DateTime? expiresAt;
  final int revision;
  final String? configurationVersion;

  const MobileControlEntry({
    required this.controlKey,
    required this.state,
    required this.outcomeCode,
    this.messageAr,
    this.expiresAt,
    this.revision = 0,
    this.configurationVersion,
  });

  bool get isAllowed => state == MobileControlState.normal;

  factory MobileControlEntry.fromMap(
    MobileControlKey key,
    Map<String, dynamic> json,
  ) {
    final stateStr = json['state'] as String? ?? 'normal';
    final state = MobileControlState.parse(stateStr);
    final outcomeCode = json['outcomeCode'] as String? ??
        (state.isAllowed
            ? 'MOBILE_ACTION_ALLOWED'
            : 'MOBILE_ACTION_RESTRICTED');
    final messageAr = json['messageAr'] as String?;
    final expiresAtStr = json['expiresAt'] as String?;
    final expiresAt =
        expiresAtStr != null ? DateTime.tryParse(expiresAtStr)?.toUtc() : null;
    final revision = (json['revision'] as num?)?.toInt() ?? 0;
    final configurationVersion = json['configurationVersion'] as String?;

    return MobileControlEntry(
      controlKey: key,
      state: state,
      outcomeCode: outcomeCode,
      messageAr: messageAr,
      expiresAt: expiresAt,
      revision: revision,
      configurationVersion: configurationVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'controlKey': controlKey.apiKey,
        'state': state.name,
        'outcomeCode': outcomeCode,
        if (messageAr != null) 'messageAr': messageAr,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'revision': revision,
        if (configurationVersion != null)
          'configurationVersion': configurationVersion,
      };
}

/// Version marker for server-managed content which remains independently
/// authorised and fetched by its own feature repository. The marker cannot carry
/// arbitrary UI instructions or navigation targets.
final class MobileDynamicContent {
  static final RegExp _catalogVersionPattern =
      RegExp(r'^catalog-[a-f0-9]{64}$');

  final String requestCatalogVersion;

  const MobileDynamicContent({required this.requestCatalogVersion});

  static MobileDynamicContent? tryFromMap(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final version = raw['requestCatalogVersion'];
    if (version is! String || !_catalogVersionPattern.hasMatch(version)) {
      return null;
    }
    return MobileDynamicContent(requestCatalogVersion: version);
  }

  Map<String, dynamic> toMap() => {
        'requestCatalogVersion': requestCatalogVersion,
      };
}

final class MobileOperationalConfiguration {
  final String version;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Map<MobileControlKey, MobileControlEntry> controls;
  final MobileBuildPolicy buildPolicy;
  final List<Map<String, dynamic>> messages;
  final Set<MobileAllowedDestination> destinations;
  final MobileDynamicContent? dynamicContent;

  const MobileOperationalConfiguration({
    required this.version,
    required this.issuedAt,
    required this.expiresAt,
    required this.controls,
    required this.buildPolicy,
    required this.messages,
    required this.destinations,
    this.dynamicContent,
  });

  bool isExpired([DateTime? now]) {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    return effectiveNow.isAfter(expiresAt);
  }

  bool isActionAllowed(MobileControlKey key) {
    final entry = controls[key];
    if (entry == null) return true;
    return entry.isAllowed;
  }

  MobileControlEntry? getControl(MobileControlKey key) => controls[key];

  /// Shipped conservative default. If no remote config has been fetched or
  /// cache is expired/unavailable, use standard normal permissions without
  /// executing any remote instructions.
  factory MobileOperationalConfiguration.defaultRestrictive() {
    final now = DateTime.now().toUtc();
    final defaultControls = <MobileControlKey, MobileControlEntry>{
      for (final key in MobileControlKey.values)
        key: MobileControlEntry(
          controlKey: key,
          state: MobileControlState.normal,
          outcomeCode: 'MOBILE_ACTION_ALLOWED',
          revision: 0,
        ),
    };
    return MobileOperationalConfiguration(
      version: '1',
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
      controls: defaultControls,
      buildPolicy: const MobileBuildPolicy(
        minimumBuild: 1,
        recommendedBuild: 19,
      ),
      messages: const [],
      destinations: MobileAllowedDestination.values.toSet(),
    );
  }

  factory MobileOperationalConfiguration.fromMap(Map<String, dynamic> json) {
    final version = json['version'] as String? ?? '1';
    final issuedAt = DateTime.parse(json['issuedAt'] as String).toUtc();
    final expiresAt = DateTime.parse(json['expiresAt'] as String).toUtc();

    final controlsMap = <MobileControlKey, MobileControlEntry>{};
    final rawControls = json['controls'];
    if (rawControls is Map<String, dynamic>) {
      for (final entry in rawControls.entries) {
        final key = MobileControlKey.tryParse(entry.key);
        if (key != null && entry.value is Map<String, dynamic>) {
          controlsMap[key] = MobileControlEntry.fromMap(
            key,
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    final buildPolicy = json['buildPolicy'] is Map<String, dynamic>
        ? MobileBuildPolicy.fromMap(json['buildPolicy'] as Map<String, dynamic>)
        : const MobileBuildPolicy(minimumBuild: 1, recommendedBuild: 19);

    final messages = (json['messages'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    final dynamicContent =
        MobileDynamicContent.tryFromMap(json['dynamicContent']);

    final destinations = <MobileAllowedDestination>{};
    final rawDestinations = json['destinations'] as List<dynamic>?;
    if (rawDestinations != null) {
      for (final dest in rawDestinations) {
        if (dest is String) {
          final parsed = MobileAllowedDestination.tryParse(dest);
          if (parsed != null) destinations.add(parsed);
        }
      }
    }

    return MobileOperationalConfiguration(
      version: version,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      controls: controlsMap,
      buildPolicy: buildPolicy,
      messages: messages,
      destinations: destinations.isEmpty
          ? MobileAllowedDestination.values.toSet()
          : destinations,
      dynamicContent: dynamicContent,
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'controls': {
          for (final entry in controls.entries)
            entry.key.apiKey: entry.value.toMap(),
        },
        'buildPolicy': buildPolicy.toMap(),
        'messages': messages,
        'destinations': destinations.map((d) => d.apiKey).toList(),
        if (dynamicContent != null) 'dynamicContent': dynamicContent!.toMap(),
      };
}
