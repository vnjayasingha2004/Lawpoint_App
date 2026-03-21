import 'package:dio/dio.dart';

import '../../Models/availabilitySlot.dart';
import '../../Models/lawyer.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../storage/dummy_data.dart';
import '../lawyer_form_options.dart';

class LawyerRepository {
  LawyerRepository(this._apiClient);

  final ApiClient _apiClient;

  List<Lawyer> _mapLawyersFromResponse(dynamic data) {
    if (data is List) {
      return data
          .map((e) => Lawyer.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => Lawyer.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<List<Lawyer>> searchLawyers({
    String? query,
    String? district,
    String? language,
    String? specialisation,
  }) async {
    final q = (query ?? '').trim().toLowerCase();
    final selectedDistrict = (district ?? '').trim();
    final selectedLanguage = (language ?? '').trim();
    final selectedSpecialisation = (specialisation ?? '').trim().toLowerCase();

    List<Lawyer> lawyers;

    if (AppConfig.useMockData) {
      lawyers = List<Lawyer>.from(DummyData.lawyers);
    } else {
      final Response res = await _apiClient.get(
        ApiEndpoints.lawyers,
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (specialisation != null && specialisation.isNotEmpty)
            'specialization': specialisation,
        },
      );
      lawyers = _mapLawyersFromResponse(res.data);
    }

    return lawyers.where((l) {
      final matchQuery = q.isEmpty ||
          l.fullName.toLowerCase().contains(q) ||
          l.specialisations.any((s) => s.toLowerCase().contains(q)) ||
          l.languages.any((lang) => lang.toLowerCase().contains(q));

      final matchDistrict =
          matchesSelectedDistrict(l.district, selectedDistrict);

      final matchLanguage =
          matchesSelectedLanguage(l.languages, selectedLanguage);

      final matchSpec = selectedSpecialisation.isEmpty ||
          l.specialisations.any(
            (s) => s.toLowerCase().contains(selectedSpecialisation),
          );

      return matchQuery && matchDistrict && matchLanguage && matchSpec;
    }).toList();
  }

  Future<Lawyer?> getLawyerById(String lawyerId) async {
    if (AppConfig.useMockData) {
      try {
        return DummyData.lawyers.firstWhere((l) => l.id == lawyerId);
      } catch (_) {
        return null;
      }
    }

    final res = await _apiClient.get(ApiEndpoints.lawyerById(lawyerId));
    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : null;
    if (data == null) return null;
    final item = (data['item'] is Map<String, dynamic>)
        ? data['item'] as Map<String, dynamic>
        : data;
    return Lawyer.fromJson(item);
  }

  Lawyer? _extractLawyer(dynamic raw) {
    final data = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    if (data.isEmpty) return null;

    if (data['item'] is Map<String, dynamic>) {
      return Lawyer.fromJson(data['item'] as Map<String, dynamic>);
    }

    if (data['user'] is Map<String, dynamic>) {
      final user =
          Map<String, dynamic>.from(data['user'] as Map<String, dynamic>);
      if (user['profile'] is Map<String, dynamic>) {
        final merged =
            Map<String, dynamic>.from(user['profile'] as Map<String, dynamic>);
        merged['verified'] = user['verified'] ?? user['isVerified'];
        return Lawyer.fromJson(merged);
      }
      return Lawyer.fromJson(user);
    }

    return Lawyer.fromJson(data);
  }

  Future<Lawyer?> getMyLawyerProfile() async {
    if (AppConfig.useMockData) {
      return DummyData.lawyers.first;
    }

    try {
      final res = await _apiClient.get(ApiEndpoints.meLawyer);
      final lawyer = _extractLawyer(res.data);
      if (lawyer != null && lawyer.id.isNotEmpty) {
        return lawyer;
      }
    } on DioException {
      // fallback below
    }

    final res = await _apiClient.get('/api/v1/users/me');
    return _extractLawyer(res.data);
  }

  Map<String, String>? _splitFullName(String? fullName) {
    final value = (fullName ?? '').trim();
    if (value.isEmpty) return null;

    final parts = value.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return {
      'firstName': firstName,
      'lastName': lastName,
    };
  }

  Future<Lawyer?> updateMyLawyerProfile({
    String? fullName,
    String? district,
    String? bio,
    double? feesLkr,
    List<String>? languages,
    List<String>? specializations,
  }) async {
    if (AppConfig.useMockData) {
      return DummyData.lawyers.first;
    }

    final nameParts = _splitFullName(fullName);

    final res = await _apiClient.patch(
      ApiEndpoints.meLawyer,
      data: {
        if (nameParts != null) 'firstName': nameParts['firstName'],
        if (nameParts != null) 'lastName': nameParts['lastName'],
        if (district != null) 'district': district,
        if (bio != null) 'bio': bio,
        if (feesLkr != null) 'feesLkr': feesLkr,
        if (languages != null) 'languages': normalizeSelectedValues(languages),
        if (specializations != null)
          'specializations': normalizeSelectedValues(specializations),
      },
    );
    return _extractLawyer(res.data);
  }

  Future<List<AvailabilitySlot>> getAvailability(String lawyerId) async {
    if (AppConfig.useMockData) {
      return const [
        AvailabilitySlot(
            id: 'a1', dayOfWeek: 1, startTime: '09:00', endTime: '12:00'),
        AvailabilitySlot(
            id: 'a2', dayOfWeek: 3, startTime: '14:00', endTime: '17:00'),
        AvailabilitySlot(
            id: 'a3', dayOfWeek: 5, startTime: '10:00', endTime: '13:00'),
      ];
    }

    final res = await _apiClient.get(ApiEndpoints.lawyerAvailability(lawyerId));
    final data = res.data;

    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<AvailabilitySlot>> getMyAvailability() async {
    try {
      final me = await getMyLawyerProfile();
      if (me == null || me.id.isEmpty) return [];
      return await getAvailability(me.id);
    } catch (_) {
      return [];
    }
  }

  Future<List<AvailabilitySlot>> updateMyAvailability(
      List<AvailabilitySlot> slots) async {
    if (AppConfig.useMockData) return slots;

    final res = await _apiClient.put(
      ApiEndpoints.myAvailability,
      data: {
        'slots': slots.map((e) => e.toJson()).toList(),
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
