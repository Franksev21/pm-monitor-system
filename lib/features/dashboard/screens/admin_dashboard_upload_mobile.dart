import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

Future<void> pickAndUploadPhotoMobile({
  required BuildContext context,
  required FirebaseAuth auth,
  required FirebaseStorage storage,
  required FirebaseFirestore firestore,
  required Function(String url) onSuccess,
}) async {
  try {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image == null) return;

    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Subiendo foto...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final fileName =
        'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = storage.ref().child('profile_images/$fileName');
    await ref.putFile(File(image.path));
    final url = await ref.getDownloadURL();

    await firestore.collection('users').doc(uid).update({
      'profileImageUrl': url,
    });

    if (context.mounted) {
      Navigator.pop(context);
      onSuccess(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil actualizada'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
