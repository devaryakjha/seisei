import 'dart:convert';

/// How many trailing characters [parsePartialJson] may drop while looking for
/// a parseable prefix. Keeps snapshot parsing cheap on every stream event.
const _maxBackoff = 64;

/// Parses the longest usable prefix of a JSON object or array that is still
/// streaming in.
///
/// Open strings, objects, and arrays are closed; a trailing key, comma, or
/// partial literal is dropped. Returns null when [text] does not start a JSON
/// object or array, or no prefix parses within the backoff budget.
Object? parsePartialJson(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return null;
  }
  final lowest = trimmed.length - _maxBackoff;
  for (var end = trimmed.length; end > 0 && end >= lowest; end -= 1) {
    final closed = _close(trimmed.substring(0, end));
    if (closed == null) {
      continue;
    }
    try {
      return jsonDecode(closed);
    } on FormatException {
      continue;
    }
  }
  return null;
}

/// Closes an open string and every open container in [prefix], or returns
/// null when the prefix ends where no value can follow a closer.
String? _close(String prefix) {
  final closers = <String>[];
  var inString = false;
  var escaped = false;
  for (var index = 0; index < prefix.length; index += 1) {
    final char = prefix[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    switch (char) {
      case '"':
        inString = true;
      case '{':
        closers.add('}');
      case '[':
        closers.add(']');
      case '}' || ']':
        if (closers.isNotEmpty) {
          closers.removeLast();
        }
    }
  }

  if (escaped) {
    return null;
  }
  final buffer = StringBuffer(prefix);
  if (inString) {
    buffer.write('"');
  } else {
    final tail = prefix.trimRight();
    if (tail.endsWith(',') || tail.endsWith(':')) {
      return null;
    }
  }
  closers.reversed.forEach(buffer.write);
  return buffer.toString();
}
