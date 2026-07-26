import 'package:flutter/material.dart';

/// Soft thin status borders for meter cards (no heavy fills).
abstract final class MeterCardChrome {
  /// Incomplete / pending — soft warm grey.
  static const emptyBorder = Color(0xFFC9BBA0);

  /// Value + photo ready to save — soft gold.
  static const readyBorder = Color(0xFFD4B84A);

  /// Entered / saved — soft light green.
  static const savedBorder = Color(0xFF8FCB9B);

  /// Needs review — soft coral.
  static const reviewBorder = Color(0xFFE0A88A);

  /// Locally saved but not synced — soft teal.
  static const localBorder = Color(0xFF8BB8C9);

  static Color borderFor({
    required bool hasValue,
    required bool hasPhoto,
    required bool isSaved,
    required bool needsReview,
    required bool savedLocally,
  }) {
    if (needsReview) return reviewBorder;
    if (isSaved) return savedBorder;
    if (savedLocally) return localBorder;
    if (hasValue && hasPhoto) return readyBorder;
    if (hasValue) return readyBorder.withValues(alpha: 0.75);
    return emptyBorder;
  }
}
