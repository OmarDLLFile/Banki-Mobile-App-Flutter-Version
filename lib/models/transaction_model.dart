class TransactionModel {
  final String id;
  final String userId;
  final String type;
  final double amount;
  final String billType;
  final DateTime timestamp;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.billType,
    required this.timestamp,
  });



  factory TransactionModel.fromMap(Map<String, dynamic> data, String id) {
    return TransactionModel(
      id: id,
      userId: data['userId'],
      type: data['type'],
      amount: (data['amount']).toDouble(),
      billType: data['billType'] ?? '',
      timestamp: DateTime.parse(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'amount': amount,
      'billType': billType,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}