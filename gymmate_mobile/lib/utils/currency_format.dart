import 'package:intl/intl.dart';

/// Single source of truth for rendering money. Uses the en_IN locale so values
/// group the Indian way (₹1,00,000) and always carry the ₹ symbol.
///
/// [decimals] defaults to 0 (membership plan prices show whole rupees); pass 2
/// for receipts/payments where paise matter. Accepts num, numeric String, or
/// null (renders ₹0).
String formatINR(dynamic amount, {int decimals = 0}) {
  final value = amount is num
      ? amount
      : num.tryParse(amount?.toString() ?? '') ?? 0;
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimals,
  );
  return format.format(value);
}
