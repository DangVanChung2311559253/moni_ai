import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_settings.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _document(String userId) {
    if (userId.isEmpty) throw StateError('Người dùng chưa đăng nhập.');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('app');
  }

  Future<AppSettings> get(String userId) async {
    final snapshot = await _document(userId).get();
    return AppSettings.fromMap(snapshot.data());
  }

  Stream<AppSettings> watch(String userId) {
    if (userId.isEmpty) return Stream.value(AppSettings.defaults);
    return _document(
      userId,
    ).snapshots().map((snapshot) => AppSettings.fromMap(snapshot.data()));
  }

  Future<void> save(String userId, AppSettings settings) {
    return _document(userId).set({
      ...settings.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
