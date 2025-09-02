import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertsPage extends StatelessWidget {
  final String userId;
  final bool isClientView; // true = client, false = contractor

  const AlertsPage({
    Key? key,
    required this.userId,
    required this.isClientView,
  }) : super(key: key);

  static const Color primaryDark = Color(0xFF002D5A);
  static const Color accentTeal = Color(0xFF007D7B);

  @override
  Widget build(BuildContext context) {
    final alertsRef = FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          isClientView ? "Client Alerts" : "Contractor Alerts",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryDark,
          ),
        ),
        iconTheme: const IconThemeData(color: primaryDark),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: alertsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: accentTeal),
            );
          }

          final alerts = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // filter by clientId/contractorId
            if (isClientView) {
              return data['clientId'] == userId;
            } else {
              return data['contractorId'] == userId;
            }
          }).toList();

          if (alerts.isEmpty) {
            return const Center(child: Text("No alerts yet"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index].data() as Map<String, dynamic>;
              return _buildAlertTile(alert);
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertTile(Map<String, dynamic> alert) {
    final type = alert['type'] ?? '';
    final milestoneTitle = alert['milestoneTitle'] ?? '';
    final projectName = alert['projectName'] ?? '';
    final reason = alert['reason'] ?? '';
    final imagePosition = alert['imagePosition'];
    final timestamp = alert['timestamp'] as Timestamp?;

    String title = '';
    String message = '';
    Color color = Colors.grey;

    switch (type) {
      case 'ready_for_review':
        title = "Milestone Ready For Review";
        message =
        "Contractor marked '$milestoneTitle' in $projectName as ready for approval.";
        color = Colors.blue;
        break;

      case 'approval':
        title = "Image Approved";
        message =
        "The ${_ordinal(imagePosition)} image in '$milestoneTitle' was approved.";
        color = Colors.green;
        break;

      case 'rejection':
        title = "Image Rejected";
        message =
        "The ${_ordinal(imagePosition)} image in '$milestoneTitle' was rejected: $reason";
        color = Colors.red;
        break;

      case 'project_complete':
        title = "Project Completed";
        message = "$projectName has been completed successfully.";
        color = Colors.purple;
        break;

      case 'new_upload':
        title = "New image uploaded";
        message = "A new image was uploaded in '$milestoneTitle' in $projectName.";
        color = Colors.green;
        break;

      case 'project_added':
        title = "New Project Assigned";
        message =
        "$projectName has been created";
        color = Colors.orange;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 3,
      child: ListTile(
        leading: Icon(Icons.notifications, color: color),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (timestamp != null)
              Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }


  String _ordinal(dynamic number) {
    if (number == null) return '';
    final n = int.tryParse(number.toString()) ?? 0;
    if (n == 1) return "first";
    if (n == 2) return "second";
    if (n == 3) return "third";
    return "${n}th";
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
