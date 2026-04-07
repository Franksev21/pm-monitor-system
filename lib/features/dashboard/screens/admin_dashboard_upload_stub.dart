import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Stub para web — upload de foto no disponible
Future<void> pickAndUploadPhotoMobile({
  required BuildContext context,
  required FirebaseAuth auth,
  required FirebaseStorage storage,
  required FirebaseFirestore firestore,
  required Function(String url) onSuccess,
}) async {
  // No-op en web
}
