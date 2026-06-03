final _upiIdRegex = RegExp(
  r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.\-_]{1,63}$',
);

String normalizeUpiId(String value) => value.trim().toLowerCase();

bool isValidUpiId(String value) {
  final normalized = normalizeUpiId(value);
  return _upiIdRegex.hasMatch(normalized);
}
