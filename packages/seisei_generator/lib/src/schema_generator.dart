import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:seisei/seisei.dart';
import 'package:source_gen/source_gen.dart';

const _generateSchemaChecker = TypeChecker.typeNamed(
  GenerateSchema,
  inPackage: 'seisei',
);
const _schemaFieldChecker = TypeChecker.typeNamed(
  SchemaField,
  inPackage: 'seisei',
);
const _schemaVariantChecker = TypeChecker.typeNamed(
  SchemaVariant,
  inPackage: 'seisei',
);

/// Generates `ObjectSchema` definitions and typed decoders for classes
/// annotated with `GenerateSchema`.
///
/// Every generated declaration is private to the annotated library:
/// `_$<Class>Schema` and `_$<Class>FromJson` for object classes, and
/// `_$<Class>Variants` and `_$<Class>FromJson` for sealed classes.
final class SchemaGenerator extends Generator {
  /// Creates a schema generator.
  const SchemaGenerator();

  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final objects = <ClassElement>[];
    final unions = <ClassElement>[];
    for (final annotated in library.annotatedWith(_generateSchemaChecker)) {
      final element = annotated.element;
      if (element is! ClassElement) {
        throw InvalidGenerationSourceError(
          '@GenerateSchema can only be applied to classes.',
          element: element,
        );
      }
      if (element.isSealed) {
        unions.add(element);
        for (final variant in _variantsOf(element)) {
          if (!objects.contains(variant)) {
            objects.add(variant);
          }
        }
      } else if (!objects.contains(element)) {
        objects.add(element);
      }
    }
    if (objects.isEmpty && unions.isEmpty) {
      return null;
    }

    final context = _Context(library.element);
    final buffer = StringBuffer();
    for (final union in unions) {
      _writeUnion(buffer, union, context);
    }
    for (final object in objects) {
      _writeObject(buffer, object, context);
    }
    return buffer.toString();
  }
}

final class _Context {
  _Context(this.library);

  final LibraryElement library;
}

void _writeObject(StringBuffer buffer, ClassElement element, _Context context) {
  final className = _name(element);
  if (element.typeParameters.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'Generic classes are not supported by @GenerateSchema.',
      element: element,
    );
  }
  if (element.isAbstract) {
    throw InvalidGenerationSourceError(
      'Abstract classes cannot be decoded. Mark the class `sealed` to '
      'generate a discriminated union over its subclasses.',
      element: element,
    );
  }

  final annotation = _readAnnotation(_generateSchemaChecker, element);
  final schemaName = annotation?.peek('name')?.stringValue ?? className;
  final description =
      annotation?.peek('description')?.stringValue ??
      _docText(element.documentationComment);

  final constructor = element.unnamedConstructor;
  if (constructor == null || constructor.isPrivate) {
    throw InvalidGenerationSourceError(
      '$className needs a public unnamed constructor for @GenerateSchema.',
      element: element,
    );
  }

  final fields = [
    for (final parameter in constructor.formalParameters)
      _resolveField(element, parameter, context),
  ];
  final seenKeys = <String>{};
  for (final field in fields) {
    if (!seenKeys.add(field.key)) {
      throw InvalidGenerationSourceError(
        '$className declares the JSON key "${field.key}" more than once.',
        element: field.parameter,
      );
    }
  }
  if (_unionOf(element) case final union?) {
    final discriminatorKey = _discriminatorKey(union);
    if (seenKeys.contains(discriminatorKey)) {
      throw InvalidGenerationSourceError(
        '$className cannot declare "$discriminatorKey"; it is the '
        'discriminator of ${_name(union)}.',
        element: element,
      );
    }
  }

  buffer
    ..writeln('const _\$${className}Schema = ObjectSchema(')
    ..writeln('  name: ${_literal(schemaName)},');
  if (description != null) {
    buffer.writeln('  description: ${_literal(description)},');
  }
  buffer.writeln('  fields: {');
  for (final field in fields) {
    buffer.writeln('    ${_literal(field.key)}: ${field.schemaExpression},');
  }
  buffer
    ..writeln('  },')
    ..writeln(');')
    ..writeln()
    ..writeln(
      '$className _\$${className}FromJson(Map<String, Object?> json) =>',
    )
    ..writeln('    $className(');
  for (final field in fields) {
    final value = field.decodeExpression;
    if (field.parameter.isNamed) {
      buffer.writeln('      ${field.parameter.name}: $value,');
    } else {
      buffer.writeln('      $value,');
    }
  }
  buffer
    ..writeln('    );')
    ..writeln();
}

