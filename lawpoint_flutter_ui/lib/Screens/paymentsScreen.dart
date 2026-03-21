import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/paymentRepository.dart';
import '../Models/payment.dart';
import '../Widgets/ui.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & Receipts')),
      body: FutureBuilder<List<PaymentItem>>(
        future: context.read<PaymentRepository>().getMyPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(icon: Icons.receipt_long_rounded, title: 'No payments yet', message: 'Successful consultation payments and receipts will appear here.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Appointment ${item.appointmentId}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          StatusPill(item.status, color: statusColor(item.status)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Amount: ${item.currency} ${item.amount.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      Text('Transaction: ${item.gatewayTxnId}'),
                      if (item.paidAt != null) ...[
                        const SizedBox(height: 4),
                        Text('Paid at: ${friendlyDateTime(item.paidAt!)}'),
                      ],
                      if (item.receipt != null) ...[
                        const SizedBox(height: 12),
                        Text('Receipt service: ${item.receipt!.service}'),
                      ],
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
