/// Qatar business calendar date — matches `public.current_business_date()` in Postgres.
DateTime qatarBusinessDate([DateTime? reference]) {
  final utc = (reference ?? DateTime.now()).toUtc();
  final qatar = utc.add(const Duration(hours: 3));
  return DateTime(qatar.year, qatar.month, qatar.day);
}

String formatBusinessDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatBusinessDateDisplay(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
