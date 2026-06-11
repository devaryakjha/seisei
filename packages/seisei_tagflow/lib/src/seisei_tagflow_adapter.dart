import 'package:seisei_ui/seisei_ui.dart';
import 'package:tagflow/tagflow.dart';

/// Fails when a Seisei block tree cannot be mapped to Tagflow safely.
final class SeiseiTagflowRenderException implements Exception {
  /// Creates a new render exception.
  const SeiseiTagflowRenderException(this.issues);

  /// Stable validation issues collected before render.
  final List<String> issues;

  @override
  String toString() {
    return 'SeiseiTagflowRenderException(${issues.join(', ')})';
  }
}

/// Optional adapter from `seisei_ui` blocks into Tagflow documents.
final class SeiseiTagflowAdapter
    implements SeiseiBlockAdapter<TagflowDocument> {
  /// Creates a Tagflow adapter.
  const SeiseiTagflowAdapter();

  /// Context metadata key for overriding the rendered document ID.
  static const String documentIdMetadataKey = 'tagflowDocumentId';

  /// Experimental schema for the current supported block vocabulary.
  static const SeiseiBlockSchema schema = SeiseiBlockSchema(
    blockTypes: {
      'root',
      'document',
      'container',
      'paragraph',
      'heading',
      'text',
      'link',
      'list',
      'listItem',
      'blockquote',
      'codeBlock',
      'inlineCode',
      'image',
      'horizontalRule',
    },
    requiredPropsByType: {
      'text': {'value'},
      'link': {'url'},
      'codeBlock': {'value'},
      'inlineCode': {'value'},
      'image': {'url'},
    },
    allowedChildTypesByType: {
      'root': _blockChildren,
      'document': _blockChildren,
      'container': _blockChildren,
      'paragraph': _inlineChildren,
      'heading': _inlineChildren,
      'link': _inlineChildren,
      'list': {'listItem'},
      'listItem': _listItemChildren,
      'blockquote': _blockChildren,
      'codeBlock': {},
      'inlineCode': {},
      'text': {},
      'image': {},
      'horizontalRule': {},
    },
  );

  static const Set<String> _blockChildren = {
    'container',
    'paragraph',
    'heading',
    'text',
    'link',
    'list',
    'blockquote',
    'codeBlock',
    'inlineCode',
    'image',
    'horizontalRule',
  };

  static const Set<String> _inlineChildren = {
    'text',
    'link',
    'inlineCode',
    'image',
  };

  static const Set<String> _listItemChildren = {
    'container',
    'paragraph',
    'heading',
    'text',
    'link',
    'list',
    'blockquote',
    'codeBlock',
    'inlineCode',
    'image',
    'horizontalRule',
  };

  @override
  String get id => 'tagflow';

  @override
  SeiseiBlockAdapterCapabilities get capabilities {
    return const SeiseiBlockAdapterCapabilities(
      blockTypes: {
        'root',
        'document',
        'container',
        'paragraph',
        'heading',
        'text',
        'link',
        'list',
        'listItem',
        'blockquote',
        'codeBlock',
        'inlineCode',
        'image',
        'horizontalRule',
      },
      actionTypes: {},
      supportsStreamingUpdates: false,
      layoutPrimitives: {'container'},
      supportsMedia: true,
      supportsForms: false,
    );
  }

  @override
  bool supports(SeiseiBlockSchema schema) {
    return capabilities.supports(schema);
  }

  @override
  TagflowDocument render(SeiseiBlock block, SeiseiBlockRenderContext context) {
    final issues = _collectIssues(block);
    if (issues.isNotEmpty) {
      throw SeiseiTagflowRenderException(List.unmodifiable(issues));
    }

    final document = TagflowDocument(
      id: _documentId(block, context),
      children: switch (block.type) {
        'root' || 'document' => [
          for (final child in block.children) _nodeFromBlock(child),
        ],
        _ => [_nodeFromBlock(block)],
      },
    );
    return document;
  }

  List<String> _collectIssues(SeiseiBlock block) {
    final issues = <String>[
      for (final error in schema.validate(block)) '${error.code}@${error.path}',
    ];
    final seenIds = <String>{};
    _collectBlockIssues(block, seenIds, issues, r'$');
    return issues;
  }

  void _collectBlockIssues(
    SeiseiBlock block,
    Set<String> seenIds,
    List<String> issues,
    String path,
  ) {
    if (!seenIds.add(block.id)) {
      issues.add('block.duplicate_id@$path');
    }

    switch (block.type) {
      case 'heading':
        _requireInt(
          block,
          path: path,
          prop: 'level',
          issues: issues,
          min: 1,
          max: 6,
          isRequired: false,
        );
        break;
      case 'text':
      case 'codeBlock':
      case 'inlineCode':
        _requireString(
          block,
          path: path,
          prop: 'value',
          issues: issues,
          isRequired: false,
        );
        if (block.type == 'codeBlock') {
          _requireString(
            block,
            path: path,
            prop: 'language',
            issues: issues,
            isRequired: false,
          );
        }
        break;
      case 'link':
        _requireUriString(
          block,
          path: path,
          prop: 'url',
          issues: issues,
          isRequired: false,
        );
        break;
      case 'list':
        _requireBool(
          block,
          path: path,
          prop: 'ordered',
          issues: issues,
          isRequired: false,
        );
        _requireInt(
          block,
          path: path,
          prop: 'startIndex',
          issues: issues,
          min: 1,
          isRequired: false,
        );
        break;
      case 'image':
        _requireUriString(
          block,
          path: path,
          prop: 'url',
          issues: issues,
          isRequired: false,
        );
        _requireString(
          block,
          path: path,
          prop: 'alt',
          issues: issues,
          isRequired: false,
        );
        _requireNumber(
          block,
          path: path,
          prop: 'width',
          issues: issues,
          isRequired: false,
        );
        _requireNumber(
          block,
          path: path,
          prop: 'height',
          issues: issues,
          isRequired: false,
        );
        break;
      case 'root':
      case 'document':
      case 'container':
      case 'paragraph':
      case 'listItem':
      case 'blockquote':
      case 'horizontalRule':
        break;
    }

    for (var i = 0; i < block.children.length; i += 1) {
      _collectBlockIssues(
        block.children[i],
        seenIds,
        issues,
        '$path.children[$i]',
      );
    }
  }

  TagflowDocumentNode _nodeFromBlock(SeiseiBlock block) {
    return switch (block.type) {
      'container' => TagflowDocumentNode.container(
        id: block.id,
        children: _childrenFrom(block),
      ),
      'paragraph' => TagflowDocumentNode.paragraph(
        id: block.id,
        children: _childrenFrom(block),
      ),
      'heading' => TagflowDocumentNode.heading(
        id: block.id,
        level: (block.props['level'] as int?) ?? 1,
        children: _childrenFrom(block),
      ),
      'text' => TagflowDocumentNode.text(
        id: block.id,
        text: block.props['value']! as String,
      ),
      'link' => TagflowDocumentNode.link(
        id: block.id,
        url: Uri.parse(block.props['url']! as String),
        children: _childrenFrom(block),
      ),
      'list' => TagflowDocumentNode.list(
        id: block.id,
        ordered: (block.props['ordered'] as bool?) ?? false,
        startIndex: block.props['startIndex'] as int?,
        children: _childrenFrom(block),
      ),
      'listItem' => TagflowDocumentNode.listItem(
        id: block.id,
        children: _childrenFrom(block),
      ),
      'blockquote' => TagflowDocumentNode.blockquote(
        id: block.id,
        children: _childrenFrom(block),
      ),
      'codeBlock' => TagflowDocumentNode.codeBlock(
        id: block.id,
        text: block.props['value']! as String,
        language: block.props['language'] as String?,
      ),
      'inlineCode' => TagflowDocumentNode.inlineCode(
        id: block.id,
        text: block.props['value']! as String,
      ),
      'image' => TagflowDocumentNode.image(
        id: block.id,
        url: Uri.parse(block.props['url']! as String),
        alt: block.props['alt'] as String?,
        width: _toDouble(block.props['width']),
        height: _toDouble(block.props['height']),
      ),
      'horizontalRule' => TagflowDocumentNode.horizontalRule(id: block.id),
      'root' || 'document' => TagflowDocumentNode.container(
        id: block.id,
        children: _childrenFrom(block),
      ),
      _ => throw SeiseiTagflowRenderException([
        'block.unsupported_type@${block.id}',
      ]),
    };
  }

  List<TagflowDocumentNode> _childrenFrom(SeiseiBlock block) {
    return [for (final child in block.children) _nodeFromBlock(child)];
  }

  String _documentId(SeiseiBlock block, SeiseiBlockRenderContext context) {
    final override = context.metadata[documentIdMetadataKey];
    if (override is String && override.isNotEmpty) {
      return override;
    }
    return block.id;
  }

  void _requireString(
    SeiseiBlock block, {
    required String path,
    required String prop,
    required List<String> issues,
    bool isRequired = true,
  }) {
    final value = block.props[prop];
    if (value == null) {
      if (isRequired) {
        issues.add('prop.required@$path.props.$prop');
      }
      return;
    }
    if (value is! String) {
      issues.add('prop.invalid_type@$path.props.$prop');
    }
  }

  void _requireUriString(
    SeiseiBlock block, {
    required String path,
    required String prop,
    required List<String> issues,
    bool isRequired = true,
  }) {
    final value = block.props[prop];
    if (value == null) {
      if (isRequired) {
        issues.add('prop.required@$path.props.$prop');
      }
      return;
    }
    if (value is! String) {
      issues.add('prop.invalid_type@$path.props.$prop');
      return;
    }
    if (value.isEmpty || Uri.tryParse(value) == null) {
      issues.add('prop.invalid_uri@$path.props.$prop');
    }
  }

  void _requireNumber(
    SeiseiBlock block, {
    required String path,
    required String prop,
    required List<String> issues,
    bool isRequired = true,
  }) {
    final value = block.props[prop];
    if (value == null) {
      if (isRequired) {
        issues.add('prop.required@$path.props.$prop');
      }
      return;
    }
    if (value is! num) {
      issues.add('prop.invalid_type@$path.props.$prop');
    }
  }

  void _requireBool(
    SeiseiBlock block, {
    required String path,
    required String prop,
    required List<String> issues,
    bool isRequired = true,
  }) {
    final value = block.props[prop];
    if (value == null) {
      if (isRequired) {
        issues.add('prop.required@$path.props.$prop');
      }
      return;
    }
    if (value is! bool) {
      issues.add('prop.invalid_type@$path.props.$prop');
    }
  }

  void _requireInt(
    SeiseiBlock block, {
    required String path,
    required String prop,
    required List<String> issues,
    int? min,
    int? max,
    bool isRequired = true,
  }) {
    final value = block.props[prop];
    if (value == null) {
      if (isRequired) {
        issues.add('prop.required@$path.props.$prop');
      }
      return;
    }
    if (value is! int) {
      issues.add('prop.invalid_type@$path.props.$prop');
      return;
    }
    if ((min != null && value < min) || (max != null && value > max)) {
      issues.add('prop.out_of_range@$path.props.$prop');
    }
  }

  double? _toDouble(Object? value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return null;
  }
}
