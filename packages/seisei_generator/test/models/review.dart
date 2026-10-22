import 'package:seisei/seisei.dart';

import 'draft.dart';

part 'review.g.dart';

/// A review that refers to schemas declared in another library.
@GenerateSchema()
class Review {
  const Review(this.reviewer, {required this.verdict, this.note});

  factory Review.fromJson(Map<String, Object?> json) => _$ReviewFromJson(json);

  static const ObjectSchema schema = _$ReviewSchema;

  final Author reviewer;

  final Status verdict;

  final Message? note;
}