void _writeUnion(StringBuffer buffer, ClassElement element, _Context context) {
  final className = _name(element);
  final variants = _variantsOf(element);
  if (variants.isEmpty) {
    throw InvalidGenerationSourceError(
      '$className has no concrete subclasses in this library.',
      element: element,
    );
  }
  final discriminatorKey = _discriminatorKey(element);
  final values = <String, ClassElement>{};
  for (final variant in variants) {
    final value = _variantValue(variant);
    if (value.isEmpty) {
      throw InvalidGenerationSourceError(
        'Discriminator values must not be empty.',
        element: variant,
      );
    }
    if (values.containsKey(value)) {
      throw InvalidGenerationSourceError(
        '${_name(variant)} and ${_name(values[value]!)} share the '
        'discriminator value "$value".',
        element: variant,
      );
    }
    values[value] = variant;
  }

  buffer.writeln('const _\$${className}Variants = <String, ObjectSchema>{');
  for (final entry in values.entries) {
    buffer.writeln(
      '  ${_literal(entry.key)}: _\$${_name(entry.value)}Schema,',
    );
  }
  buffer
    ..writeln('};')
    ..writeln()
    ..writeln(
      '$className _\$${className}FromJson(Map<String, Object?> json) =>',
    )
    ..writeln('    switch (json[${_literal(discriminatorKey)}]) {');
  for (final entry in values.entries) {
    buffer.writeln(
      '      ${_literal(entry.key)} => '
      '_\$${_name(entry.value)}FromJson(json),',
    );
  }
  buffer
    ..writeln('      final value => throw DecodeException(')
    ..writeln(
      "        'Unknown ${_escape(className)} discriminator: \$value.',",
    )
    ..writeln('        source: json,')
    ..writeln('      ),')
    ..writeln('    };')
    ..writeln();
}

final class _Field {
  const _Field({
    required this.parameter,
    required this.key,
    required this.schemaExpression,
    required this.decodeExpression,
  });

  final FormalParameterElement parameter;
  final String key;
  final String schemaExpression;
  final String decodeExpression;
}

_Field _resolveField(
  ClassElement owner,
  FormalParameterElement parameter,
  _Context context,
) {
  final parameterName = parameter.name!;
  final field = _findField(owner, parameterName);
  final annotation =
      _readAnnotation(_schemaFieldChecker, parameter) ??
      (field == null ? null : _readAnnotation(_schemaFieldChecker, field));
  final key = annotation?.peek('name')?.stringValue ?? parameterName;
  final description =
      annotation?.peek('description')?.stringValue ??
      _docText(field?.documentationComment);

  final type = parameter.type;
  final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
  final defaultValue = parameter.hasDefaultValue
      ? parameter.defaultValueCode
      : null;
  final isRequired = !isNullable && defaultValue == null;

  final isArray = type.isDartCoreList;
  final valueType = isArray
      ? (type as InterfaceType).typeArguments.single
      : type;
  if (isArray && valueType.nullabilitySuffix == NullabilitySuffix.question) {
    throw InvalidGenerationSourceError(
      'List elements must not be nullable.',
      element: parameter,
    );
  }

  final shape = _shapeOf(valueType, parameter, owner, context);
  final constraints = _Constraints.read(annotation)
    ..check(shape, isArray: isArray, element: parameter);

  final arguments = <String>[
    ...shape.schemaArguments,
    if (!isRequired) 'isRequired: false',
    if (isArray) 'isArray: true',
    if (description != null) 'description: ${_literal(description)}',
    ...constraints.arguments,
  ];
  final schemaExpression = arguments.isEmpty
      ? '${shape.constructor}()'
      : '${shape.constructor}(${arguments.join(', ')})';

  final read = 'json[${_literal(key)}]';
  String decodeValue(String value) => isArray
      ? '[for (final item in $value as List) ${shape.decode('item')}]'
      : shape.decode(value);
  final String decodeExpression;
  if (isRequired) {
    decodeExpression = decodeValue('$read!');
  } else {
    decodeExpression =
        'switch ($read) {\n'
        '        null => ${defaultValue ?? 'null'},\n'
        '        final value => ${decodeValue('value')},\n'
        '      }';
  }

  return _Field(
    parameter: parameter,
    key: key,
    schemaExpression: schemaExpression,
    decodeExpression: decodeExpression,
  );
}

enum _ShapeKind { string, integer, number, boolean, object, union }

