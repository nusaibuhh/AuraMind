import 'package:flutter/material.dart';

class ConsultationPaymentChoice {
  const ConsultationPaymentChoice({
    required this.method,
    required this.phone,
  });

  final String method;
  final String phone;
}

Future<ConsultationPaymentChoice?> showConsultationPaymentSheet(
  BuildContext context, {
  required double amount,
  String currency = 'BDT',
}) async {
  final phoneController = TextEditingController();
  var method = 'bkash';
  String? validationMessage;

  final result = await showModalBottomSheet<ConsultationPaymentChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Make payment',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Amount: $currency ${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            const Text(
              'Preferred payment method',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ('bkash', 'bKash', Icons.phone_android_rounded),
                ('nagad', 'Nagad', Icons.account_balance_wallet_rounded),
                ('bank_card', 'Bank card', Icons.credit_card_rounded),
              ].map((option) {
                return ChoiceChip(
                  avatar: Icon(option.$3, size: 18),
                  label: Text(option.$2),
                  selected: method == option.$1,
                  onSelected: (_) => setSheetState(() {
                    method = option.$1;
                    validationMessage = null;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile number',
                hintText: '01XXXXXXXXX',
                errorText: validationMessage,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will continue to SSLCommerz’s secure hosted checkout. '
              'Available methods depend on the merchant account.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Continue to secure payment'),
                onPressed: () {
                  final phone = phoneController.text.trim();
                  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 10 || digits.length > 15) {
                    setSheetState(() {
                      validationMessage = 'Enter a valid mobile number';
                    });
                    return;
                  }
                  Navigator.pop(
                    sheetContext,
                    ConsultationPaymentChoice(method: method, phone: phone),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  phoneController.dispose();
  return result;
}
