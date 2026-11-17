import '../data/database.dart';

class ConflictInfo {
  final String parcelaId;
  final Map<String, dynamic> localValues;
  final Map<String, dynamic> serverValues;
  final List<String> differingFields;
  final ConflictResolution? resolution;

  ConflictInfo({
    required this.parcelaId,
    required this.localValues,
    required this.serverValues,
    required this.differingFields,
    this.resolution,
  });

  ConflictInfo copyWith({
    String? parcelaId,
    Map<String, dynamic>? localValues,
    Map<String, dynamic>? serverValues,
    List<String>? differingFields,
    ConflictResolution? resolution,
  }) {
    return ConflictInfo(
      parcelaId: parcelaId ?? this.parcelaId,
      localValues: localValues ?? this.localValues,
      serverValues: serverValues ?? this.serverValues,
      differingFields: differingFields ?? this.differingFields,
      resolution: resolution ?? this.resolution,
    );
  }

  static ConflictInfo? fromSyncComparison(
    Parcela local,
    Map<String, dynamic> server,
  ) {
    final localMap = _parcelaToMap(local);
    final serverMap = server;

    final differingFields = <String>[];
    for (final key in localMap.keys) {
      if (key == 'updatedAt' || key == 'id' || key == 'uuid') continue;
      final localVal = normalizeValue(localMap[key]);
      final serverVal = normalizeValue(serverMap[key]);
      if (localVal != serverVal) {
        differingFields.add(key);
      }
    }

    if (differingFields.isEmpty) return null;

    return ConflictInfo(
      parcelaId: local.uuid,
      localValues: localMap,
      serverValues: serverMap,
      differingFields: differingFields,
    );
  }

  static String normalizeValue(dynamic value) {
    if (value == null) return '';
    if (value is int) {
      // Ints have no fractional part: 42 must stay '42', not '42.0'.
      // (Bug Q0: value.toDouble().toString() turned int 42 into '42.0', which
      // made fromSyncComparison flag false conflicts on numeric fields.)
      return value.toString();
    }
    if (value is double) {
      // Whole doubles collapse to the int form so 42.0 == 42 across
      // int/double JSON representations; fractions keep their value
      // (e.g., 1.5 vs 1.50 both normalize to '1.5').
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is DateTime) {
      // Normalize dates to ISO8601
      return value.toIso8601String();
    }
    if (value is bool) {
      return value.toString();
    }
    return value.toString();
  }

  static Map<String, dynamic> _parcelaToMap(Parcela p) {
    return {
      'propriedade': p.propriedade,
      'propUt': p.propUt,
      'idParcela': p.idParcela,
      'areaHa': p.areaHa,
      'observacoes': p.observacoes,
      'synced': p.synced,
      'prontaParaSync': p.prontaParaSync,
      'userId': p.userId,
      'createdAt': p.createdAt.toIso8601String(),
      'updatedAt': p.updatedAt.toIso8601String(),
    };
  }
}

enum ConflictResolution {
  keepLocal,
  useServer,
}