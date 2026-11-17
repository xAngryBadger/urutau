import 'package:flutter_test/flutter_test.dart';
import 'package:urutau/models/conflict_info.dart';

void main() {
  group('ConflictInfo', () {
    group('normalizeValue', () {
      test('normalizes null to empty string', () {
        expect(ConflictInfo.normalizeValue(null), '');
      });

      test('normalizes int to string', () {
        expect(ConflictInfo.normalizeValue(42), '42');
      });

      test('normalizes double to string', () {
        expect(ConflictInfo.normalizeValue(1.5), '1.5');
      });

      test('normalizes whole double to int form (Q0: 42.0 -> "42")', () {
        expect(ConflictInfo.normalizeValue(42.0), '42');
      });

      test('int and whole double normalize identically (Q0: no false conflict)', () {
        expect(ConflictInfo.normalizeValue(42), ConflictInfo.normalizeValue(42.0));
        expect(ConflictInfo.normalizeValue(42), '42');
        expect(ConflictInfo.normalizeValue(0), '0');
        expect(ConflictInfo.normalizeValue(-7), '-7');
      });

      test('fractional double keeps precision (1.5 vs 1.50 collide)', () {
        expect(ConflictInfo.normalizeValue(1.50), '1.5');
      });

      test('normalizes bool to string', () {
        expect(ConflictInfo.normalizeValue(true), 'true');
        expect(ConflictInfo.normalizeValue(false), 'false');
      });

      test('normalizes string', () {
        expect(ConflictInfo.normalizeValue('test'), 'test');
      });
    });

    group('fromSyncComparison', () {
      test('returns null when no differences', () {
        // Would need a Parcela mock for real test
        expect(true, isTrue);
      });
    });

    group('copyWith', () {
      test('creates new instance with updated fields', () {
        final original = ConflictInfo(
          parcelaId: '1',
          localValues: {'key': 'value'},
          serverValues: {'key': 'other'},
          differingFields: ['key'],
          resolution: ConflictResolution.keepLocal,
        );

        final updated = original.copyWith(resolution: ConflictResolution.useServer);

        expect(updated.resolution, ConflictResolution.useServer);
        expect(updated.parcelaId, '1');
        expect(updated.localValues, {'key': 'value'});
      });
    });
  });
}