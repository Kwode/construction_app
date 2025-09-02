import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/gallery_tab.dart';

class MilestonesPage extends StatelessWidget {
  final String projectId;
  final String projectName;

  const MilestonesPage({
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
      backgroundColor: Colors.white,
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
          if (!projectSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final projectData = projectSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final totalBudget = (projectData['budget'] ?? 0.0).toDouble();

          return StreamBuilder<QuerySnapshot>(
            stream: milestonesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error loading milestones"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final milestones = snapshot.data!.docs;

              if (milestones.isEmpty) {
                return Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMilestoneScreen(projectId: projectId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Color(0xFF007D7B)), // teal
                    label: const Text(
                      "Add First Milestone",
                      style: TextStyle(color: Color(0xFF007D7B)),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: milestones.length + 1,
                itemBuilder: (context, index) {
                  if (index == milestones.length) {
                    return TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMilestoneScreen(projectId: projectId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, color: Color(0xFF007D7B)),
                      label: const Text(
                        "Add Milestone",
                        style: TextStyle(color: Color(0xFF007D7B)),
                      ),
                    );
                  }

                  final m = milestones[index];
                  final mData = m.data() as Map<String, dynamic>;

                  final title = mData['title'] ?? 'Unnamed Milestone';
                  final description = mData['description'] ?? '';
                  final rawAmount = mData['amount'];
                  final double amount = rawAmount is int
                      ? rawAmount.toDouble()
                      : (rawAmount is double ? rawAmount : 0.0);
                  final isApproved = mData['isApproved'] ?? false;
                  final isReadyForReview = mData['isReadyForReviewByContractor'] ?? false;
                  final isCompleted = mData['isCompleted'] ?? false;
                  final milestoneId = m.id;

                  // Calculate allocation percentage
                  final allocationPercent = totalBudget > 0 ? (amount / totalBudget * 100) : 0;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('site_images')
                        .where('milestoneId', isEqualTo: milestoneId)
                        .snapshots(),
                    builder: (context, imagesSnapshot) {
                      if (imagesSnapshot.hasError) return const ListTile(title: Text("Error loading images"));
                      if (!imagesSnapshot.hasData) return const ListTile(title: Text("Loading..."));

                      final images = imagesSnapshot.data!.docs;
                      final totalImages = images.length;

                      String statusText;
                      if (isCompleted) {
                        statusText = "Completed";
                      } else if (isReadyForReview) {
                        statusText = "Ready for Review";
                      } else {
                        statusText = "Pending";
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(title),
                              subtitle: Text(
                                "$description\nAmount: ₦${amount.toStringAsFixed(2)} | Allocation: ${allocationPercent.toStringAsFixed(1)}%\nStatus: $statusText",
                              ),
                              isThreeLine: true,
                              trailing: Icon(
                                isCompleted ? Icons.check_circle : Icons.pending,
                                color: isCompleted ? Colors.green : Colors.grey,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GalleryTab(
                                      projectId: projectId,
                                      milestoneId: milestoneId,
                                      isClientView: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (!isReadyForReview && !isCompleted && totalImages > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('projects')
                                        .doc(projectId)
                                        .collection('milestones')
                                        .doc(milestoneId)
                                        .update({'isReadyForReviewByContractor': true});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Milestone marked as ready for review!'),
                                        backgroundColor: Color(0xFF007D7B), // teal
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007D7B), // dark blue
                                  ),
                                  child: const Text(
                                    'Mark as Ready for Review',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            if (!isReadyForReview && !isCompleted && totalImages == 0)
                              const Padding(
                                padding: EdgeInsets.only(left: 16, bottom: 12),
                                child: Text(
                                  "Upload at least one image to mark milestone ready for review",
                                  style: TextStyle(color: Color(0xFFFF3D00)), // orange-red warning
                                ),
                              ),
                          ],
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


class AddMilestoneScreen extends StatefulWidget {
  final String projectId;

  const AddMilestoneScreen({super.key, required this.projectId});

  @override
  State<AddMilestoneScreen> createState() => _AddMilestoneScreenState();
}

class _AddMilestoneScreenState extends State<AddMilestoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isLoading = false;
  double? _totalBudget;
  double _usedBudget = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchBudgetInfo();
  }

  Future<void> _fetchBudgetInfo() async {
    try {
      final projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (!projectDoc.exists) return;

      final totalBudgetRaw = projectDoc.data()?['budget'] ?? 0;
      _totalBudget = totalBudgetRaw is int ? totalBudgetRaw.toDouble() : totalBudgetRaw;

      final milestonesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .get();

      double used = 0.0;
      for (var m in milestonesSnapshot.docs) {
        final amt = m.data()['amount'];
        if (amt is int) used += amt.toDouble();
        else if (amt is double) used += amt;
      }

      setState(() => _usedBudget = used);
    } catch (e) {
      debugPrint("Error fetching budget info: $e");
    }
  }

  Future<void> _createMilestone() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final remaining = (_totalBudget ?? 0) - _usedBudget;
    if (amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot exceed remaining budget: ₦${remaining.toStringAsFixed(2)}"),
          backgroundColor: const Color(0xFFFF3D00), // orange-red
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('milestones')
          .add({
        "title": title,
        "description": desc,
        "amount": amount,
        "isApproved": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error creating milestone: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingBudget = (_totalBudget ?? 0) - _usedBudget;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Milestone", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007D7B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_totalBudget != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "Remaining Budget: ₦${remainingBudget.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF007D7B)), // teal
                  ),
                ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Milestone Title"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter milestone title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: "Description"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter description" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Milestone Amount (₦)"),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter milestone amount";
                  final amt = double.tryParse(value);
                  if (amt == null) return "Enter a valid number";
                  if (_totalBudget != null && amt > remainingBudget) {
                    return "Exceeds remaining budget: ₦${remainingBudget.toStringAsFixed(2)}";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007D7B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _isLoading ? null : _createMilestone,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Milestone"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