final class _Shape {
  const _Shape({
    required this.kind,
    required this.constructor,
    required this.decode,
    this.schemaArguments = const [],
  });

  final _ShapeKind kind;
  final String constructor;
  final List<String> schemaArguments;
  final String Function(String value) decode;
}

_Shape _shapeOf(
  DartType type,
  FormalParameterElement parameter,
  ClassElement owner,
  _Context context,
) {
  if (type.isDartCoreString) {
    return _Shape(
      kind: _ShapeKind.string,
      constructor: 'ObjectField.string',
      decode: (value) => '$value as String',
    );
  }
  if (type.isDartCoreInt) {
    return _Shape(
      kind: _ShapeKind.integer,
      constructor: 'ObjectField.integer',
      decode: (value) => '$value as int',
    );
  }
  if (type.isDartCoreDouble) {
    return _Shape(
      kind: _ShapeKind.number,
      constructor: 'ObjectField.number',
      decode: (value) => '($value as num).toDouble()',
    );
  }
  if (type.isDartCoreNum) {
    return _Shape(
      kind: _ShapeKind.number,
      constructor: 'ObjectField.number',
      decode: (value) => '$value as num',
    );
  }
  if (type.isDartCoreBool) {
    return _Shape(
      kind: _ShapeKind.boolean,
      constructor: 'ObjectField.boolean',
      decode: (value) => '$value as bool',
    );
  }

  final element = type is InterfaceType ? type.element : null;
  if (element is EnumElement) {
    final enumName = _name(element);
    final values = [
      for (final constant in element.fields)
        if (constant.isEnumConstant) _literal(constant.name!),
    ];
    return _Shape(
      kind: _ShapeKind.string,
      constructor: 'ObjectField.string',
      schemaArguments: ['enumValues: [${values.join(', ')}]'],
      decode: (value) => '$enumName.values.byName($value as String)',
    );
  }

  if (element is ClassElement &&
      _readAnnotation(_generateSchemaChecker, element) != null) {
    if (element == owner) {
      throw InvalidGenerationSourceError(
        'Recursive schemas are not supported: ${_name(owner)} refers to '
        'itself.',
        element: parameter,
      );
    }
    final local = element.library == context.library;
    final typeName = _name(element);
    final fromJson = local ? '_\$${typeName}FromJson' : '$typeName.fromJson';
    String decode(String value) =>
        '$fromJson(($value as Map).cast<String, Object?>())';
    if (!local) {
      _checkExposed(element, parameter);
    }
    if (element.isSealed) {
      final variants = local ? '_\$${typeName}Variants' : '$typeName.variants';
      return _Shape(
        kind: _ShapeKind.union,
        constructor: 'ObjectField.discriminatedUnion',
        schemaArguments: [
          'discriminatorKey: ${_literal(_discriminatorKey(element))}',
          'variants: $variants',
        ],
        decode: decode,
      );
    }
    final schema = local ? '_\$${typeName}Schema' : '$typeName.schema';
    return _Shape(
      kind: _ShapeKind.object,
      constructor: 'ObjectField.object',
      schemaArguments: ['schema: $schema'],
      decode: decode,
    );
  }

  throw InvalidGenerationSourceError(
    'Unsupported type ${type.getDisplayString()} for '
    '"${parameter.name}". Use String, int, double, num, bool, an enum, a '
    'class annotated with @GenerateSchema, or a List of one of those.',
    element: parameter,
  );
}

void _checkExposed(ClassElement element, FormalParameterElement parameter) {
  final typeName = _name(element);
  final member = element.isSealed ? 'variants' : 'schema';
  final hasMember = element.getField(member)?.isStatic ?? false;
  final hasFromJson =
      element.getNamedConstructor('fromJson') != null ||
      (element.getMethod('fromJson')?.isStatic ?? false);
  if (!hasMember || !hasFromJson) {
    throw InvalidGenerationSourceError(
      '$typeName is declared in another library, so it must expose its '
      'generated members: `static const $member = '
      '_\$$typeName${element.isSealed ? 'Variants' : 'Schema'};` and '
      '`factory $typeName.fromJson(Map<String, Object?> json) => '
      '_\$${typeName}FromJson(json);`.',
      element: parameter,
    );
  }
}

final class _Constraints {
  const _Constraints({
    this.minimum,
    this.maximum,
    this.pattern,
    this.minItems,
    this.maxItems,
  });

