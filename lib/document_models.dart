

class OrderDocument {
  final String uuid;
  final String number;
  final String date;
  final String customerName;
  final String status;
  final double amount;

  OrderDocument({
    required this.uuid,
    required this.number,
    required this.date,
    required this.customerName,
    required this.status,
    required this.amount,
  });

  factory OrderDocument.fromJson(Map<String, dynamic> json) {
    return OrderDocument(
      uuid: json['uuid'] ?? '',
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      customerName: json['customer_name'] ?? '',
      status: json['status'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class SaleDocument {
  final String uuid;
  final String number;
  final String date;
  final String customerName;
  final double amount;

  SaleDocument({
    required this.uuid,
    required this.number,
    required this.date,
    required this.customerName,
    required this.amount,
  });

  factory SaleDocument.fromJson(Map<String, dynamic> json) {
    return SaleDocument(
      uuid: json['uuid'] ?? '',
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      customerName: json['customer_name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

class IncomeDocument {
  final String uuid;
  final String number;
  final String date;
  final String customerName;

  IncomeDocument({
    required this.uuid,
    required this.number,
    required this.date,
    required this.customerName,
  });

  factory IncomeDocument.fromJson(Map<String, dynamic> json) {
    return IncomeDocument(
      uuid: json['uuid'] ?? '',
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      customerName: json['customer_name'] ?? '',
    );
  }
}

class ExpenseDocument {
  final String uuid;
  final String number;
  final String date;
  final String customerName;

  ExpenseDocument({
    required this.uuid,
    required this.number,
    required this.date,
    required this.customerName,
  });

  factory ExpenseDocument.fromJson(Map<String, dynamic> json) {
    return ExpenseDocument(
      uuid: json['uuid'] ?? '',
      number: json['number'] ?? '',
      date: json['date'] ?? '',
      customerName: json['customer_name'] ?? '',
    );
  }
}