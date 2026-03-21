class PaymentReceipt {
  final String transactionId;
  final double amount;
  final String currency;
  final DateTime? paidAt;
  final String service;

  const PaymentReceipt({
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.paidAt,
    required this.service,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    return PaymentReceipt(
      transactionId: (json['transactionId'] ?? json['transaction_id'] ?? '').toString(),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      currency: (json['currency'] ?? 'LKR').toString(),
      paidAt: json['paidAt'] == null && json['paid_at'] == null
          ? null
          : DateTime.tryParse((json['paidAt'] ?? json['paid_at']).toString()),
      service: (json['service'] ?? 'Consultation payment').toString(),
    );
  }
}

class PaymentItem {
  final String id;
  final String appointmentId;
  final String gatewayTxnId;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final PaymentReceipt? receipt;

  const PaymentItem({
    required this.id,
    required this.appointmentId,
    required this.gatewayTxnId,
    required this.amount,
    required this.currency,
    required this.status,
    this.paidAt,
    this.receipt,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    final dynamic receiptJson = json['receipt'];
    return PaymentItem(
      id: (json['id'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? json['appointment_id'] ?? '').toString(),
      gatewayTxnId: (json['gatewayTxnId'] ?? json['gateway_txn_id'] ?? '').toString(),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      currency: (json['currency'] ?? 'LKR').toString(),
      status: (json['status'] ?? '').toString(),
      paidAt: json['paidAt'] == null && json['paid_at'] == null
          ? null
          : DateTime.tryParse((json['paidAt'] ?? json['paid_at']).toString()),
      receipt: receiptJson is Map<String, dynamic>
          ? PaymentReceipt.fromJson(receiptJson)
          : null,
    );
  }
}
