/// Validates a string input for use as an interval value (minutes).
///
/// Returns `null` if [input] represents a valid positive integer (≥ 1).
/// Returns a non-null error message string for any invalid input, including:
///   - empty or whitespace-only strings
///   - non-numeric strings
///   - zero
///   - negative integers
///   - decimal numbers (e.g. "1.5", "2.0")
///
/// This function never performs any Firebase write operations.
String? validateInterval(String input) {
  if (input.trim().isEmpty) {
    return 'Please enter a value';
  }

  // Reject decimals before attempting integer parse
  if (input.contains('.')) {
    return 'Please enter a whole number';
  }

  final parsed = int.tryParse(input.trim());
  if (parsed == null) {
    return 'Please enter a valid number';
  }

  if (parsed < 1) {
    return 'Value must be at least 1';
  }

  return null;
}
