import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Birthday {
  Birthday({
    required this.id,
    required this.name,
    required this.birthDate,
    this.relationship = 'Family',
    this.giftIdeas = '',
    this.remind7DaysBefore = true,
    this.remind1DayBefore = true,
    this.remindOnDay = true,
    this.reminderTime = '09:00 AM',
    this.customNotes = '',
    this.yearKnown = true,
    this.isUserBirthday = false,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String relationship;
  final String giftIdeas;
  final bool remind7DaysBefore;
  final bool remind1DayBefore;
  final bool remindOnDay;
  final String reminderTime;
  final String customNotes;
  final bool yearKnown;
  final bool isUserBirthday;

  static const List<String> relationshipOptions = [
    'Family',
    'Friend',
    'School',
    'Work',
    'Partner',
    'Other',
  ];

  int? get turningAge => turningAgeFor(DateTime.now());
  int get daysUntilNext => daysUntilNextFor(DateTime.now());
  DateTime get nextBirthdayDate => nextBirthdayDateFor(DateTime.now());
  String get formattedDate => formattedDateFor(DateTime.now());

  int? turningAgeFor(DateTime reference) {
    if (!yearKnown || birthDate.year <= 0) return null;
    return nextBirthdayDateFor(reference).year - birthDate.year;
  }

  int daysUntilNextFor(DateTime reference) {
    final today = DateTime(reference.year, reference.month, reference.day);
    return nextBirthdayDateFor(reference).difference(today).inDays;
  }

  DateTime nextBirthdayDateFor(DateTime reference) {
    final month = birthDate.month;
    final day = birthDate.day;
    final nextYear = reference.year;
    final candidate = _safeBirthdayDate(nextYear, month, day);
    if (!candidate.isBefore(
      DateTime(reference.year, reference.month, reference.day),
    )) {
      return candidate;
    }
    return _safeBirthdayDate(nextYear + 1, month, day);
  }

  String formattedDateFor(DateTime reference) {
    final dt = DateFormat('MMMM d').format(birthDate);
    final age = turningAgeFor(reference);
    if (age == null || age <= 0) return dt;
    return '$dt (Turns $age)';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'birthDate': birthDate.toIso8601String(),
    'relationship': relationship,
    'giftIdeas': giftIdeas,
    'remind7DaysBefore': remind7DaysBefore,
    'remind1DayBefore': remind1DayBefore,
    'remindOnDay': remindOnDay,
    'reminderTime': reminderTime,
    'customNotes': customNotes,
    'yearKnown': yearKnown,
    'isUserBirthday': isUserBirthday,
  };

  factory Birthday.fromJson(Map<String, dynamic> json) {
    final birthDateRaw = json['birthDate'];
    DateTime parsedBirthDate;
    if (birthDateRaw is String && birthDateRaw.trim().isNotEmpty) {
      try {
        parsedBirthDate = DateTime.parse(birthDateRaw);
      } catch (_) {
        parsedBirthDate = DateTime(DateTime.now().year, 1, 1);
      }
    } else {
      parsedBirthDate = DateTime(DateTime.now().year, 1, 1);
    }

    final yearKnown = json['yearKnown'] is bool
        ? json['yearKnown'] as bool
        : true;
    final isUserBirthday = json['isUserBirthday'] is bool
        ? json['isUserBirthday'] as bool
        : false;

    return Birthday(
      id:
          (json['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? '',
      birthDate: _coerceBirthDate(parsedBirthDate, yearKnown),
      relationship: (json['relationship'] as String?) ?? 'Family',
      giftIdeas: (json['giftIdeas'] as String?) ?? '',
      remind7DaysBefore: json['remind7DaysBefore'] is bool
          ? json['remind7DaysBefore'] as bool
          : true,
      remind1DayBefore: json['remind1DayBefore'] is bool
          ? json['remind1DayBefore'] as bool
          : true,
      remindOnDay: json['remindOnDay'] is bool
          ? json['remindOnDay'] as bool
          : true,
      reminderTime: (json['reminderTime'] as String?) ?? '09:00 AM',
      customNotes: (json['customNotes'] as String?) ?? '',
      yearKnown: yearKnown,
      isUserBirthday: isUserBirthday,
    );
  }

  Birthday copyWith({
    String? id,
    String? name,
    DateTime? birthDate,
    String? relationship,
    String? giftIdeas,
    bool? remind7DaysBefore,
    bool? remind1DayBefore,
    bool? remindOnDay,
    String? reminderTime,
    String? customNotes,
    bool? yearKnown,
    bool? isUserBirthday,
  }) {
    return Birthday(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      relationship: relationship ?? this.relationship,
      giftIdeas: giftIdeas ?? this.giftIdeas,
      remind7DaysBefore: remind7DaysBefore ?? this.remind7DaysBefore,
      remind1DayBefore: remind1DayBefore ?? this.remind1DayBefore,
      remindOnDay: remindOnDay ?? this.remindOnDay,
      reminderTime: reminderTime ?? this.reminderTime,
      customNotes: customNotes ?? this.customNotes,
      yearKnown: yearKnown ?? this.yearKnown,
      isUserBirthday: isUserBirthday ?? this.isUserBirthday,
    );
  }

  static Birthday? findUserBirthday(List<Birthday> birthdays) {
    for (final birthday in birthdays) {
      if (birthday.isUserBirthday) return birthday;
    }
    return null;
  }

  static DateTime _coerceBirthDate(DateTime parsed, bool yearKnown) {
    if (!yearKnown) {
      return DateTime(2000, parsed.month, parsed.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _safeBirthdayDate(int year, int month, int day) {
    final safeYear = year < 1 ? 2000 : year;
    final monthValue = month.clamp(1, 12);
    final maxDay = DateTime(safeYear, monthValue + 1, 0).day;
    final safeDay = day.clamp(1, maxDay);
    return DateTime(safeYear, monthValue, safeDay);
  }
}

class Reminder {
  Reminder({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.date,
    required this.time,
    required this.repeat,
    required this.reminderBefore,
    required this.priority,
    required this.notes,
    required this.completed,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final DateTime date;
  final String time;
  final String repeat;
  final String reminderBefore;
  final String priority;
  final String notes;
  final bool completed;

  Reminder copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    DateTime? date,
    String? time,
    String? repeat,
    String? reminderBefore,
    String? priority,
    String? notes,
    bool? completed,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      reminderBefore: reminderBefore ?? this.reminderBefore,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'description': description,
    'date': date.toIso8601String(),
    'time': time,
    'repeat': repeat,
    'reminderBefore': reminderBefore,
    'priority': priority,
    'notes': notes,
    'completed': completed,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    description: json['description'] as String,
    date: DateTime.parse(json['date'] as String),
    time: json['time'] as String,
    repeat: json['repeat'] as String,
    reminderBefore: json['reminderBefore'] as String,
    priority: json['priority'] as String,
    notes: json['notes'] as String,
    completed: json['completed'] as bool,
  );

  Color get categoryColor {
    switch (category) {
      case 'Bills':
        return const Color(0xFF22C55E);
      case 'AI Reset':
        return const Color(0xFF8B5CF6);
      case 'Subscriptions':
        return const Color(0xFF3B82F6);
      case 'Gaming':
        return const Color(0xFFEC4899);
      case 'Work':
        return const Color(0xFFF59E0B);
      case 'School':
        return const Color(0xFF14B8A6);
      case 'Personal':
        return const Color(0xFFEF4444);
      case 'Household':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'Bills':
        return Icons.receipt_long;
      case 'AI Reset':
        return Icons.smart_toy;
      case 'Subscriptions':
        return Icons.subscriptions;
      case 'Gaming':
        return Icons.sports_esports;
      case 'Work':
        return Icons.work;
      case 'School':
        return Icons.school;
      case 'Personal':
        return Icons.favorite;
      case 'Household':
        return Icons.home_work;
      default:
        return Icons.push_pin;
    }
  }
}

class DayClassMode {
  static const String f2f = 'Face-to-Face Class';
  static const String asyncModule = 'Asynchronous (Module)';
  static const String syncOnline = 'Synchronous Module (Online)';

  static const List<String> allModes = [f2f, asyncModule, syncOnline];

  static String getShortName(String mode) {
    switch (mode) {
      case asyncModule:
        return 'ASYNC';
      case syncOnline:
        return 'ONLINE';
      case f2f:
      default:
        return 'F2F';
    }
  }
}

class SchoolClass {
  SchoolClass({
    required this.id,
    required this.subject,
    this.courseCode = '',
    this.teacher = '',
    this.room = '',
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.reminderBefore = 'At start',
    this.notes = '',
    this.colorValue = 0xFF14B8A6,
  });

  final String id;
  final String subject;
  final String courseCode;
  final String teacher;
  final String room;
  final List<int> daysOfWeek; // 1 = Mon, 2 = Tue, ..., 7 = Sun
  final String startTime;
  final String endTime;
  final String
  reminderBefore; // "At start", "10 minutes", "15 minutes", "30 minutes"
  final String notes;
  final int colorValue;

  SchoolClass copyWith({
    String? id,
    String? subject,
    String? courseCode,
    String? teacher,
    String? room,
    List<int>? daysOfWeek,
    String? startTime,
    String? endTime,
    String? reminderBefore,
    String? notes,
    int? colorValue,
  }) {
    return SchoolClass(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      courseCode: courseCode ?? this.courseCode,
      teacher: teacher ?? this.teacher,
      room: room ?? this.room,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reminderBefore: reminderBefore ?? this.reminderBefore,
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'courseCode': courseCode,
    'teacher': teacher,
    'room': room,
    'daysOfWeek': daysOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'reminderBefore': reminderBefore,
    'notes': notes,
    'colorValue': colorValue,
  };

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
    id: json['id'] as String,
    subject: json['subject'] as String,
    courseCode: (json['courseCode'] ?? '') as String,
    teacher: (json['teacher'] ?? '') as String,
    room: (json['room'] ?? '') as String,
    daysOfWeek:
        (json['daysOfWeek'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [1],
    startTime: (json['startTime'] ?? '08:00 AM') as String,
    endTime: (json['endTime'] ?? '10:00 AM') as String,
    reminderBefore: (json['reminderBefore'] ?? 'At start') as String,
    notes: (json['notes'] ?? '') as String,
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF14B8A6,
  );

  Color get color => Color(colorValue);

  String get daysFormatted {
    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    if (daysOfWeek.length == 7) return 'Everyday';
    if (daysOfWeek.length == 6 &&
        daysOfWeek.contains(1) &&
        daysOfWeek.contains(2) &&
        daysOfWeek.contains(3) &&
        daysOfWeek.contains(4) &&
        daysOfWeek.contains(5) &&
        daysOfWeek.contains(6)) {
      return 'Mon – Sat';
    }
    if (daysOfWeek.length == 5 &&
        daysOfWeek.contains(1) &&
        daysOfWeek.contains(2) &&
        daysOfWeek.contains(3) &&
        daysOfWeek.contains(4) &&
        daysOfWeek.contains(5)) {
      return 'Mon – Fri';
    }
    final sorted = List<int>.from(daysOfWeek)..sort();
    return sorted
        .map((d) => dayNames[d] ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  String get timeRange => '$startTime – $endTime';

  bool occursOnDay(int weekday) => daysOfWeek.contains(weekday);

  bool get isToday => occursOnDay(DateTime.now().weekday);
}

class AIAccount {
  AIAccount({
    required this.id,
    required this.service,
    required this.accountName,
    required this.email,
    required this.username,
    required this.password,
    this.authMethod = 'Password', // Password, Google, OAuth, API Key
    required this.plan,
    DateTime? resetDate,
    String? resetTime,
    String? resetSchedule,
    DateTime? renewalDate,
    required this.notes,
    this.resetState = 'none',
    this.resetCooldownUntil,
  }) : resetDate = resetDate ?? DateTime.now().add(const Duration(days: 30)),
       resetTime = resetTime ?? '10:00 PM',
       resetSchedule = resetSchedule ?? 'Exact Date/Time',
       renewalDate =
           renewalDate ?? DateTime.now().add(const Duration(days: 30));

  final String id;
  final String
  service; // ChatGPT, Claude, Gemini, Grok, Cursor, GitHub Copilot, Perplexity, DeepSeek, Custom
  final String accountName; // Personal, School, Work, etc.
  final String email;
  final String username;
  final String password;
  final String authMethod;
  final String plan; // Free, Plus, Pro, Team, Enterprise, Custom
  final DateTime resetDate;
  final String resetTime;
  final String resetSchedule; // backward compatible
  final DateTime renewalDate;
  final String notes;
  final String resetState;
  final DateTime? resetCooldownUntil;

  /// Availability follows the device's local clock; no saved/manual state
  /// can override the scheduled reset.
  String get currentResetStatus =>
      _resetAt.isAfter(DateTime.now()) ? 'Cooldown' : 'Active';

  DateTime get _resetAt {
    final time = _parsedResetTime;
    return DateTime(
      resetDate.year,
      resetDate.month,
      resetDate.day,
      time.hour,
      time.minute,
    );
  }

  DateTime get _parsedResetTime {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*([ap]m)?\s*$',
      caseSensitive: false,
    ).firstMatch(resetTime);
    if (match == null) return DateTime(0, 1, 1, 22);
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)?.toLowerCase();
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return DateTime(0, 1, 1, 22);
    return DateTime(0, 1, 1, hour, minute);
  }

  bool get isFreePlan => plan.toLowerCase() == 'free';
  bool get isGoogleAuth => authMethod == 'Google';
  bool get isPasswordOptional => authMethod != 'Password';

  AIAccount copyWith({
    String? id,
    String? service,
    String? accountName,
    String? email,
    String? username,
    String? password,
    String? authMethod,
    String? plan,
    DateTime? resetDate,
    String? resetTime,
    String? resetSchedule,
    DateTime? renewalDate,
    String? notes,
    String? resetState,
    DateTime? resetCooldownUntil,
  }) {
    return AIAccount(
      id: id ?? this.id,
      service: service ?? this.service,
      accountName: accountName ?? this.accountName,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      authMethod: authMethod ?? this.authMethod,
      plan: plan ?? this.plan,
      resetDate: resetDate ?? this.resetDate,
      resetTime: resetTime ?? this.resetTime,
      resetSchedule: resetSchedule ?? this.resetSchedule,
      renewalDate: renewalDate ?? this.renewalDate,
      notes: notes ?? this.notes,
      resetState: resetState ?? this.resetState,
      resetCooldownUntil: resetCooldownUntil ?? this.resetCooldownUntil,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'service': service,
    'accountName': accountName,
    'email': email,
    'username': username,
    'password': password,
    'authMethod': authMethod,
    'plan': plan,
    'resetDate': resetDate.toIso8601String(),
    'resetTime': resetTime,
    'resetSchedule': resetSchedule,
    'renewalDate': renewalDate.toIso8601String(),
    'notes': notes,
    'resetState': resetState,
    'resetCooldownUntil': resetCooldownUntil?.toIso8601String(),
  };

  factory AIAccount.fromJson(Map<String, dynamic> json) {
    DateTime parsedResetDate;
    if (json['resetDate'] != null) {
      parsedResetDate = DateTime.parse(json['resetDate'] as String);
    } else if (json['renewalDate'] != null) {
      parsedResetDate = DateTime.parse(json['renewalDate'] as String);
    } else {
      parsedResetDate = DateTime.now().add(const Duration(days: 30));
    }

    return AIAccount(
      id: json['id'] as String,
      service: json['service'] as String,
      accountName: json['accountName'] as String,
      email: (json['email'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      password: (json['password'] ?? '') as String,
      authMethod: (json['authMethod'] ?? 'Password') as String,
      plan: json['plan'] as String,
      resetDate: parsedResetDate,
      resetTime: (json['resetTime'] ?? '10:00 PM') as String,
      resetSchedule: (json['resetSchedule'] ?? 'Exact Date/Time') as String,
      renewalDate: json['renewalDate'] != null
          ? DateTime.parse(json['renewalDate'] as String)
          : DateTime.now().add(const Duration(days: 30)),
      notes: (json['notes'] ?? '') as String,
      resetState: (json['resetState'] ?? 'none') as String,
      resetCooldownUntil: json['resetCooldownUntil'] is String
          ? DateTime.tryParse(json['resetCooldownUntil'] as String)
          : null,
    );
  }

  Color get serviceColor {
    switch (service) {
      case 'ChatGPT':
        return const Color(0xFF10A37F);
      case 'Claude':
        return const Color(0xFFD97706);
      case 'Gemini':
        return const Color(0xFF2563EB);
      case 'Grok':
        return const Color(0xFF111827);
      case 'Cursor':
        return const Color(0xFF0284C7);
      case 'GitHub Copilot':
        return const Color(0xFF6E40C9);
      case 'Perplexity':
        return const Color(0xFF0D9488);
      case 'DeepSeek':
        return const Color(0xFF4F46E5);
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

class UserAccount {
  UserAccount({
    required this.id,
    required this.serviceName,
    required this.accountName,
    required this.username,
    required this.email,
    required this.password,
    this.authMethod = 'Password', // Password, Google, OAuth, API Key
    required this.website,
    required this.category,
    required this.notes,
    this.recoveryEmail = '',
    this.recoveryPhone = '',
    this.securityQuestion = '',
    this.pin = '',
    this.accountNumber = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String serviceName;
  final String accountName;
  final String username;
  final String email;
  final String password;
  final String authMethod;
  final String website;
  final String
  category; // Websites, Apps, Gaming, Finance, Email, Work, School, AI, Shopping, Custom
  final String notes;
  final String recoveryEmail;
  final String recoveryPhone;
  final String securityQuestion;
  final String pin;
  final String accountNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isGoogleAuth => authMethod == 'Google';
  bool get isPasswordOptional => authMethod != 'Password';

  UserAccount copyWith({
    String? id,
    String? serviceName,
    String? accountName,
    String? username,
    String? email,
    String? password,
    String? authMethod,
    String? website,
    String? category,
    String? notes,
    String? recoveryEmail,
    String? recoveryPhone,
    String? securityQuestion,
    String? pin,
    String? accountNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      accountName: accountName ?? this.accountName,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      authMethod: authMethod ?? this.authMethod,
      website: website ?? this.website,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      recoveryPhone: recoveryPhone ?? this.recoveryPhone,
      securityQuestion: securityQuestion ?? this.securityQuestion,
      pin: pin ?? this.pin,
      accountNumber: accountNumber ?? this.accountNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceName': serviceName,
    'accountName': accountName,
    'username': username,
    'email': email,
    'password': password,
    'authMethod': authMethod,
    'website': website,
    'category': category,
    'notes': notes,
    'recoveryEmail': recoveryEmail,
    'recoveryPhone': recoveryPhone,
    'securityQuestion': securityQuestion,
    'pin': pin,
    'accountNumber': accountNumber,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'] as String,
    serviceName: json['serviceName'] as String,
    accountName: json['accountName'] as String,
    username: (json['username'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    password: (json['password'] ?? '') as String,
    authMethod: (json['authMethod'] ?? 'Password') as String,
    website: (json['website'] ?? '') as String,
    category: (json['category'] ?? 'Websites') as String,
    notes: (json['notes'] ?? '') as String,
    recoveryEmail: (json['recoveryEmail'] ?? '') as String,
    recoveryPhone: (json['recoveryPhone'] ?? '') as String,
    securityQuestion: (json['securityQuestion'] ?? '') as String,
    pin: (json['pin'] ?? '') as String,
    accountNumber: (json['accountNumber'] ?? '') as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  IconData get categoryIcon {
    switch (category) {
      case 'Websites':
        return Icons.language;
      case 'Apps':
        return Icons.apps;
      case 'Gaming':
        return Icons.sports_esports;
      case 'Finance':
        return Icons.account_balance;
      case 'Email':
        return Icons.email;
      case 'Work':
        return Icons.work;
      case 'School':
        return Icons.school;
      case 'AI':
        return Icons.smart_toy;
      case 'Shopping':
        return Icons.shopping_bag;
      default:
        return Icons.lock_outline;
    }
  }
}

/// Represents a single completed payment occurrence for a recurring bill.
class BillPayment {
  BillPayment({
    required this.occurrenceDate,
    required this.paidDate,
    required this.amount,
  });

  /// The due date of the billing cycle that was paid.
  final DateTime occurrenceDate;

  /// The actual date/time the user marked the bill as paid.
  final DateTime paidDate;

  /// The amount that was paid for this occurrence.
  final double amount;

  BillPayment copyWith({
    DateTime? occurrenceDate,
    DateTime? paidDate,
    double? amount,
  }) {
    return BillPayment(
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      paidDate: paidDate ?? this.paidDate,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() => {
    'occurrenceDate': occurrenceDate.toIso8601String(),
    'paidDate': paidDate.toIso8601String(),
    'amount': amount,
  };

  factory BillPayment.fromJson(Map<String, dynamic> json) => BillPayment(
    occurrenceDate: DateTime.parse(json['occurrenceDate'] as String),
    paidDate: DateTime.parse(json['paidDate'] as String),
    amount: (json['amount'] as num).toDouble(),
  );
}

class Bill {
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.repeat,
    required this.category,
    required this.paid,
    required this.reminderSchedule,
    required this.notes,
    String? resetSchedule,
    List<BillPayment>? paymentHistory,
  }) : resetSchedule = resetSchedule ?? reminderSchedule,
       paymentHistory = paymentHistory ?? [];

  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final String repeat; // None, Monthly, Yearly, Custom
  final String category;
  final bool paid;
  final String reminderSchedule; // 1 day before, 3 days before, 1 week before
  final String resetSchedule; // when a paid recurring bill becomes unpaid
  final String notes;

  /// Payment history for recurring bills. Each entry represents one completed
  /// billing cycle. Non-recurring bills will always have an empty list.
  final List<BillPayment> paymentHistory;

  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    String? repeat,
    String? category,
    bool? paid,
    String? reminderSchedule,
    String? resetSchedule,
    String? notes,
    List<BillPayment>? paymentHistory,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      repeat: repeat ?? this.repeat,
      category: category ?? this.category,
      paid: paid ?? this.paid,
      reminderSchedule: reminderSchedule ?? this.reminderSchedule,
      resetSchedule: resetSchedule ?? this.resetSchedule,
      notes: notes ?? this.notes,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'dueDate': dueDate.toIso8601String(),
    'repeat': repeat,
    'category': category,
    'paid': paid,
    'reminderSchedule': reminderSchedule,
    'resetSchedule': resetSchedule,
    'notes': notes,
    'paymentHistory': paymentHistory.map((p) => p.toJson()).toList(),
  };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'] as String,
    name: json['name'] as String,
    amount: (json['amount'] as num).toDouble(),
    dueDate: DateTime.parse(json['dueDate'] as String),
    repeat: json['repeat'] as String,
    category: json['category'] as String,
    paid: json['paid'] as bool,
    reminderSchedule: json['reminderSchedule'] as String,
    resetSchedule:
        (json['resetSchedule'] ?? json['reminderSchedule'] ?? '3 days before')
            as String,
    notes: json['notes'] as String,
    // Null-safe: old records without paymentHistory default to empty list
    paymentHistory:
        (json['paymentHistory'] as List<dynamic>?)
            ?.map((e) => BillPayment.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  /// Returns true if this bill repeats periodically (Monthly, Yearly, Custom).
  bool get isRecurring => repeat != 'None' && repeat.isNotEmpty;

  /// Parses the reminder schedule string and returns the number of days before due date.
  /// Returns 0 for "Same day" or "None".
  int getReminderAdvanceDays() {
    return _getAdvanceDays(reminderSchedule);
  }

  int getResetAdvanceDays() {
    return _getAdvanceDays(resetSchedule);
  }

  int _getAdvanceDays(String schedule) {
    final clean = schedule.trim().toLowerCase();
    if (clean == 'same day' ||
        clean == 'at due date' ||
        clean == 'at time' ||
        clean == 'none' ||
        clean.isEmpty) {
      return 0;
    }
    if (clean == '1 day before' || clean == '1 day') return 1;
    if (clean == '2 days before' || clean == '2 days') return 2;
    if (clean == '3 days before' || clean == '3 days') return 3;
    if (clean == '5 days before' || clean == '5 days') return 5;
    if (clean == '1 week before' || clean == '1 week' || clean == '7 days') {
      return 7;
    }
    final match = RegExp(r'(\d+)\s*day').firstMatch(clean);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '1') ?? 1;
    }
    return 1;
  }

  /// Calculates the activation date for an occurrence (when it enters the reminder window).
  DateTime getActivationDate(DateTime occurrenceDate) {
    final advanceDays = getResetAdvanceDays();
    return occurrenceDate.subtract(Duration(days: advanceDays));
  }

  /// Advances a date by one month, clamping day to valid range (e.g. Jan 31 -> Feb 28/29).
  DateTime advanceMonthly(DateTime date) {
    var year = date.year;
    var month = date.month + 1;
    if (month > 12) {
      month = 1;
      year++;
    }
    final maxDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      date.day.clamp(1, maxDay),
      date.hour,
      date.minute,
    );
  }

  /// Advances a date by one year, clamping day for leap years (e.g. Feb 29 2028 -> Feb 28 2029).
  DateTime advanceYearly(DateTime date) {
    final year = date.year + 1;
    final maxDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(
      year,
      date.month,
      date.day.clamp(1, maxDay),
      date.hour,
      date.minute,
    );
  }

  /// Calculates the next occurrence date after the given date based on recurrence type.
  DateTime getNextOccurrence(DateTime fromDate) {
    if (repeat == 'Monthly') {
      return advanceMonthly(fromDate);
    } else if (repeat == 'Yearly') {
      return advanceYearly(fromDate);
    } else if (repeat == 'None' || repeat.isEmpty) {
      return fromDate;
    } else {
      // Custom or unknown repeat
      return advanceMonthly(fromDate);
    }
  }

  /// Checks if the bill is currently overdue relative to [referenceDate] (or today).
  bool isOverdueAt({DateTime? referenceDate}) {
    if (paid) return false;
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(due);
  }

  /// Whether the bill is currently overdue today.
  bool get isOverdue => isOverdueAt();

  /// Returns 'paid', 'overdue', or 'unpaid' relative to [referenceDate] (or today).
  String getStatus({DateTime? referenceDate}) {
    if (paid) return 'paid';
    if (isOverdueAt(referenceDate: referenceDate)) return 'overdue';
    return 'unpaid';
  }

  /// The current status string ('paid', 'overdue', or 'unpaid').
  String get status => getStatus();

  /// Returns 'PAID', 'OVERDUE', or 'UNPAID' relative to [referenceDate] (or today).
  String getStatusLabel({DateTime? referenceDate}) {
    final s = getStatus(referenceDate: referenceDate);
    switch (s) {
      case 'paid':
        return 'PAID';
      case 'overdue':
        return 'OVERDUE';
      case 'unpaid':
      default:
        return 'UNPAID';
    }
  }

  /// The user-facing uppercase status label ('PAID', 'OVERDUE', 'UNPAID').
  String get statusLabel => getStatusLabel();

  /// Gets the days until due (negative if overdue).
  int getDaysUntilDue({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  /// Returns the effective due date that should be displayed to the user,
  /// respecting the reminder/activation window for recurring bills.
  /// Example: monthly bill due Nov 1, reminder 3 days => activation Oct 29.
  /// If today is Oct 15 and history contains Oct 1 paid => display Oct 1 (PAID) until Oct 29.
  DateTime getDisplayDueDate({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    if (!isRecurring || paymentHistory.isEmpty) return dueDate;
    final nextDue = dueDate;
    final activation = getActivationDate(nextDue);
    final today = DateTime(now.year, now.month, now.day);
    final activationDay = DateTime(
      activation.year,
      activation.month,
      activation.day,
    );
    if (today.isBefore(activationDay)) {
      // Before activation window => still show last paid occurrence as PAID
      final last = paymentHistory.last;
      return last.occurrenceDate;
    }
    return nextDue;
  }

  /// Returns the effective display status ('paid','overdue','unpaid','upcoming')
  /// respecting activation window for recurring bills.
  String getDisplayStatus({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    // Recurring with history and before activation => PAID
    if (isRecurring && paymentHistory.isNotEmpty) {
      final activation = getActivationDate(dueDate);
      final today = DateTime(now.year, now.month, now.day);
      final activationDay = DateTime(
        activation.year,
        activation.month,
        activation.day,
      );
      if (today.isBefore(activationDay)) {
        return 'paid';
      }
      // activation reached => evaluate real due date status
      // For recurring, paid flag should be false for active occurrence
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (paid) return 'paid';
      if (today.isAfter(dueDay)) return 'overdue';
      return 'unpaid';
    }
    // Non-recurring or no history: consider activation window for upcoming
    if (paid) return 'paid';
    if (isOverdueAt(referenceDate: now)) return 'overdue';
    // Check if still upcoming (before reminder window)
    final activation = getActivationDate(dueDate);
    final today = DateTime(now.year, now.month, now.day);
    final activationDay = DateTime(
      activation.year,
      activation.month,
      activation.day,
    );
    if (today.isBefore(activationDay)) return 'upcoming';
    return 'unpaid';
  }

  String getDisplayStatusLabel({DateTime? referenceDate}) {
    final s = getDisplayStatus(referenceDate: referenceDate);
    switch (s) {
      case 'paid':
        return 'PAID';
      case 'overdue':
        return 'OVERDUE';
      case 'upcoming':
        return 'UPCOMING';
      default:
        return 'UNPAID';
    }
  }

  BillPayment? getCurrentPayment({DateTime? referenceDate}) {
    final displayDue = getDisplayDueDate(referenceDate: referenceDate);
    // Try to find payment for display due date
    final p = getPaymentForOccurrence(displayDue);
    if (p != null) return p;
    return paymentHistory.isNotEmpty ? paymentHistory.last : null;
  }

  DateTime getNextOccurrenceDate({DateTime? referenceDate}) =>
      getNextOccurrence(dueDate);
  String getNextOccurrenceStatus({DateTime? referenceDate}) => 'unpaid';
  bool isOccurrencePaid(DateTime occurrenceDate) {
    return paymentHistory.any(
      (p) =>
          p.occurrenceDate.year == occurrenceDate.year &&
          p.occurrenceDate.month == occurrenceDate.month &&
          p.occurrenceDate.day == occurrenceDate.day,
    );
  }

  BillPayment? getPaymentForOccurrence(DateTime occurrenceDate) {
    try {
      return paymentHistory.firstWhere(
        (p) =>
            p.occurrenceDate.year == occurrenceDate.year &&
            p.occurrenceDate.month == occurrenceDate.month &&
            p.occurrenceDate.day == occurrenceDate.day,
      );
    } catch (_) {
      return null;
    }
  }
}

class GasPurchase {
  GasPurchase({
    required this.id,
    this.gasType = 'LPG',
    required this.tankSize,
    required this.amountPaid,
    required this.purchaseDate,
    this.supplierName = '',
    this.contactNumber = '',
    this.notes = '',
  });

  final String id;
  final String gasType; // LPG cooking gas
  final String tankSize; // 11 kg, 5 kg, 50 kg, etc.
  final double amountPaid;
  final DateTime purchaseDate;
  final String supplierName;
  final String contactNumber;
  final String notes;

  GasPurchase copyWith({
    String? id,
    String? gasType,
    String? tankSize,
    double? amountPaid,
    DateTime? purchaseDate,
    String? supplierName,
    String? contactNumber,
    String? notes,
  }) {
    return GasPurchase(
      id: id ?? this.id,
      gasType: gasType ?? this.gasType,
      tankSize: tankSize ?? this.tankSize,
      amountPaid: amountPaid ?? this.amountPaid,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      supplierName: supplierName ?? this.supplierName,
      contactNumber: contactNumber ?? this.contactNumber,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'gasType': gasType,
    'tankSize': tankSize,
    'amountPaid': amountPaid,
    'purchaseDate': purchaseDate.toIso8601String(),
    'supplierName': supplierName,
    'contactNumber': contactNumber,
    'notes': notes,
  };

  factory GasPurchase.fromJson(Map<String, dynamic> json) => GasPurchase(
    id: json['id'] as String,
    gasType: (json['gasType'] ?? 'LPG') as String,
    tankSize: json['tankSize'] as String,
    amountPaid: (json['amountPaid'] as num).toDouble(),
    purchaseDate: DateTime.parse(json['purchaseDate'] as String),
    supplierName: (json['supplierName'] ?? '') as String,
    contactNumber: (json['contactNumber'] ?? '') as String,
    notes: (json['notes'] ?? '') as String,
  );
}

class SupplierPhoneNumber {
  SupplierPhoneNumber({
    required this.id,
    required this.phoneNumber,
    this.network = 'Globe', // Globe, Smart, DITO, TM, TNT, Sun, Landline, Other
  });

  final String id;
  final String phoneNumber;
  final String network;

  SupplierPhoneNumber copyWith({
    String? id,
    String? phoneNumber,
    String? network,
  }) {
    return SupplierPhoneNumber(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      network: network ?? this.network,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phoneNumber': phoneNumber,
    'network': network,
  };

  factory SupplierPhoneNumber.fromJson(Map<String, dynamic> json) =>
      SupplierPhoneNumber(
        id: (json['id'] ?? '') as String,
        phoneNumber: (json['phoneNumber'] ?? '') as String,
        network: (json['network'] ?? 'Globe') as String,
      );

  IconData get networkIcon {
    switch (network) {
      case 'Globe':
      case 'TM':
      case 'Smart':
      case 'TNT':
      case 'Sun':
      case 'DITO':
        return Icons.phone_android;
      case 'Landline':
        return Icons.phone_in_talk;
      default:
        return Icons.phone;
    }
  }

  Color get networkColor {
    switch (network) {
      case 'Globe':
      case 'TM':
        return const Color(0xFF0054A6);
      case 'Smart':
      case 'TNT':
        return const Color(0xFF00A859);
      case 'DITO':
        return const Color(0xFFE21B1B);
      case 'Sun':
        return const Color(0xFFFFB800);
      case 'Landline':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class Supplier {
  Supplier({
    required this.id,
    required this.name,
    List<SupplierPhoneNumber>? phoneNumbers,
    String? contactNumber,
    required this.address,
    required this.notes,
  }) : phoneNumbers =
           phoneNumbers ??
           (contactNumber != null && contactNumber.isNotEmpty
               ? [
                   SupplierPhoneNumber(
                     id: 'primary',
                     phoneNumber: contactNumber,
                     network: 'Globe',
                   ),
                 ]
               : []),
       contactNumber =
           contactNumber ??
           (phoneNumbers != null && phoneNumbers.isNotEmpty
               ? phoneNumbers.first.phoneNumber
               : '');

  final String id;
  final String name;
  final List<SupplierPhoneNumber> phoneNumbers;
  final String contactNumber;
  final String address;
  final String notes;

  Supplier copyWith({
    String? id,
    String? name,
    List<SupplierPhoneNumber>? phoneNumbers,
    String? contactNumber,
    String? address,
    String? notes,
  }) {
    final updatedNumbers = phoneNumbers ?? this.phoneNumbers;
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumbers: updatedNumbers,
      contactNumber:
          contactNumber ??
          (updatedNumbers.isNotEmpty
              ? updatedNumbers.first.phoneNumber
              : this.contactNumber),
      address: address ?? this.address,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumbers': phoneNumbers.map((p) => p.toJson()).toList(),
    'contactNumber': contactNumber,
    'address': address,
    'notes': notes,
  };

  factory Supplier.fromJson(Map<String, dynamic> json) {
    List<SupplierPhoneNumber> parsedNumbers = [];
    if (json['phoneNumbers'] != null && json['phoneNumbers'] is List) {
      parsedNumbers = (json['phoneNumbers'] as List)
          .map((e) => SupplierPhoneNumber.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final legacyContact = (json['contactNumber'] ?? '') as String;
    if (parsedNumbers.isEmpty && legacyContact.isNotEmpty) {
      parsedNumbers.add(
        SupplierPhoneNumber(
          id: 'legacy_primary',
          phoneNumber: legacyContact,
          network: 'Globe',
        ),
      );
    }

    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumbers: parsedNumbers,
      contactNumber: legacyContact.isNotEmpty
          ? legacyContact
          : (parsedNumbers.isNotEmpty ? parsedNumbers.first.phoneNumber : ''),
      address: (json['address'] ?? '') as String,
      notes: (json['notes'] ?? '') as String,
    );
  }
}

class AppSettings {
  AppSettings({
    required this.themeMode, // System, Light, Dark
    this.userName = '',
    this.nameSetupCompleted = false,
    this.profileImagePath = '',
    required this.notificationTime,
    required this.currency,
    required this.appLock,
    required this.biometricEnabled,
    this.gasNotificationDays = 3,
    this.lastSeenWhatsNewVersion = '',
    this.backupFolderPath = '',
    this.hideSchoolScheduleInCalendar = false,
  });

  final String themeMode;
  final String userName;
  final bool nameSetupCompleted;
  final String profileImagePath;
  final String notificationTime;
  final String currency;
  final bool appLock;
  final bool biometricEnabled;
  final int gasNotificationDays;
  final String lastSeenWhatsNewVersion;
  final String backupFolderPath;
  final bool hideSchoolScheduleInCalendar;

  AppSettings copyWith({
    String? themeMode,
    String? userName,
    bool? nameSetupCompleted,
    String? profileImagePath,
    String? notificationTime,
    String? currency,
    bool? appLock,
    bool? biometricEnabled,
    int? gasNotificationDays,
    String? lastSeenWhatsNewVersion,
    String? backupFolderPath,
    bool? hideSchoolScheduleInCalendar,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      userName: userName ?? this.userName,
      nameSetupCompleted: nameSetupCompleted ?? this.nameSetupCompleted,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      notificationTime: notificationTime ?? this.notificationTime,
      currency: currency ?? this.currency,
      appLock: appLock ?? this.appLock,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      gasNotificationDays: gasNotificationDays ?? this.gasNotificationDays,
      lastSeenWhatsNewVersion:
          lastSeenWhatsNewVersion ?? this.lastSeenWhatsNewVersion,
      backupFolderPath: backupFolderPath ?? this.backupFolderPath,
      hideSchoolScheduleInCalendar:
          hideSchoolScheduleInCalendar ?? this.hideSchoolScheduleInCalendar,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode,
    'userName': userName,
    'nameSetupCompleted': nameSetupCompleted,
    'profileImagePath': profileImagePath,
    'notificationTime': notificationTime,
    'currency': currency,
    'appLock': appLock,
    'biometricEnabled': biometricEnabled,
    'gasNotificationDays': gasNotificationDays,
    'lastSeenWhatsNewVersion': lastSeenWhatsNewVersion,
    'backupFolderPath': backupFolderPath,
    'hideSchoolScheduleInCalendar': hideSchoolScheduleInCalendar,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawName = json['userName'];
    final nameValue = rawName is String ? rawName : '';
    final hasName =
        nameValue.trim().isNotEmpty &&
        nameValue.trim() != 'User' &&
        nameValue.trim() != 'Alex';
    final setupDone = (json['nameSetupCompleted'] is bool)
        ? json['nameSetupCompleted'] as bool
        : hasName;

    final themeModeRaw = json['themeMode'];
    final safeThemeMode =
        themeModeRaw is String &&
            (themeModeRaw == 'System' ||
                themeModeRaw == 'Light' ||
                themeModeRaw == 'Dark')
        ? themeModeRaw
        : 'System';

    final notificationTimeRaw = json['notificationTime'];
    final safeNotificationTime =
        notificationTimeRaw is String && notificationTimeRaw.trim().isNotEmpty
        ? notificationTimeRaw
        : '09:00 AM';

    final currencyRaw = json['currency'];
    final safeCurrency = currencyRaw is String && currencyRaw.trim().isNotEmpty
        ? currencyRaw
        : '₱';

    final appLockValue = json['appLock'];
    final biometricEnabledValue = json['biometricEnabled'];
    final gasNotificationDaysValue = json['gasNotificationDays'];
    final lastSeenWhatsNewVersionValue = json['lastSeenWhatsNewVersion'];
    final backupFolderPathValue = json['backupFolderPath'];
    final hideSchoolScheduleInCalendarValue =
        json['hideSchoolScheduleInCalendar'];

    return AppSettings(
      themeMode: safeThemeMode,
      userName: nameValue,
      nameSetupCompleted: setupDone,
      profileImagePath: json['profileImagePath'] is String
          ? json['profileImagePath'] as String
          : '',
      notificationTime: safeNotificationTime,
      currency: safeCurrency,
      appLock: appLockValue is bool ? appLockValue : false,
      biometricEnabled: biometricEnabledValue is bool
          ? biometricEnabledValue
          : false,
      gasNotificationDays: gasNotificationDaysValue is num
          ? gasNotificationDaysValue.toInt()
          : 3,
      lastSeenWhatsNewVersion: lastSeenWhatsNewVersionValue is String
          ? lastSeenWhatsNewVersionValue
          : '',
      backupFolderPath: backupFolderPathValue is String
          ? backupFolderPathValue
          : '',
      hideSchoolScheduleInCalendar: hideSchoolScheduleInCalendarValue is bool
          ? hideSchoolScheduleInCalendarValue
          : false,
    );
  }
}
