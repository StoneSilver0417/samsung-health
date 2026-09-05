export '../core/theme/app_design_tokens.dart';
export '../core/theme/app_theme.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Legacy aliases for backward compatibility
const TextStyle kMetricStyle = AppTypography.heroMetric;
const TextStyle kMetricLabelStyle = AppTypography.metricLabel;

/// Legacy theme builder function
ThemeData buildTheme() => buildAppTheme();
