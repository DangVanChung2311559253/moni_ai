import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ai_analysis_models.dart';

class AnomalyAlertStore {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('anomaly_alerts');

  Future<List<AnomalyAlertRecord>> getAll(String userId) async {
    if (userId.isEmpty) return [];
    final snapshot = await _collection(userId).get();
    final records = snapshot.docs.map((doc) {
      final data = doc.data();
      final rawDate = data['date'];
      return AnomalyAlertRecord(
        amount: (data['amount'] as num).toDouble(),
        category: data['category'].toString(),
        date: rawDate is Timestamp
            ? rawDate.toDate()
            : DateTime.parse(rawDate.toString()),
        severity: data['severity'].toString(),
        reason: data['reason'].toString(),
        status: data['status'].toString(),
      );
    }).toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  Future<void> add(String userId, AnomalyAlertRecord record) async {
    if (userId.isEmpty) return;
    await _collection(userId).add({
      'amount': record.amount,
      'category': record.category,
      'date': Timestamp.fromDate(record.date),
      'severity': record.severity,
      'reason': record.reason,
      'status': record.status,
      'created_at': FieldValue.serverTimestamp(),
    });
    changes.value++;
  }
}
