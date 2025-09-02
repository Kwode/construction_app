import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/milestones_page.dart';
import '../../shared/progress_utils.dart';

class ContractorDashboardTab extends StatelessWidget {
  final String contractorId;
  final void Function(String projectId, String projectName) onProjectSelected;

  const ContractorDashboardTab({
    super.key,
    required this.contractorId,
    required this.onProjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    final CollectionReference projectsRef =
    FirebaseFirestore.instance.collection('projects');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white
      ),
      child: Container(
        color: Colors.white.withOpacity(0.85), // overlay for readability
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: projectsRef
                .where('contractorId', isEqualTo: contractorId)
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading projects"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final projects = snapshot.data!.docs;

              if (projects.isEmpty) {
                return const Center(
                  child: Text("No projects assigned yet."),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Contractor Dashboard",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002D5A), // Dark Blue
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
                        final clientId =
                            projectData['clientId'] ?? "Unknown Client";

                        final totalBudget = (projectData['budget'] is int)
                            ? (projectData['budget'] as int).toDouble()
                            : (projectData['budget'] ?? 0.0);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
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

                              double usedBudget = 0;
                              for (var m in milestones) {
                                final mData = m.data() as Map<String, dynamic>;
                                final amountRaw = mData['amount'];
                                final amount = amountRaw is int
                                    ? amountRaw.toDouble()
                                    : (amountRaw is double ? amountRaw : 0.0);
                                usedBudget += amount;
                              }

                              final remainingBudget = totalBudget - usedBudget;
                              final progress =
                              ProgressUtils.calculateProgress(milestones);

                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(clientId)
                                    .get(),
                                builder: (context, clientSnapshot) {
                                  if (clientSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const ListTile(
                                        title: Text("Loading..."));
                                  }

                                  final clientData = clientSnapshot.data?.data()
                                  as Map<String, dynamic>?;
                                  final clientName =
                                      clientData?['fullName'] ??
                                          "Unknown Client";

                                  return ListTile(
                                    title: Text(
                                      projectName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF002D5A), // Dark Blue
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Client: $clientName",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            color: const Color(0xFF007D7B), // Teal
                                            backgroundColor:
                                            Colors.grey[300],
                                            minHeight: 6,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "${(progress * 100).toStringAsFixed(0)}% Complete",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Total Budget: ₦$totalBudget",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF002D5A)),
                                        ),
                                        Text(
                                          "Remaining: ₦$remainingBudget",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFFF3D00), // Orange-Red
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Color(0xFF007D7B), // Teal
                                    ),
                                    onTap: () {
                                      onProjectSelected(
                                          projectDoc.id, projectName);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MilestonesPage(
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
      ),
    );
  }
}
