import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUser(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).set(data);
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    return doc.data();
  }

  Future<UserModel?> getUserModel(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Stream<Map<String, dynamic>?> streamUser(String uid) {
    return _db
        .collection("users")
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<UserModel>> streamUsers() {
    return _db
        .collection("users")
        .orderBy("name")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> collectionStream(
    String collectionPath,
  ) {
    return _db.collection(collectionPath).snapshots();
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).update(data);
  }

  Future<void> updateUserRole(String uid, String role) async {
    await _db.collection("users").doc(uid).update({'role': role});
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    await _db.collection("users").doc(uid).update({
      'name': name,
      'email': email,
    });
  }

  Future<void> setUserActive(String uid, bool isActive) async {
    await _db.collection("users").doc(uid).update({'isActive': isActive});
  }

  Future<void> softDeleteUser(String uid) async {
    await _db.collection("users").doc(uid).update({
      'isActive': false,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String uid) async {
    await _db.collection("users").doc(uid).delete();
  }
}
