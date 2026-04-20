enum ReportStatus {
  open('OPEN'),
  resolved('RESOLVED');

  const ReportStatus(this.apiValue);

  final String apiValue;

  static ReportStatus fromApiValue(String value) {
    return ReportStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => ReportStatus.open,
    );
  }

  String get label {
    switch (this) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.resolved:
        return 'Resolved';
    }
  }
}
