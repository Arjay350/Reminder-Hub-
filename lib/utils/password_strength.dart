import 'package:flutter/material.dart';

enum PasswordStrengthLevel {
  veryWeak,
  weak,
  fair,
  strong,
  veryStrong,
}

class PasswordStrength {
  final PasswordStrengthLevel level;
  final int score;
  final String label;
  final Color color;
  final List<String> criteria;

  PasswordStrength({
    required this.level,
    required this.score,
    required this.label,
    required this.color,
    required this.criteria,
  });

  static PasswordStrength calculate(String password) {
    if (password.isEmpty) {
      return PasswordStrength(
        level: PasswordStrengthLevel.veryWeak,
        score: 0,
        label: '—',
        color: Colors.grey,
        criteria: [],
      );
    }

    int score = 0;
    final List<String> criteria = [];

    // Length checks
    if (password.length >= 8) {
      score += 1;
      criteria.add('At least 8 characters');
    } else {
      criteria.add('Needs 8+ characters');
    }
    if (password.length >= 12) {
      score += 1;
      criteria.add('At least 12 characters');
    }

    // Character variety checks
    if (RegExp(r'[a-z]').hasMatch(password)) {
      score += 1;
      criteria.add('Lowercase letter');
    } else {
      criteria.add('Add lowercase letter');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score += 1;
      criteria.add('Uppercase letter');
    } else {
      criteria.add('Add uppercase letter');
    }

    if (RegExp(r'\d').hasMatch(password)) {
      score += 1;
      criteria.add('Number');
    } else {
      criteria.add('Add number');
    }

    if (RegExp(r'''[!@#$%^&*()_+\-=\[\]{};:'",.<>/?\\|`~]''').hasMatch(password)) {
      score += 1;
      criteria.add('Special character');
    } else {
      criteria.add('Add special character');
    }

    // Additional bonus points
    if (password.length >= 16) score += 1;
    if (RegExp(r'[a-z]').allMatches(password).length >= 3) score += 1;
    if (RegExp(r'[A-Z]').allMatches(password).length >= 2) score += 1;
    if (RegExp(r'\d').allMatches(password).length >= 2) score += 1;
    if (RegExp(r'''[!@#$%^&*()_+\-=\[\]{};:'",.<>/?\\|`~]''').allMatches(password).length >= 2) score += 1;

    // Determine level
    PasswordStrengthLevel level;
    String label;
    Color color;

    if (score <= 2) {
      level = PasswordStrengthLevel.veryWeak;
      label = 'Very Weak';
      color = Colors.red.shade700;
    } else if (score <= 4) {
      level = PasswordStrengthLevel.weak;
      label = 'Weak';
      color = Colors.red.shade400;
    } else if (score <= 6) {
      level = PasswordStrengthLevel.fair;
      label = 'Fair';
      color = Colors.orange.shade600;
    } else if (score <= 8) {
      level = PasswordStrengthLevel.strong;
      label = 'Strong';
      color = Colors.lightGreen.shade600;
    } else {
      level = PasswordStrengthLevel.veryStrong;
      label = 'Very Strong';
      color = Colors.green.shade700;
    }

    return PasswordStrength(
      level: level,
      score: score,
      label: label,
      color: color,
      criteria: criteria,
    );
  }

  static String getStrengthText(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.veryWeak:
        return 'Very Weak';
      case PasswordStrengthLevel.weak:
        return 'Weak';
      case PasswordStrengthLevel.fair:
        return 'Fair';
      case PasswordStrengthLevel.strong:
        return 'Strong';
      case PasswordStrengthLevel.veryStrong:
        return 'Very Strong';
    }
  }

  static Color getStrengthColor(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.veryWeak:
        return Colors.red.shade700;
      case PasswordStrengthLevel.weak:
        return Colors.red.shade400;
      case PasswordStrengthLevel.fair:
        return Colors.orange.shade600;
      case PasswordStrengthLevel.strong:
        return Colors.lightGreen.shade600;
      case PasswordStrengthLevel.veryStrong:
        return Colors.green.shade700;
    }
  }
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showCriteria;
  final double height;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showCriteria = true,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final strength = PasswordStrength.calculate(password);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength Bar
        Container(
          height: height,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _getWidthFactor(strength.level),
            child: Container(
              decoration: BoxDecoration(
                color: strength.color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
        if (showCriteria) ...[
          const SizedBox(height: 8),
          // Label and Criteria
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Strength: ${strength.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: strength.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: strength.criteria.map((criterion) {
              final isMet = !criterion.startsWith('Needs') && !criterion.startsWith('Add');
              return Chip(
                label: Text(
                  criterion,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMet ? Colors.green.shade700 : (theme.brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade700),
                    fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                backgroundColor: isMet ? Colors.green.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
                side: BorderSide(
                  color: isMet ? Colors.green.withValues(alpha: 0.3) : theme.dividerColor,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  double _getWidthFactor(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.veryWeak:
        return 0.15;
      case PasswordStrengthLevel.weak:
        return 0.3;
      case PasswordStrengthLevel.fair:
        return 0.5;
      case PasswordStrengthLevel.strong:
        return 0.75;
      case PasswordStrengthLevel.veryStrong:
        return 1.0;
    }
  }
}

class CompactPasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final double height;

  const CompactPasswordStrengthIndicator({
    super.key,
    required this.password,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final strength = PasswordStrength.calculate(password);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _getWidthFactor(strength.level),
            child: Container(
              decoration: BoxDecoration(
                color: strength.color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strength.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: strength.color,
          ),
        ),
      ],
    );
  }

  double _getWidthFactor(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.veryWeak:
        return 0.15;
      case PasswordStrengthLevel.weak:
        return 0.3;
      case PasswordStrengthLevel.fair:
        return 0.5;
      case PasswordStrengthLevel.strong:
        return 0.75;
      case PasswordStrengthLevel.veryStrong:
        return 1.0;
    }
  }
}