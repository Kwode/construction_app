import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ProjectSettingsTab extends StatelessWidget {
  const ProjectSettingsTab({super.key, required String userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Project Settings",
          style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF002D5A)
        ),
        ),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where(
          'contractorId',
          isEqualTo: FirebaseAuth.instance.currentUser!.uid,
        )
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No projects found"));
          }

          final projects = snapshot.data!.docs;

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final projectId = project.id;
              final projectData = project.data() as Map<String, dynamic>;

              final projectName = projectData['name'] ?? 'Unnamed Project';
              final budget = projectData['budget'] ?? 0;
              final clientId = projectData['clientId'];

              return Slidable(
                key: ValueKey(projectId),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) async {
                        await FirebaseFirestore.instance
                            .collection('projects')
                            .doc(projectId)
                            .delete();
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(projectName),
                  subtitle: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(clientId)
                        .get(),
                    builder: (context, clientSnapshot) {
                      if (clientSnapshot.connectionState == ConnectionState.waiting) {
                        return const Text("Loading client...");
                      }
                      if (!clientSnapshot.hasData || !clientSnapshot.data!.exists) {
                        return const Text("Client not found");
                      }

                      final clientData = clientSnapshot.data!.data() as Map<String, dynamic>;
                      final clientName = clientData['name'] ??
                          clientData['email'] ??
                          "Unknown Client";

                      return Text("Client: $clientName • Budget: ₦$budget");
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProjectScreen(projectId: projectId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ), 
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF007D7B),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddProjectScreen(
                projectsRef: FirebaseFirestore.instance.collection('projects'),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),

    );
  }
}



class AddProjectScreen extends StatefulWidget {
  final CollectionReference projectsRef;

  const AddProjectScreen({super.key, required this.projectsRef});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _budgetController = TextEditingController();
  final contractorId = FirebaseAuth.instance.currentUser!.uid;

  bool _isLoading = false;

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final budgetText = _budgetController.text.trim();
    final budget = double.tryParse(budgetText) ?? 0.0;

    try {
      // Look up client by email
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'client')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Client not found. Ask them to sign up.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      final clientId = query.docs.first.id;

      // Create project with budget + balance
      await widget.projectsRef.add({
        "name": name,
        "clientId": clientId,
        "contractorId": contractorId,
        "budget": budget,
        "balance": budget,
        "progress": 0.0,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // save alert
      await FirebaseFirestore.instance.collection("alerts").add({
        "type": "project_added",
        "projectName": name,
        "clientId": clientId,
        "contractorId": contractorId,
        "timestamp": FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error creating project: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Project", style: TextStyle(color: Colors.white)),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Project Name"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter project name" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Client Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter client email" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: "Project Budget (₦)"),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ? "Enter project budget" : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007D7B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _isLoading ? null : _createProject,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Project"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProjectScreen extends StatefulWidget {
  final String projectId;

  const EditProjectScreen({super.key, required this.projectId});

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjectData();
  }

  void _loadProjectData() async {
    final doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .get();

    if (doc.exists) {
      setState(() {
        _nameController.text = doc['name'] ?? '';
        _budgetController.text = doc['budget']?.toString() ?? '';
      });
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
        'name': _nameController.text,
        'budget': double.tryParse(_budgetController.text) ?? 0.0,
      });

      Navigator.pop(context); // go back after saving
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
        const Text("Edit Project", style: TextStyle(color: Colors.white)),
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
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Project Name"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter name" : null,
              ),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Budget"),
                validator: (value) =>
                value == null || value.isEmpty ? "Enter budget" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007D7B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _saveChanges,
                child: const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
