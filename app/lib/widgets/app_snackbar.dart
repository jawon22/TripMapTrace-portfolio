import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.destructive,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
