import 'block.dart';

/// Schema for allowed UI blocks.
final class SeiseiBlockSchema {
  /// Creates a block schema.
  const SeiseiBlockSchema({
    required this.blockTypes,
    this.actionTypes = const {},
  });

  /// Allowed block types.
  final Set<String> blockTypes;

  /// Allowed action types.
  final Set<String> actionTypes;

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

    for (var i = 0; i < block.children.length; i += 1) {
      _validateBlock(block.children[i], '$path.children[$i]', errors);
    }
  }
}

/// Stable UI block validation error.
final class SeiseiBlockValidationError {
  /// Creates a validation error.
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
