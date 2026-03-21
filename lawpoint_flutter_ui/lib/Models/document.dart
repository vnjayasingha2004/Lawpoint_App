class DocumentItem {
  final String id;
  final String fileName;
  final String fileType;
  final DateTime uploadedAt;
  final bool shared;
  final String? checksum;
  final int sizeBytes;
  final String? downloadUrl;
  final String? previewUrl;
  final List<String> sharedWithIds;

  final String classification;
  final String? secretCategory;
  final String redactionStatus;
  final bool hasRedactedVersion;

  final bool requiresPreviewBeforeShare;
  final bool reviewedForShare;
  final String? redactionReviewedAt;

  final bool manualShareApproved;
  final String? manualShareApprovedAt;

  const DocumentItem({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.uploadedAt,
    required this.shared,
    this.checksum,
    this.sizeBytes = 0,
    this.downloadUrl,
    this.previewUrl,
    this.sharedWithIds = const [],
    this.classification = 'NORMAL',
    this.secretCategory,
    this.redactionStatus = 'NOT_REQUIRED',
    this.hasRedactedVersion = false,
    this.requiresPreviewBeforeShare = false,
    this.reviewedForShare = false,
    this.redactionReviewedAt,
    this.manualShareApproved = false,
    this.manualShareApprovedAt,
  });

  bool get isSecret => classification.toUpperCase() == 'SECRET';

  factory DocumentItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    List<String> parseStringList(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      return const [];
    }

    bool parseBool(dynamic v) => v == true || v?.toString() == 'true';

    return DocumentItem(
      id: (json['id'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['fileName'] ?? json['name'] ?? '')
          .toString(),
      fileType:
          (json['file_type'] ?? json['fileType'] ?? json['mimeType'] ?? '')
              .toString(),
      uploadedAt: parseDate(json['uploaded_at'] ?? json['uploadedAt']),
      shared: parseBool(json['shared']),
      checksum: json['checksum']?.toString(),
      sizeBytes: parseInt(json['sizeBytes']),
      downloadUrl: json['downloadUrl']?.toString(),
      previewUrl: json['previewUrl']?.toString(),
      sharedWithIds: parseStringList(json['sharedWithIds']),
      classification: (json['classification'] ?? 'NORMAL').toString(),
      secretCategory: json['secretCategory']?.toString(),
      redactionStatus: (json['redactionStatus'] ?? 'NOT_REQUIRED').toString(),
      hasRedactedVersion: parseBool(json['hasRedactedVersion']),
      requiresPreviewBeforeShare: parseBool(json['requiresPreviewBeforeShare']),
      reviewedForShare: parseBool(json['reviewedForShare']),
      redactionReviewedAt: json['redactionReviewedAt']?.toString(),
      manualShareApproved: parseBool(json['manualShareApproved']),
      manualShareApprovedAt: json['manualShareApprovedAt']?.toString(),
    );
  }
}
