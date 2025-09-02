import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/progress_utils.dart';
import 'client_milestones_page.dart';

class ClientDashboardTab extends StatelessWidget {
  final String clientId;

  const ClientDashboardTab({
    Key? key,
    required this.clientId,
    required Null Function(dynamic projectId, dynamic projectName) onProjectSelected,
  }) : super(key: key);

  static const Color primaryDark = Color(0xFF002D5A);
  static const Color accentTeal = Color(0xFF007D7B);

  @override
  Widget build(BuildContext context) {
    final projectsRef = FirebaseFirestore.instance
        .collection('projects')
        .where('clientId', isEqualTo: clientId);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: projectsRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Error loading projects"));
            }
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: accentTeal));
            }

            final projects = snapshot.data!.docs;

            if (projects.isEmpty) {
              return const Center(
                child: Text(
                  "No projects assigned to you",
                  style: TextStyle(
                      color: primaryDark, fontWeight: FontWeight.w500),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Projects",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryDark,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final projectDoc = projects[index];
                      final projectData =
                      projectDoc.data() as Map<String, dynamic>;
                      final projectName =
                          projectData['name'] ?? "Unnamed Project";
                      final contractorId =
                          projectData['contractorId'] ?? "Unknown Contractor";

                      final totalBudget = (projectData['budget'] is int)
                          ? (projectData['budget'] as int).toDouble()
                          : (projectData['budget'] ?? 0.0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectDoc.id)
                              .collection('milestones')
                              .snapshots(),
                          builder: (context, milestoneSnapshot) {
                            if (!milestoneSnapshot.hasData) {
                              return const SizedBox();
                            }

                            final milestones = milestoneSnapshot.data!.docs;

                            // ✅ Only approved milestones count towards used budget
                            double usedBudget = 0;
                            for (var m in milestones) {
                              final mData = m.data() as Map<String, dynamic>;
                              final approved = mData['status'] == 'approved';
                              if (approved) {
                                final amountRaw = mData['amount'];
                                final amount = amountRaw is int
                                    ? amountRaw.toDouble()
                                    : (amountRaw is double ? amountRaw : 0.0);
                                usedBudget += amount;
                              }
                            }

                            final remainingBudget = totalBudget - usedBudget;
                            final progress =
                            ProgressUtils.calculateProgress(milestones);

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(contractorId)
                                  .get(),
                              builder: (context, contractorSnapshot) {
                                if (!contractorSnapshot.hasData) {
                                  return const ListTile(title: Text("Loading..."));
                                }

                                final contractorData = contractorSnapshot.data!
                                    .data() as Map<String, dynamic>?;
                                final contractorName =
                                    contractorData?['fullName'] ??
                                        "Unknown Contractor";

                                return ListTile(
                                  title: Text(
                                    projectName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryDark,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Contractor: $contractorName",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: progress,
                                        color: accentTeal,
                                        backgroundColor: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${(progress * 100).toStringAsFixed(0)}% Complete",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Total Budget: ₦${totalBudget.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: primaryDark,
                                            ),
                                          ),
                                          Text(
                                            "Remaining: ₦${remainingBudget.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: accentTeal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: primaryDark,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClientMilestonesPage(
                                          projectId: projectDoc.id,
                                          projectName: projectName,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