  factory _Constraints.read(ConstantReader? annotation) {
    if (annotation == null) {
      return const _Constraints();
    }
    return _Constraints(
      minimum: _numLiteral(annotation.peek('minimum')),
      maximum: _numLiteral(annotation.peek('maximum')),
      pattern: annotation.peek('pattern')?.stringValue,
      minItems: annotation.peek('minItems')?.intValue,
      maxItems: annotation.peek('maxItems')?.intValue,
    );
  }

  final String? minimum;
  final String? maximum;
  final String? pattern;
  final int? minItems;
  final int? maxItems;

  void check(_Shape shape, {required bool isArray, required Element element}) {
    final numeric =
        shape.kind == _ShapeKind.integer || shape.kind == _ShapeKind.number;
    if ((minimum != null || maximum != null) && !numeric) {
      throw InvalidGenerationSourceError(
        'minimum and maximum only apply to int, double and num fields.',
        element: element,
      );
    }
    if (pattern != null && shape.kind != _ShapeKind.string) {
      throw InvalidGenerationSourceError(
        'pattern only applies to String fields.',
        element: element,
      );
    }
    if (pattern != null && shape.schemaArguments.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'pattern does not apply to enum fields.',
        element: element,
      );
    }
    if ((minItems != null || maxItems != null) && !isArray) {
      throw InvalidGenerationSourceError(
        'minItems and maxItems only apply to List fields.',
        element: element,
      );
    }
  }

  List<String> get arguments => [
    if (minimum != null) 'minimum: $minimum',
    if (maximum != null) 'maximum: $maximum',
    if (pattern != null) 'pattern: ${_literal(pattern!)}',
    if (minItems != null) 'minItems: $minItems',
    if (maxItems != null) 'maxItems: $maxItems',
  ];
}

String? _numLiteral(ConstantReader? reader) {
  if (reader == null) {
    return null;
  }
  if (reader.isInt) {
    return '${reader.intValue}';
  }
  return '${reader.doubleValue}';
}

FieldElement? _findField(ClassElement owner, String name) {
  if (owner.getField(name) case final field?) {
    return field;
  }
  for (final supertype in owner.allSupertypes) {
    if (supertype.element.getField(name) case final field?) {
      return field;
    }
  }
  return null;
}

ConstantReader? _readAnnotation(TypeChecker checker, Element element) {
  final value = checker.firstAnnotationOfExact(element);
  return value == null ? null : ConstantReader(value);
}

List<ClassElement> _variantsOf(ClassElement union) {
  return [
    for (final candidate in union.library.classes)
      if (!candidate.isAbstract &&
          !candidate.isSealed &&
          candidate.supertype?.element == union)
        candidate,
  ];
}

ClassElement? _unionOf(ClassElement element) {
  final superElement = element.supertype?.element;
  if (superElement is ClassElement &&
      superElement.isSealed &&
      _readAnnotation(_generateSchemaChecker, superElement) != null) {
    return superElement;
  }
  return null;
}

String _discriminatorKey(ClassElement union) {
  return _readAnnotation(
        _generateSchemaChecker,
        union,
      )?.peek('discriminatorKey')?.stringValue ??
      'type';
}

String _variantValue(ClassElement variant) {
  if (_readAnnotation(_schemaVariantChecker, variant) case final reader?) {
    return reader.read('value').stringValue;
  }
  final name = _name(variant).replaceFirst(RegExp('^_+'), '');
  return '${name[0].toLowerCase()}${name.substring(1)}';
}

String _name(Element element) => element.name!;

/// Turns a `///` or `/** */` doc comment into plain text: wrapped lines are
/// joined with spaces and blank lines keep paragraphs apart.
String? _docText(String? comment) {
  if (comment == null) {
    return null;
  }
  final lines = comment
      .split('\n')
      .map(
        (line) => line
            .trim()
            .replaceFirst(RegExp(r'^/\*\*'), '')
            .replaceFirst(RegExp(r'\*/$'), '')
            .replaceFirst(RegExp('^///?'), '')
            .replaceFirst(RegExp(r'^\*(?!/)'), '')
            .trim(),
      )
      .toList();
  final paragraphs = <String>[];
  final current = <String>[];
  for (final line in lines) {
    if (line.isEmpty) {
      if (current.isNotEmpty) {
        paragraphs.add(current.join(' '));
        current.clear();
      }
    } else {
      current.add(line);
    }
  }
  if (current.isNotEmpty) {
    paragraphs.add(current.join(' '));
  }
  final text = paragraphs.join('\n\n');
  return text.isEmpty ? null : text;
}

String _literal(String value) => "'${_escape(value)}'";

String _escape(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');
