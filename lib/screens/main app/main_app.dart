import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/alerts_page.dart';
import '../shared/gallery_tab.dart';
import 'client/client_dashboard.dart';
import 'contractor/contractor_dashboard.dart';
import 'contractor/project_settings.dart';

class MainApp extends StatefulWidget {
  final String userRole; // 'contractor' or 'client'

  const MainApp({super.key, required this.userRole});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  int _unreadCount = 3; // TODO: Replace with real unread logic from Firestore

  String? _selectedProjectId;
  String? _selectedProjectName;
  String? _selectedMilestoneId;
  String? _selectedMilestoneTitle;

  late List<BottomNavigationBarItem> _navItems;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();

    // Get current user UID
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Bottom nav items
    if (widget.userRole == 'contractor') {
      _navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Projects'),
      ];
    } else {
      _navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications),
              if (_unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3D00), // Orange-Red badge
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          label: 'Alerts',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in"),),
      );
    }

    List<Widget> tabs;

    if (widget.userRole == 'contractor') {
      tabs = [
        ContractorDashboardTab(
          contractorId: _currentUserId!,
          onProjectSelected: (projectId, projectName) {
            setState(() {
              _selectedProjectId = projectId;
              _selectedProjectName = projectName;
              _currentIndex = 1; // switch to Alerts
            });
          },
        ),
        AlertsPage(userId: _currentUserId!, isClientView: false),
        ProjectSettingsTab(userId: _currentUserId!),
      ];
    } else {
      tabs = [
        ClientDashboardTab(
          clientId: _currentUserId!,
          onProjectSelected: (projectId, projectName) {
            setState(() {
              _selectedProjectId = projectId;
              _selectedProjectName = projectName;
              _currentIndex = 1;
            });
          },
        ),
        AlertsPage(userId: _currentUserId!, isClientView: true),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: _selectedProjectName == null
            ? Image.asset(
          'assets/design2.png',
          height: 36,
        )
            : Text(
          _selectedProjectName!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Colors.white
          ),
        ),
        leading: _selectedProjectId != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFF3D00)),
          onPressed: () {
            setState(() {
              _selectedProjectId = null;
              _selectedProjectName = null;
              _selectedMilestoneId = null;
              _selectedMilestoneTitle = null;
              _currentIndex = 0;
            });
          },
        )
            : null,
        actions: [
          if (_selectedProjectId == null)
            IconButton(
              icon: const Icon(Icons.person, color: Color(0xFFFF3D00)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
        ],

      ),
      body: SafeArea(child: tabs[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF007D7B), // Teal
        unselectedItemColor: const Color(0xFF002D5A).withOpacity(0.6), // Muted Dark Blue
        type: BottomNavigationBarType.fixed,
        items: _navItems,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }
}



class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _email;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
  }

  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _email = user.email;

    FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (mounted) {
          setState(() {
            _nameController.text = data["fullName"] ?? "";
          });
        }
      }
    });
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "fullName": _nameController.text,
      "email": _email,
    }, SetOptions(merge: true));

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF007D7B),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFF007D7B),
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _email ?? "",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(),
              ),
            ),

            const Spacer(),

            if (_isSaving) const CircularProgressIndicator(),
            if (!_isSaving)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007D7B),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.save, color: Colors.white,),
                label: const Text("Save Changes", style: TextStyle(color: Colors.white),),
                onPressed: _saveProfile,
              ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007D7B),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.exit_to_app, color: Colors.white,),
              label: const Text("Logout", style: TextStyle(color: Colors.white),),
              onPressed: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
