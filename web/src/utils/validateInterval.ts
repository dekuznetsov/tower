// Port of the Flutter interval validator (mobile/lib/utils/validate_interval.dart).
// An interval must be a positive integer (>= 1). Anything else — empty, non-numeric,
// zero, negative, or decimal — is rejected.

/**
 * Validates a raw interval input string.
 * @returns `null` when valid, or a human-readable error message when invalid.
 */
export function validateInterval(input: string): string | null {
  const trimmed = input.trim();
  if (trimmed === '') return 'Введіть значення';
  // Only plain non-negative integer digits are accepted (no sign, decimal, or exponent).
  if (!/^\d+$/.test(trimmed)) return 'Має бути ціле число';
  const value = Number(trimmed);
  if (!Number.isInteger(value) || value < 1) return 'Має бути не менше 1';
  return null;
}

/** Convenience predicate wrapping {@link validateInterval}. */
export function isValidInterval(input: string): boolean {
  return validateInterval(input) === null;
}
