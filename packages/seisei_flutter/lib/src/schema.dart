import 'package:seisei_flutter/src/block.dart';

/// Schema for allowed UI blocks.
// ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
@Deprecated(
  'Use Tagflow native blocks: SeiseiNativeBlocks for model output and '
  'SeiseiBlock.toNativeBlocks to migrate stored trees. Removed in '
  'seisei_flutter 0.4.0.',
)
final class SeiseiBlockSchema {
  /// Creates a block schema.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  const SeiseiBlockSchema({
    required this.blockTypes,
    this.actionTypes = const {},
    this.requiredPropsByType = const {},
    this.allowedChildTypesByType = const {},
  });

  /// Allowed block types.
  final Set<String> blockTypes;

  /// Allowed action types.
  final Set<String> actionTypes;

  /// Required property keys for each block type.
  final Map<String, Set<String>> requiredPropsByType;

  /// Allowed direct child types for each parent block type.
  final Map<String, Set<String>> allowedChildTypesByType;

  /// Validates a block tree.
  List<SeiseiBlockValidationError> validate(SeiseiBlock block) {
    final errors = <SeiseiBlockValidationError>[];
    _validateBlock(block, r'$', errors);

    return errors;
  }

  void _validateBlock(
    SeiseiBlock block,
    String path,
    List<SeiseiBlockValidationError> errors,
  ) {
    if (!blockTypes.contains(block.type)) {
      errors.add(
        SeiseiBlockValidationError(
          code: 'block.unsupported_type',
          path: path,
          message: 'Unsupported block type: ${block.type}',
        ),
      );
    }

    for (var i = 0; i < block.actions.length; i += 1) {
      final action = block.actions[i];
      if (!actionTypes.contains(action.type)) {
        errors.add(
          SeiseiBlockValidationError(
            code: 'action.unsupported_type',
            path: '$path.actions[$i]',
            message: 'Unsupported action type: ${action.type}',
          ),
        );
      }
    }

    final requiredProps = requiredPropsByType[block.type] ?? const {};
    for (final prop in requiredProps) {
      if (!block.props.containsKey(prop)) {
        errors.add(
          SeiseiBlockValidationError(
            code: 'prop.required',
            path: '$path.props.$prop',
            message: 'Missing required property: $prop',
          ),
        );
      }
    }

    final allowedChildTypes = allowedChildTypesByType[block.type];
    for (var i = 0; i < block.children.length; i += 1) {
      final child = block.children[i];
      if (allowedChildTypes != null &&
          !allowedChildTypes.contains(child.type)) {
        errors.add(
          SeiseiBlockValidationError(
            code: 'child.unsupported_type',
            path: '$path.children[$i]',
            message: 'Unsupported child type: ${child.type}',
          ),
        );
      }
      _validateBlock(child, '$path.children[$i]', errors);
    }
  }
}

/// Stable UI block validation error.
// ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
@Deprecated(
  'Use Tagflow native blocks: SeiseiNativeBlocks for model output and '
  'SeiseiBlock.toNativeBlocks to migrate stored trees. Removed in '
  'seisei_flutter 0.4.0.',
)
final class SeiseiBlockValidationError {
  /// Creates a validation error.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  const SeiseiBlockValidationError({
    required this.code,
    required this.path,
    required this.message,
  });

  /// Stable error code.
  final String code;

  /// Path to the failing block or action.
  final String path;

  /// Human-readable message.
  final String message;
}
