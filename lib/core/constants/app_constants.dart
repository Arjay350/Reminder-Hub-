import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Reminder Hub';
  static const String appVersion = '1.4.0';

  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color primaryLightColor = Color(0xFF818CF8);
  static const Color primaryDarkColor = Color(0xFF3730A3);

  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentPurple = Color(0xFF8B5CF6);

  static const Color surfaceColor = Color(0xFF1E1E2E);
  static const Color backgroundColor = Color(0xFF0F0F1A);
  static const Color cardColor = Color(0xFF1A1A2E);

  static const double borderRadius = 24.0;
  static const double borderRadiusSmall = 16.0;
  static const double spacing = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration animationDurationFast = Duration(milliseconds: 200);

  static const String hiveBoxReminders = 'reminders';
  static const String hiveBoxAIAccounts = 'ai_accounts';
  static const String hiveBoxUserAccounts = 'user_accounts';
  static const String hiveBoxBills = 'bills';
  static const String hiveBoxGasPurchases = 'gas_purchases';
  static const String hiveBoxSuppliers = 'suppliers';
  static const String hiveBoxSettings = 'settings';

  static const int notificationIdBase = 1000;
  static const String notificationChannelId = 'reminderhub_channel';
  static const String notificationChannelName = 'Reminder Hub Notifications';
  static const String notificationChannelDescription =
      'Notifications for reminders, bills, and gas refills';

  static const List<String> reminderCategories = [
    'Bills',
    'AI Reset',
    'Subscriptions',
    'Gaming',
    'Work',
    'School',
    'Personal',
    'Household',
    'Custom',
  ];

  static const List<String> accountCategories = [
    'Websites',
    'Apps',
    'Gaming',
    'Finance',
    'Email',
    'Work',
    'School',
    'AI',
    'Shopping',
    'Custom',
  ];

  static const List<String> aiServices = [
    'ChatGPT',
    'Claude',
    'Gemini',
    'Grok',
    'Cursor',
    'GitHub Copilot',
    'Perplexity',
    'DeepSeek',
    'Custom',
  ];

  static const List<String> repeatOptions = [
    'None',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'Custom',
  ];

  static const List<String> reminderBeforeOptions = [
    'At time',
    '10 minutes',
    '30 minutes',
    '1 hour',
    '1 day',
    'Custom',
  ];

  static const List<String> priorityOptions = ['Low', 'Medium', 'High'];

  static const List<String> billStatusOptions = ['Upcoming', 'Paid', 'Overdue'];
}

class CategoryConfig {
  final String name;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const CategoryConfig({
    required this.name,
    required this.icon,
    required this.color,
    required this.lightColor,
  });

  static const Map<String, CategoryConfig> reminderCategories = {
    'Bills': CategoryConfig(
      name: 'Bills',
      icon: Icons.receipt_long,
      color: AppConstants.accentOrange,
      lightColor: Color(0xFFFFEDD5),
    ),
    'AI Reset': CategoryConfig(
      name: 'AI Reset',
      icon: Icons.smart_toy,
      color: AppConstants.accentPurple,
      lightColor: Color(0xFFF3E8FF),
    ),
    'Subscriptions': CategoryConfig(
      name: 'Subscriptions',
      icon: Icons.subscriptions,
      color: AppConstants.primaryColor,
      lightColor: Color(0xFFE0E7FF),
    ),
    'Gaming': CategoryConfig(
      name: 'Gaming',
      icon: Icons.videogame_asset,
      color: Color(0xFFEC4899),
      lightColor: Color(0xFFFCE7F3),
    ),
    'Work': CategoryConfig(
      name: 'Work',
      icon: Icons.work,
      color: Color(0xFF06B6D4),
      lightColor: Color(0xFFCFFAFE),
    ),
    'School': CategoryConfig(
      name: 'School',
      icon: Icons.school,
      color: Color(0xFF84CC16),
      lightColor: Color(0xFFF7FEE7),
    ),
    'Personal': CategoryConfig(
      name: 'Personal',
      icon: Icons.favorite,
      color: AppConstants.accentRed,
      lightColor: Color(0xFFFEF2F2),
    ),
    'Household': CategoryConfig(
      name: 'Household',
      icon: Icons.home,
      color: Color(0xFFF97316),
      lightColor: Color(0xFFFFF7ED),
    ),
    'Custom': CategoryConfig(
      name: 'Custom',
      icon: Icons.label,
      color: Color(0xFF64748B),
      lightColor: Color(0xFFF1F5F9),
    ),
  };

  static const Map<String, CategoryConfig> accountCategories = {
    'Websites': CategoryConfig(
      name: 'Websites',
      icon: Icons.language,
      color: AppConstants.primaryColor,
      lightColor: Color(0xFFE0E7FF),
    ),
    'Apps': CategoryConfig(
      name: 'Apps',
      icon: Icons.apps,
      color: AppConstants.accentGreen,
      lightColor: Color(0xFFDCFCE7),
    ),
    'Gaming': CategoryConfig(
      name: 'Gaming',
      icon: Icons.videogame_asset,
      color: Color(0xFFEC4899),
      lightColor: Color(0xFFFCE7F3),
    ),
    'Finance': CategoryConfig(
      name: 'Finance',
      icon: Icons.account_balance_wallet,
      color: AppConstants.accentOrange,
      lightColor: Color(0xFFFFEDD5),
    ),
    'Email': CategoryConfig(
      name: 'Email',
      icon: Icons.email,
      color: Color(0xFF06B6D4),
      lightColor: Color(0xFFCFFAFE),
    ),
    'Work': CategoryConfig(
      name: 'Work',
      icon: Icons.work,
      color: Color(0xFF84CC16),
      lightColor: Color(0xFFF7FEE7),
    ),
    'School': CategoryConfig(
      name: 'School',
      icon: Icons.school,
      color: AppConstants.accentPurple,
      lightColor: Color(0xFFF3E8FF),
    ),
    'AI': CategoryConfig(
      name: 'AI',
      icon: Icons.smart_toy,
      color: Color(0xFFEC4899),
      lightColor: Color(0xFFFCE7F3),
    ),
    'Shopping': CategoryConfig(
      name: 'Shopping',
      icon: Icons.shopping_cart,
      color: Color(0xFFF97316),
      lightColor: Color(0xFFFFF7ED),
    ),
    'Custom': CategoryConfig(
      name: 'Custom',
      icon: Icons.label,
      color: Color(0xFF64748B),
      lightColor: Color(0xFFF1F5F9),
    ),
  };

  static const Map<String, IconData> aiServiceIcons = {
    'ChatGPT': Icons.chat,
    'Claude': Icons.psychology,
    'Gemini': Icons.auto_awesome,
    'Grok': Icons.explore,
    'Cursor': Icons.code,
    'GitHub Copilot': Icons.code_off,
    'Perplexity': Icons.search,
    'DeepSeek': Icons.smart_toy,
    'Custom': Icons.star,
  };
}
