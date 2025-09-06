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
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true); // Added ordering like contractor

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
                    color: primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
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

                      // Ensure total budget is always a double
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
                            if (milestoneSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                title: Text("Loading milestones..."),
                              );
                            }

                            if (!milestoneSnapshot.hasData ||
                                milestoneSnapshot.data!.docs.isEmpty) {
                              return ListTile(
                                title: Text(projectName),
                                subtitle: const Text(
                                  "No milestones yet",
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: accentTeal,
                                ),
                              );
                            }

                            final milestones = milestoneSnapshot.data!.docs;

                            // ✅ Unified Budget Calculation
                            double usedBudget = 0;
                            for (var m in milestones) {
                              final mData = m.data() as Map<String, dynamic>;

                              final amountRaw = mData['amount'];
                              final amount = double.tryParse(
                                  amountRaw?.toString() ?? '0') ??
                                  0.0;

                              usedBudget += amount;
                            }

                            final remainingBudget = totalBudget - usedBudget;

                            // ✅ Use the same progress calculation utility
                            final progress =
                            ProgressUtils.calculateProgress(milestones);

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(contractorId)
                                  .snapshots(),
                              builder: (context, contractorSnapshot) {
                                if (!contractorSnapshot.hasData ||
                                    !contractorSnapshot.data!.exists) {
                                  return const ListTile(
                                      title: Text("Loading contractor..."));
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
                                      // Contractor info
                                      Text(
                                        "Contractor: $contractorName",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Progress Bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          color: accentTeal,
                                          backgroundColor: Colors.grey[300],
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // Percentage complete
                                      Text(
                                        "${(progress * 100).toStringAsFixed(0)}% Complete",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),

                                      // Budget Details
                                      Text(
                                        "Total Budget: ₦${totalBudget.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: primaryDark,
                                        ),
                                      ),
                                      Text(
                                        "Remaining: ₦${remainingBudget.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFF3D00),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: accentTeal,
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
