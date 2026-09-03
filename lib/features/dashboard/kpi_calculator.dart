/// Injury-rate KPI math per the standards named in the app spec.
///
/// - ANSI Z16.1 / OSHA convention bases the rate on 200,000 hours
///   (100 employees × 40 hrs/week × 50 weeks — "per 100 full-time workers").
/// - ISO 45001's international convention instead bases it on 1,000,000
///   hours worked. Both are exposed so a site can report either way; default
///   is the US/ANSI base since OSHA recordkeeping is named first in the spec.
class KpiCalculator {
  KpiCalculator._();

  static const int ansiOshaBase = 200000;
  static const int isoInternationalBase = 1000000;

  /// Lost Time Injury Frequency Rate.
  static double calculateLTIFR({
    required int lostTimeInjuries,
    required double totalHoursWorked,
    int base = ansiOshaBase,
  }) {
    if (totalHoursWorked <= 0) return 0;
    return (lostTimeInjuries * base) / totalHoursWorked;
  }

  /// Total Recordable Incident Rate — OSHA recordkeeping always uses the
  /// 200,000-hour base regardless of which base LTIFR is reported against.
  static double calculateTRIR({
    required int recordableIncidents,
    required double totalHoursWorked,
  }) {
    if (totalHoursWorked <= 0) return 0;
    return (recordableIncidents * ansiOshaBase) / totalHoursWorked;
  }
}
