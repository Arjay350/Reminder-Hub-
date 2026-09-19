import '../models/app_models.dart';

class GasCalculationService {
  /// Counts calendar days from the purchase date through the reference date.
  /// A future-dated purchase has not started yet and returns zero.
  static int calculateActiveTankDays(
    DateTime purchaseDate, {
    DateTime? referenceDate,
  }) {
    final purchaseDay = DateTime(
      purchaseDate.year,
      purchaseDate.month,
      purchaseDate.day,
    );
    final currentDay = referenceDate ?? DateTime.now();
    final today = DateTime(currentDay.year, currentDay.month, currentDay.day);
    final difference = today.difference(purchaseDay).inDays;
    return difference < 0 ? 0 : difference + 1;
  }

  /// Calculate completed tank durations between consecutive LPG orders.
  /// The replacement order day is excluded because the previous tank was
  /// already replaced that day (e.g. Jan 1 -> Jan 31 = 30 days).
  /// Expects purchases list to be ordered by purchaseDate descending (latest first).
  static int calculateCompletedTankDuration(
    DateTime previousOrderDate,
    DateTime replacementOrderDate,
  ) {
    final previousDay = DateTime(
      previousOrderDate.year,
      previousOrderDate.month,
      previousOrderDate.day,
    );
    final replacementDay = DateTime(
      replacementOrderDate.year,
      replacementOrderDate.month,
      replacementOrderDate.day,
    );
    final duration = replacementDay.difference(previousDay).inDays;
    return duration < 0 ? 0 : duration;
  }

  static List<int> getTankDurations(List<GasPurchase> purchases) {
    if (purchases.length < 2) return [];
    final List<int> durations = [];
    for (int i = 0; i < purchases.length - 1; i++) {
      final days = calculateCompletedTankDuration(
        purchases[i + 1].purchaseDate,
        purchases[i].purchaseDate,
      );
      if (days > 0) {
        durations.add(days);
      }
    }
    return durations;
  }

  /// Calculates average duration (in days) that a cooking LPG tank lasted in the household.
  static int calculateAverageDuration(List<GasPurchase> purchases) {
    final durations = getTankDurations(purchases);
    if (durations.isEmpty) return 0;
    final total = durations.reduce((a, b) => a + b);
    return (total / durations.length).round();
  }

  /// Calculates longest tank duration in days.
  static int calculateLongestDuration(List<GasPurchase> purchases) {
    final durations = getTankDurations(purchases);
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a > b ? a : b);
  }

  /// Calculates shortest tank duration in days.
  static int calculateShortestDuration(List<GasPurchase> purchases) {
    final durations = getTankDurations(purchases);
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a < b ? a : b);
  }

  /// Calculates average days between orders.
  static double calculateAverageDaysBetween(List<GasPurchase> purchases) {
    final durations = getTankDurations(purchases);
    if (durations.isEmpty) return 0.0;
    final total = durations.reduce((a, b) => a + b);
    return total / durations.length;
  }

  /// Total money spent on cooking LPG tanks.
  static double calculateTotalSpent(List<GasPurchase> purchases) {
    return purchases.fold(0.0, (sum, item) => sum + item.amountPaid);
  }

  /// Formats days into human readable duration text, e.g. "54 days (approx. 1 mo 24 days)".
  static String formatDurationText(int days) {
    if (days <= 0) return '0 days';
    if (days < 30) return '$days days';
    final months = days ~/ 30;
    final remainingDays = days % 30;
    if (remainingDays == 0) {
      return '$days days (~$months ${months == 1 ? 'month' : 'months'})';
    }
    return '$days days (~$months ${months == 1 ? 'month' : 'months'}, $remainingDays ${remainingDays == 1 ? 'day' : 'days'})';
  }
}
