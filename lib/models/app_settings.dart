class AppSettings {
  final bool notificationsEnabled;
  final bool dailyReminderEnabled;
  final bool forecastWarningsEnabled;
  final double lowBalanceThreshold;

  const AppSettings({
    required this.notificationsEnabled,
    required this.dailyReminderEnabled,
    required this.forecastWarningsEnabled,
    required this.lowBalanceThreshold,
  });

  static const defaults = AppSettings(
    notificationsEnabled: true,
    dailyReminderEnabled: true,
    forecastWarningsEnabled: true,
    lowBalanceThreshold: 200000,
  );

  factory AppSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return AppSettings(
      notificationsEnabled: data['notifications_enabled'] != false,
      dailyReminderEnabled: data['daily_reminder_enabled'] != false,
      forecastWarningsEnabled: data['forecast_warnings_enabled'] != false,
      lowBalanceThreshold:
          (data['low_balance_threshold'] as num?)?.toDouble() ?? 200000,
    );
  }

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? dailyReminderEnabled,
    bool? forecastWarningsEnabled,
    double? lowBalanceThreshold,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      forecastWarningsEnabled:
          forecastWarningsEnabled ?? this.forecastWarningsEnabled,
      lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
    );
  }

  Map<String, dynamic> toMap() => {
    'notifications_enabled': notificationsEnabled,
    'daily_reminder_enabled': dailyReminderEnabled,
    'forecast_warnings_enabled': forecastWarningsEnabled,
    'low_balance_threshold': lowBalanceThreshold,
  };
}
