class Lawyer {
  final String id;
  final String fullName;
  final List<String> specialisations;
  final List<String> languages;
  final String district;
  final bool verified;
  final double? feeLkr;
  final String? bio;

  const Lawyer({
    required this.id,
    required this.fullName,
    required this.specialisations,
    required this.languages,
    required this.district,
    required this.verified,
    this.feeLkr,
    this.bio,
  });

  factory Lawyer.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['profile'] as Map<String, dynamic>)
        : <String, dynamic>{};

    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (profile.containsKey(key) && profile[key] != null)
          return profile[key];
        if (json.containsKey(key) && json[key] != null) return json[key];
      }
      return null;
    }

    List<String> toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final s = value.toString().trim();
      if (s.isEmpty) return [];

      if (s.startsWith('[') && s.endsWith(']')) {
        final inner = s.substring(1, s.length - 1).trim();
        if (inner.isEmpty) return [];
        return inner
            .split(',')
            .map((e) => e.replaceAll('"', '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      return s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final firstName = (pick(['firstName']) ?? '').toString().trim();
    final lastName = (pick(['lastName']) ?? '').toString().trim();
    final rawFullName =
        (pick(['full_name', 'fullName']) ?? '').toString().trim();

    final fullName = rawFullName.isNotEmpty
        ? rawFullName
        : [firstName, lastName].where((e) => e.isNotEmpty).join(' ').trim();

    final verificationRaw = (pick([
              'verificationStatus',
              'verifiedStatus',
              'verified_status',
              'verified'
            ]) ??
            false)
        .toString()
        .toLowerCase();

    final verified = verificationRaw == 'true' ||
        verificationRaw == 'approved' ||
        verificationRaw == 'verified';

    final feeRaw = pick(['fees', 'feesLkr', 'fee_lkr', 'fee']);

    return Lawyer(
      id: (pick(['id', 'lawyer_id']) ?? '').toString(),
      fullName: fullName,
      specialisations: toStringList(
        pick(['specialisations', 'specializations']),
      ),
      languages: toStringList(pick(['languages'])),
      district: (pick(['district']) ?? '').toString(),
      verified: verified,
      feeLkr: feeRaw == null ? null : double.tryParse(feeRaw.toString()),
      bio: pick(['bio'])?.toString(),
    );
  }
}
