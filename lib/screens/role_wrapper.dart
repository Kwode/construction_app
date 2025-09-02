import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/sign_in_page.dart';
import 'main app/main_app.dart';

class RoleWrapper extends StatelessWidget {
  const RoleWrapper({super.key});

  Future<String?> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc['role'] as String?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          // If no role found or user signed out → back to sign in
          return const SignInPage();
        }

        final role = snapshot.data!;
        return MainApp(userRole: role);
      },
    );
  }
}
