class VideoSession {
  final String sessionId;
  final String appointmentId;
  final String provider;
  final String roomName;
  final String joinUrl;
  final String socketPath;
  final String? socketToken;
  final DateTime? allowedFrom;
  final DateTime? allowedUntil;
  final bool canJoinNow;
  final String state;
  final String message;
  final List<Map<String, dynamic>> iceServers;

  const VideoSession({
    required this.sessionId,
    required this.appointmentId,
    required this.provider,
    required this.roomName,
    required this.joinUrl,
    required this.socketPath,
    required this.socketToken,
    required this.allowedFrom,
    required this.allowedUntil,
    required this.canJoinNow,
    required this.state,
    required this.message,
    required this.iceServers,
  });

  factory VideoSession.fromJson(Map<String, dynamic> json) {
    final rawServers = json['iceServers'];
    final List<Map<String, dynamic>> servers = rawServers is List
        ? rawServers
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      return v?.toString().toLowerCase() == 'true';
    }

    return VideoSession(
      sessionId: (json['sessionId'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? '').toString(),
      provider: (json['provider'] ?? 'webrtc').toString(),
      roomName: (json['roomName'] ?? '').toString(),
      joinUrl: (json['joinUrl'] ?? '').toString(),
      socketPath: (json['socketPath'] ?? '/ws/video').toString(),
      socketToken: json['socketToken']?.toString(),
      allowedFrom: json['allowedFrom'] == null
          ? null
          : DateTime.tryParse(json['allowedFrom'].toString()),
      allowedUntil: json['allowedUntil'] == null
          ? null
          : DateTime.tryParse(json['allowedUntil'].toString()),
      canJoinNow: parseBool(json['canJoinNow']),
      state: (json['state'] ?? 'OPEN').toString(),
      message: (json['message'] ?? '').toString(),
      iceServers: servers,
    );
  }
}
