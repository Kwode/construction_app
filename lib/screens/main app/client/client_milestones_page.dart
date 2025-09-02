import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/gallery_tab.dart';

class ClientMilestonesPage extends StatelessWidget {
  final String projectId;
  final String projectName;

  const ClientMilestonesPage({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final milestonesRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .orderBy('createdAt', descending: false);

    return Scaffold(
      backgroundColor:Colors.white,
      appBar: AppBar(
        title: Text(projectName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007D7B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('projects').doc(projectId).get(),
        builder: (context, projectSnapshot) {
          if (!projectSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final projectData = projectSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final totalBudget = (projectData['budget'] ?? 0.0).toDouble();

          return StreamBuilder<QuerySnapshot>(
            stream: milestonesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error loading milestones"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final milestones = snapshot.data!.docs;

              if (milestones.isEmpty) {
                return const Center(child: Text("No milestones yet"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: milestones.length,
                itemBuilder: (context, index) {
                  final m = milestones[index];
                  final mData = m.data() as Map<String, dynamic>;

                  final title = mData['title'] ?? 'Unnamed Milestone';
                  final milestoneAmount = (mData['amount'] ?? 0.0).toDouble();
                  final isMarkedComplete = mData['isReadyForReviewByContractor'] ?? false;

                  // Calculate dynamic budget percentage
                  final budgetPercent = totalBudget > 0 ? (milestoneAmount / totalBudget * 100) : 0;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('site_images')
                        .where('milestoneId', isEqualTo: m.id)
                        .snapshots(),
                    builder: (context, imagesSnapshot) {
                      if (imagesSnapshot.hasError) return const ListTile(title: Text("Error loading milestone images"));
                      if (!imagesSnapshot.hasData) return const ListTile(title: Text("Loading..."));

                      final images = imagesSnapshot.data!.docs;
                      final totalImages = images.length;
                      final approvedImages = images.where((img) {
                        final data = img.data() as Map<String, dynamic>;
                        return (data['approved'] ?? false) == true;
                      }).length;

                      final allImagesApproved = totalImages > 0 && approvedImages == totalImages;

                      // Determine milestone status
                      String statusText;
                      Color statusColor;
                      if (totalImages == 0) {
                        statusText = "Pending";
                        statusColor = Colors.orange;
                      } else if (allImagesApproved) {
                        statusText = "Approved";
                        statusColor = Colors.green;
                      } else if (isMarkedComplete) {
                        statusText = "Ready for Review";
                        statusColor = Colors.blue;
                      } else {
                        statusText = "Pending";
                        statusColor = Colors.orange;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              totalImages > 0
                                  ? Text(
                                "$approvedImages / $totalImages images approved",
                                style: TextStyle(color: statusColor),
                              )
                                  : const Text(
                                "No images uploaded yet",
                                style: TextStyle(color: Colors.orange),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Amount: ₦${milestoneAmount.toStringAsFixed(2)} | Allocation: ${budgetPercent.toStringAsFixed(1)}%",
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              if (!allImagesApproved && totalImages > 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Waiting for your approval",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GalleryTab(
                                  projectId: projectId,
                                  milestoneId: m.id,
                                  isClientView: true,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
