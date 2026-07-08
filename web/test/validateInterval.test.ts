import { describe, it, expect } from 'vitest';
import fc from 'fast-check';
import { validateInterval, isValidInterval } from '../src/utils/validateInterval';

// Reference predicate: an input is valid iff, trimmed, it is all digits and >= 1.
const referenceValid = (input: string): boolean => {
  const t = input.trim();
  return /^\d+$/.test(t) && Number(t) >= 1;
};

describe('validateInterval', () => {
  // Feature: web-app-google-auth, Property W5: Interval validation rejects invalid input
  it('W5: null iff input is a positive integer, non-null otherwise', () => {
    fc.assert(
      fc.property(fc.string(), (input) => {
        const result = validateInterval(input);
        expect(result === null).toBe(referenceValid(input));
      }),
      { numRuns: 500 },
    );
  });

  it('W5: rejects all clearly-invalid representative inputs', () => {
    for (const bad of ['', '   ', 'abc', '0', '-1', '1.5', '1e3', '+2', ' 3 x', 'NaN']) {
      expect(validateInterval(bad)).not.toBeNull();
      expect(isValidInterval(bad)).toBe(false);
    }
  });

  it('accepts positive integers (incl. leading zeros and surrounding spaces)', () => {
    fc.assert(
      fc.property(fc.integer({ min: 1, max: 100000 }), (n) => {
        expect(validateInterval(String(n))).toBeNull();
        expect(validateInterval(`  ${n}  `)).toBeNull();
      }),
      { numRuns: 200 },
    );
  });
});
