import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_hub/models/app_models.dart';

void main() {
  group('Test 1 — Non-recurring Bill', () {
    test('Non-recurring bill marks paid without advancing due date', () {
      final electricity = Bill(
        id: 'bill-elec-1',
        name: 'Electricity',
        amount: 2500.0,
        dueDate: DateTime(2026, 8, 30),
        repeat: 'None',
        category: 'Utilities',
        paid: false,
        reminderSchedule: '3 days before',
        notes: '',
      );

      expect(electricity.paid, isFalse);
      expect(
        electricity.getStatus(referenceDate: DateTime(2026, 8, 30)),
        'unpaid',
      );
      expect(electricity.isRecurring, isFalse);

      // User marks as paid
      final paidBill = electricity.copyWith(paid: true);
      expect(paidBill.paid, isTrue);
      expect(paidBill.status, 'paid');
      expect(paidBill.statusLabel, 'PAID');
      expect(paidBill.dueDate, DateTime(2026, 8, 30));
      expect(paidBill.paymentHistory, isEmpty);
    });
  });

  group('Test 2 & 3 — Monthly Recurring Bill Lifecycle', () {
    test(
      'Paying monthly bill records payment history and advances to next unpaid month',
      () {
        final internet = Bill(
          id: 'bill-net-1',
          name: 'Internet',
          amount: 1500.0,
          dueDate: DateTime(2026, 8, 30),
          repeat: 'Monthly',
          category: 'Internet',
          paid: false,
          reminderSchedule: '3 days before',
          notes: '',
        );

        expect(internet.isRecurring, isTrue);
        expect(
          internet.getStatus(referenceDate: DateTime(2026, 8, 30)),
          'unpaid',
        );

        // Cycle 1: User pays August 30 occurrence on August 27
        final payment1 = BillPayment(
          occurrenceDate: internet.dueDate,
          paidDate: DateTime(2026, 8, 27),
          amount: internet.amount,
        );
        final nextDueDate1 = internet.getNextOccurrence(internet.dueDate);
        expect(nextDueDate1, DateTime(2026, 9, 30));

        final activeCycle1 = internet.copyWith(
          dueDate: nextDueDate1,
          paid: false,
          paymentHistory: [...internet.paymentHistory, payment1],
        );

        // Verify Cycle 1 State
        expect(activeCycle1.dueDate, DateTime(2026, 9, 30));
        expect(activeCycle1.paid, isFalse); // IMPORTANT: NOT marked as paid
        expect(
          activeCycle1.getStatus(referenceDate: DateTime(2026, 8, 30)),
          'unpaid',
        );
        expect(activeCycle1.paymentHistory.length, 1);
        expect(
          activeCycle1.paymentHistory[0].occurrenceDate,
          DateTime(2026, 8, 30),
        );
        expect(activeCycle1.paymentHistory[0].paidDate, DateTime(2026, 8, 27));
        expect(activeCycle1.paymentHistory[0].amount, 1500.0);

        // Cycle 2: User pays September 30 occurrence on September 29
        final payment2 = BillPayment(
          occurrenceDate: activeCycle1.dueDate,
          paidDate: DateTime(2026, 9, 29),
          amount: activeCycle1.amount,
        );
        final nextDueDate2 = activeCycle1.getNextOccurrence(
          activeCycle1.dueDate,
        );
        expect(nextDueDate2, DateTime(2026, 10, 30));

        final activeCycle2 = activeCycle1.copyWith(
          dueDate: nextDueDate2,
          paid: false,
          paymentHistory: [...activeCycle1.paymentHistory, payment2],
        );

        // Verify Cycle 2 State
        expect(activeCycle2.dueDate, DateTime(2026, 10, 30));
        expect(activeCycle2.paid, isFalse); // Still unpaid for October
        expect(
          activeCycle2.getStatus(referenceDate: DateTime(2026, 9, 30)),
          'unpaid',
        );
        expect(activeCycle2.paymentHistory.length, 2);
        expect(
          activeCycle2.paymentHistory[0].occurrenceDate,
          DateTime(2026, 8, 30),
        );
        expect(
          activeCycle2.paymentHistory[1].occurrenceDate,
          DateTime(2026, 9, 30),
        );
      },
    );
  });

  group('Test 4 — Yearly Recurring Bill Lifecycle', () {
    test('Paying yearly bill advances by 1 year and records history', () {
      final insurance = Bill(
        id: 'bill-ins-1',
        name: 'Insurance',
        amount: 12000.0,
        dueDate: DateTime(2026, 8, 30),
        repeat: 'Yearly',
        category: 'Insurance',
        paid: false,
        reminderSchedule: '1 week before',
        notes: 'Annual car insurance',
      );

      final nextDueDate = insurance.getNextOccurrence(insurance.dueDate);
      expect(nextDueDate, DateTime(2027, 8, 30));

      final payment = BillPayment(
        occurrenceDate: insurance.dueDate,
        paidDate: DateTime(2026, 8, 25),
        amount: insurance.amount,
      );

      final afterPayment = insurance.copyWith(
        dueDate: nextDueDate,
        paid: false,
        paymentHistory: [payment],
      );

      expect(afterPayment.dueDate, DateTime(2027, 8, 30));
      expect(afterPayment.paid, isFalse);
      expect(afterPayment.paymentHistory.length, 1);
      expect(
        afterPayment.paymentHistory.first.occurrenceDate,
        DateTime(2026, 8, 30),
      );
    });
  });

  group('Test 5 & 6 — Month-end & Leap Year Boundary Calculations', () {
    test(
      'advanceMonthly safely clamps Jan 31 -> Feb 28 in non-leap year (2025)',
      () {
        final bill = Bill(
          id: 'b-1',
          name: 'Gym',
          amount: 1000,
          dueDate: DateTime(2025, 1, 31),
          repeat: 'Monthly',
          category: 'Other',
          paid: false,
          reminderSchedule: 'none',
          notes: '',
        );

        final febDate = bill.advanceMonthly(bill.dueDate);
        expect(febDate, DateTime(2025, 2, 28));

        final marDate = bill.advanceMonthly(febDate);
        expect(marDate, DateTime(2025, 3, 28));
      },
    );

    test(
      'advanceMonthly safely clamps Jan 31 -> Feb 29 in leap year (2028)',
      () {
        final bill = Bill(
          id: 'b-2',
          name: 'Gym',
          amount: 1000,
          dueDate: DateTime(2028, 1, 31),
          repeat: 'Monthly',
          category: 'Other',
          paid: false,
          reminderSchedule: 'none',
          notes: '',
        );

        final febLeapDate = bill.advanceMonthly(bill.dueDate);
        expect(febLeapDate, DateTime(2028, 2, 29));
      },
    );

    test(
      'advanceMonthly clamps 31st to 30th for 30-day months (March 31 -> April 30)',
      () {
        final bill = Bill(
          id: 'b-3',
          name: 'Service',
          amount: 500,
          dueDate: DateTime(2026, 3, 31),
          repeat: 'Monthly',
          category: 'Other',
          paid: false,
          reminderSchedule: 'none',
          notes: '',
        );

        final aprDate = bill.advanceMonthly(bill.dueDate);
        expect(aprDate, DateTime(2026, 4, 30));

        final mayDate = bill.advanceMonthly(DateTime(2026, 5, 31));
        expect(mayDate, DateTime(2026, 6, 30));
      },
    );

    test(
      'advanceYearly clamps Feb 29 on leap year to Feb 28 on next non-leap year',
      () {
        final bill = Bill(
          id: 'b-4',
          name: 'Leap Renewal',
          amount: 2000,
          dueDate: DateTime(2028, 2, 29),
          repeat: 'Yearly',
          category: 'Other',
          paid: false,
          reminderSchedule: 'none',
          notes: '',
        );

        final nextYear = bill.advanceYearly(bill.dueDate);
        expect(nextYear, DateTime(2029, 2, 28));
      },
    );
  });

  group('Test 7 — Overdue Bill Calculation & Payment', () {
    test(
      'Overdue recurring bill remains overdue until paid and advances properly',
      () {
        // Due August 20, 2026
        final bill = Bill(
          id: 'b-overdue',
          name: 'Water Utility',
          amount: 800,
          dueDate: DateTime(2026, 8, 20),
          repeat: 'Monthly',
          category: 'Utilities',
          paid: false,
          reminderSchedule: '1 day before',
          notes: '',
        );

        // Reference date: August 26, 2026
        final refDate = DateTime(2026, 8, 26);
        expect(bill.isOverdueAt(referenceDate: refDate), isTrue);
        expect(bill.getStatus(referenceDate: refDate), 'overdue');
        expect(bill.getStatusLabel(referenceDate: refDate), 'OVERDUE');

        // User pays overdue bill on August 26
        final nextDate = bill.getNextOccurrence(bill.dueDate);
        expect(nextDate, DateTime(2026, 9, 20));

        final paidBill = bill.copyWith(
          dueDate: nextDate,
          paid: false,
          paymentHistory: [
            BillPayment(
              occurrenceDate: bill.dueDate,
              paidDate: refDate,
              amount: bill.amount,
            ),
          ],
        );

        expect(paidBill.dueDate, DateTime(2026, 9, 20));
        expect(paidBill.paid, isFalse);
        // On August 26, September 20 is in the future -> not overdue!
        expect(paidBill.isOverdueAt(referenceDate: refDate), isFalse);
        expect(paidBill.getStatus(referenceDate: refDate), 'unpaid');
        expect(paidBill.paymentHistory.length, 1);
        expect(
          paidBill.paymentHistory.first.occurrenceDate,
          DateTime(2026, 8, 20),
        );
      },
    );
  });

  group('Test 8 — Payment History Preservation During Edits', () {
    test('Editing bill metadata preserves payment history', () {
      final billWithHistory = Bill(
        id: 'b-edit',
        name: 'Netflix',
        amount: 500,
        dueDate: DateTime(2026, 9, 30),
        repeat: 'Monthly',
        category: 'Subscription',
        paid: false,
        reminderSchedule: '3 days before',
        notes: 'Old notes',
        paymentHistory: [
          BillPayment(
            occurrenceDate: DateTime(2026, 7, 30),
            paidDate: DateTime(2026, 7, 28),
            amount: 500,
          ),
          BillPayment(
            occurrenceDate: DateTime(2026, 8, 30),
            paidDate: DateTime(2026, 8, 29),
            amount: 500,
          ),
        ],
      );

      expect(billWithHistory.paymentHistory.length, 2);

      // User changes amount to 550 and notes
      final editedBill = billWithHistory.copyWith(
        amount: 550,
        notes: 'Price increased to 550',
      );

      expect(editedBill.amount, 550);
      expect(editedBill.notes, 'Price increased to 550');
      expect(editedBill.paymentHistory.length, 2);
      expect(editedBill.paymentHistory[0].amount, 500);
      expect(editedBill.paymentHistory[1].amount, 500);
    });
  });

  group('Test 9 — JSON Serialization & Backward Compatibility', () {
    test('Older JSON without paymentHistory deserializes safely', () {
      final legacyJson = {
        'id': 'legacy-1',
        'name': 'Electric Meralco',
        'amount': 3200.50,
        'dueDate': '2026-08-15T00:00:00.000',
        'repeat': 'Monthly',
        'category': 'Utilities',
        'paid': false,
        'reminderSchedule': '3 days before',
        'notes': 'Legacy record',
      };

      final bill = Bill.fromJson(legacyJson);
      expect(bill.id, 'legacy-1');
      expect(bill.name, 'Electric Meralco');
      expect(bill.amount, 3200.50);
      expect(bill.paymentHistory, isNotNull);
      expect(bill.paymentHistory, isEmpty);
    });

    test('Full JSON serialization round-trip retains paymentHistory', () {
      final original = Bill(
        id: 'roundtrip-1',
        name: 'Spotify',
        amount: 149.0,
        dueDate: DateTime(2026, 9, 10),
        repeat: 'Monthly',
        category: 'Subscription',
        paid: false,
        reminderSchedule: '1 day before',
        notes: 'Family plan',
        paymentHistory: [
          BillPayment(
            occurrenceDate: DateTime(2026, 8, 10),
            paidDate: DateTime(2026, 8, 9),
            amount: 149.0,
          ),
        ],
      );

      final json = original.toJson();
      final restored = Bill.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.amount, original.amount);
      expect(restored.dueDate, original.dueDate);
      expect(restored.paymentHistory.length, 1);
      expect(
        restored.paymentHistory.first.occurrenceDate,
        DateTime(2026, 8, 10),
      );
      expect(restored.paymentHistory.first.paidDate, DateTime(2026, 8, 9));
      expect(restored.paymentHistory.first.amount, 149.0);
    });
  });

  group('Test 10 — Statistics Calculation', () {
    test(
      'Statistics correctly calculate total unpaid and count active bills without duplicate counting',
      () {
        final bills = [
          // 1. One-time unpaid bill: 2500
          Bill(
            id: 'b1',
            name: 'Electric',
            amount: 2500.0,
            dueDate: DateTime(2026, 8, 30),
            repeat: 'None',
            category: 'Utilities',
            paid: false,
            reminderSchedule: '1 day before',
            notes: '',
          ),
          // 2. One-time paid bill: 800
          Bill(
            id: 'b2',
            name: 'Water',
            amount: 800.0,
            dueDate: DateTime(2026, 8, 20),
            repeat: 'None',
            category: 'Utilities',
            paid: true,
            reminderSchedule: '1 day before',
            notes: '',
          ),
          // 3. Active recurring bill (paid August cycle, now representing September cycle unpaid): 1500
          Bill(
            id: 'b3',
            name: 'Internet',
            amount: 1500.0,
            dueDate: DateTime(2026, 9, 30),
            repeat: 'Monthly',
            category: 'Internet',
            paid: false,
            reminderSchedule: '3 days before',
            notes: '',
            paymentHistory: [
              BillPayment(
                occurrenceDate: DateTime(2026, 8, 30),
                paidDate: DateTime(2026, 8, 28),
                amount: 1500.0,
              ),
            ],
          ),
        ];

        final unpaidBills = bills.where((b) => !b.paid).toList();
        final paidBills = bills.where((b) => b.paid).toList();

        expect(unpaidBills.length, 2); // b1 and b3
        expect(paidBills.length, 1); // b2

        final totalUnpaidAmount = unpaidBills.fold(
          0.0,
          (sum, b) => sum + b.amount,
        );
        expect(totalUnpaidAmount, 2500.0 + 1500.0); // 4000.0
      },
    );
  });

  test('Recurring bill resets to unpaid at the selected reset window', () {
    final bill = Bill(
      id: 'reset-window',
      name: 'Internet',
      amount: 1500,
      dueDate: DateTime(2026, 10, 30),
      repeat: 'Monthly',
      category: 'Internet',
      paid: false,
      reminderSchedule: 'Same day',
      resetSchedule: '3 days before',
      notes: '',
      paymentHistory: [
        BillPayment(
          occurrenceDate: DateTime(2026, 9, 30),
          paidDate: DateTime(2026, 9, 27),
          amount: 1500,
        ),
      ],
    );

    expect(
      bill.getDisplayStatus(referenceDate: DateTime(2026, 10, 26)),
      'paid',
    );
    expect(
      bill.getDisplayStatus(referenceDate: DateTime(2026, 10, 27)),
      'unpaid',
    );
    expect(bill.getResetAdvanceDays(), 3);
  });
}
