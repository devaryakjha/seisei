/// Operation applied by a structured generation patch.
enum StructuredPatchOperation {
  /// Add a value at the target path.
  add,

  /// Replace the value at the target path.
  replace,

  /// Remove the value at the target path.
  remove,
}

/// Path-level update for JSON-like structured generation output.
final class StructuredPatch {
  /// Creates a structured patch.
  const StructuredPatch({
    required this.operation,
    required this.path,
    this.value,
  });

  /// Creates an add patch.
  const StructuredPatch.add({
    required this.path,
    required this.value,
  }) : operation = StructuredPatchOperation.add;

  /// Creates a replace patch.
  const StructuredPatch.replace({
    required this.path,
    required this.value,
  }) : operation = StructuredPatchOperation.replace;

  /// Creates a remove patch.
  const StructuredPatch.remove({
    required this.path,
  })  : operation = StructuredPatchOperation.remove,
        value = null;

  /// Patch operation.
  final StructuredPatchOperation operation;

  /// JSON-style path. Object keys are strings and array indexes are integers.
  final List<Object> path;

  /// Value for add and replace operations.
  final Object? value;

  @override
  bool operator ==(Object other) {
    return other is StructuredPatch &&
        other.operation == operation &&
        _listEquals(other.path, path) &&
        _structuredEquals(other.value, value);
  }

  @override
  int get hashCode => Object.hash(
        operation,
        Object.hashAll(path),
        _structuredHash(value),
      );

  @override
  String toString() {
    return 'StructuredPatch($operation, $path, $value)';
  }
}

/// Computes stable path-level patches between two JSON-like values.
List<StructuredPatch> diffStructuredValues(Object? previous, Object? next) {
  final patches = <StructuredPatch>[];
  _diffStructuredValue(previous, next, const [], patches);
  return List.unmodifiable(patches);
}

void _diffStructuredValue(
  Object? previous,
  Object? next,
  List<Object> path,
  List<StructuredPatch> patches,
) {
  if (_structuredEquals(previous, next)) {
    return;
  }

  if (previous is Map && next is Map) {
    _diffMaps(previous, next, path, patches);
    return;
  }

  if (previous is List && next is List && previous.length == next.length) {
    for (var index = 0; index < previous.length; index += 1) {
      _diffStructuredValue(
        previous[index],
        next[index],
        [...path, index],
        patches,
      );
    }
    return;
  }

  patches.add(StructuredPatch.replace(path: path, value: next));
}

void _diffMaps(
  Map<Object?, Object?> previous,
  Map<Object?, Object?> next,
  List<Object> path,
  List<StructuredPatch> patches,
) {
  for (final entry in previous.entries) {
    final key = _pathKey(entry.key);
    if (!next.containsKey(entry.key)) {
      patches.add(StructuredPatch.remove(path: [...path, key]));
      continue;
    }
    _diffStructuredValue(
      entry.value,
      next[entry.key],
      [...path, key],
      patches,
    );
  }

  for (final entry in next.entries) {
    if (previous.containsKey(entry.key)) {
      continue;
    }
    patches.add(
      StructuredPatch.add(
        path: [...path, _pathKey(entry.key)],
        value: entry.value,
      ),
    );
  }
}

Object _pathKey(Object? key) {
  return switch (key) {
    final String value => value,
    final int value => value,
    _ => '$key',
  };
}

bool _structuredEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }

  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_structuredEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }

  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_structuredEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }

  return left == right;
}

bool _listEquals(List<Object> left, List<Object> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _structuredHash(Object? value) {
  return switch (value) {
    final Map map => Object.hashAll(
        map.entries.map(
          (entry) => Object.hash(entry.key, _structuredHash(entry.value)),
        ),
      ),
    final List list => Object.hashAll(list.map(_structuredHash)),
    _ => value.hashCode,
  };
}
