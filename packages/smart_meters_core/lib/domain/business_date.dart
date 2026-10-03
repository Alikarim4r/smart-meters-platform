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

String localizeDigits(String input, {required String languageCode}) {
  if (!languageCode.toLowerCase().startsWith('ar')) return input;
  const western = '0123456789';
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final i = western.indexOf(ch);
    out.write(i < 0 ? ch : arabicIndic[i]);
  }
  return out.toString();
}

String formatBusinessDateDisplay(DateTime date, {String languageCode = 'en'}) {
  const monthsEn = [
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
  const monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  final ar = languageCode.toLowerCase().startsWith('ar');
  final raw = ar
      ? '${date.day} ${monthsAr[date.month - 1]} ${date.year}'
      : '${monthsEn[date.month - 1]} ${date.day}, ${date.year}';
  return localizeDigits(raw, languageCode: languageCode);
}
