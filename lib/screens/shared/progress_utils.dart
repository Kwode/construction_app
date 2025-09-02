import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressUtils {
  /// Calculate progress as a value between 0.0 and 1.0
  static double calculateProgress(List<QueryDocumentSnapshot> milestones) {
    if (milestones.isEmpty) return 0.0;

    int completed = 0;
    for (var doc in milestones) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isCompleted'] == true) {   // ✅ use isCompleted instead of status
        completed++;
      }
    }

    return completed / milestones.length;
  }
}
