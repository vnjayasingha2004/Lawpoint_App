const List<String> sriLankanDistricts = [
  'Ampara',
  'Anuradhapura',
  'Badulla',
  'Batticaloa',
  'Colombo',
  'Galle',
  'Gampaha',
  'Hambantota',
  'Jaffna',
  'Kalutara',
  'Kandy',
  'Kegalle',
  'Kilinochchi',
  'Kurunegala',
  'Mannar',
  'Matale',
  'Matara',
  'Monaragala',
  'Mullaitivu',
  'Nuwara Eliya',
  'Polonnaruwa',
  'Puttalam',
  'Ratnapura',
  'Trincomalee',
  'Vavuniya',
];

const List<String> lawyerLanguageOptions = [
  'English',
  'Sinhala',
  'Tamil',
];

List<String> splitMultiSelectText(String? value) {
  if (value == null || value.trim().isEmpty) return [];

  final seen = <String>{};
  final output = <String>[];

  for (final item in value.split(',')) {
    final next = item.trim();
    final key = next.toLowerCase();
    if (next.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    output.add(next);
  }

  return output;
}

List<String> normalizeSelectedValues(Iterable<String> values) {
  final seen = <String>{};
  final output = <String>[];

  for (final item in values) {
    final next = item.trim();
    final key = next.toLowerCase();
    if (next.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    output.add(next);
  }

  return output;
}

String joinMultiSelectText(Iterable<String> values) {
  return normalizeSelectedValues(values).join(', ');
}

bool matchesSelectedDistrict(String sourceDistricts, String? selectedDistrict) {
  final selected = (selectedDistrict ?? '').trim().toLowerCase();
  if (selected.isEmpty) return true;

  return splitMultiSelectText(sourceDistricts)
      .any((item) => item.toLowerCase() == selected);
}

bool matchesSelectedLanguage(
    List<String> sourceLanguages, String? selectedLanguage) {
  final selected = (selectedLanguage ?? '').trim().toLowerCase();
  if (selected.isEmpty) return true;

  return sourceLanguages.any((item) => item.toLowerCase() == selected);
}

String displayMultiSelectText(String? value, {String empty = 'Not provided'}) {
  final items = splitMultiSelectText(value);
  return items.isEmpty ? empty : items.join(', ');
}
