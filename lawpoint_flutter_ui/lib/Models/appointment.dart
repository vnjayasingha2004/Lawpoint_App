class Appointment {
  final String id;
  final String clientId;
  final String lawyerId;
  final DateTime start;
  final DateTime end;
  final String status;
  final String paymentStatus;
  final double amount;

  const Appointment({
    required this.id,
    required this.clientId,
    required this.lawyerId,
    required this.start,
    required this.end,
    required this.status,
    required this.paymentStatus,
    required this.amount,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    double parseAmount(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    return Appointment(
      id: (json['id'] ?? json['appointment_id'] ?? '').toString(),
      clientId: (json['client_id'] ?? json['clientId'] ?? '').toString(),
      lawyerId: (json['lawyer_id'] ?? json['lawyerId'] ?? '').toString(),
      start: parseDate(
        json['start_at'] ??
            json['startAt'] ??
            json['slot_start'] ??
            json['start'],
      ),
      end: parseDate(
        json['end_at'] ?? json['endAt'] ?? json['slot_end'] ?? json['end'],
      ),
      status: (json['status'] ?? 'SCHEDULED').toString(),
      paymentStatus:
          (json['payment_status'] ?? json['paymentStatus'] ?? 'PENDING')
              .toString(),
      amount: parseAmount(json['amount']),
    );
  }
}
