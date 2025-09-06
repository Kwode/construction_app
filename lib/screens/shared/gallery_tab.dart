import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:permission_handler/permission_handler.dart';

class GalleryTab extends StatefulWidget {
  final String? projectId;
  final String milestoneId;
  final bool isClientView;

  const GalleryTab({
    Key? key,
    this.projectId,
    required this.milestoneId,
    required this.isClientView,
  }) : super(key: key);

  @override
  State<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<GalleryTab> {
  String? _selectedProjectId;
  late String _selectedMilestoneId;
  bool _isAdmin = false;
  bool _isLoading = false;

  final cloudinary =
  CloudinaryPublic('diphueztd', 'flutter_unsigned', cache: false);
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.projectId;
    _selectedMilestoneId = widget.milestoneId;
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;
    final role = (doc.data() ?? const {})['role'] as String? ?? '';
    setState(() => _isAdmin = role == 'admin');
  }

  /// Recomputes milestone & project progress after changes
  Future<void> _recomputeMilestoneAndProject({
    required String projectId,
    required String milestoneId,
  }) async {
    final milestoneImagesSnap = await FirebaseFirestore.instance
        .collection('site_images')
        .where('milestoneId', isEqualTo: milestoneId)
        .get();

    final totalImages = milestoneImagesSnap.docs.length;
    final approvedImages = milestoneImagesSnap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['approved'] ?? false) == true;
    }).length;

    final milestoneRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId);

    await milestoneRef.set({
      'totalImages': totalImages,
      'approvedImages': approvedImages,
      'isCompleted': totalImages > 0 && approvedImages == totalImages,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final projectImagesSnap = await FirebaseFirestore.instance
        .collection('site_images')
        .where('projectId', isEqualTo: projectId)
        .get();

    final pTotal = projectImagesSnap.docs.length;
    final pApproved = projectImagesSnap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['approved'] ?? false) == true;
    }).length;

    final progress = pTotal == 0 ? 0.0 : (pApproved / pTotal);

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .update({'progress': progress});
  }

  Future<void> _uploadImage(ImageSource source) async {
    if (_selectedProjectId == null || _selectedMilestoneId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select a project & milestone first'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (source == ImageSource.camera) {
      var status = await Permission.camera.request();
      if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission denied',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    try {
      setState(() => _isLoading = true);

      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(pickedFile.path,
            resourceType: CloudinaryResourceType.Image),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Add image doc
      final docRef =
      await FirebaseFirestore.instance.collection('site_images').add({
        'url': response.secureUrl,
        'uploadedBy': user.uid,
        'projectId': _selectedProjectId,
        'milestoneId': _selectedMilestoneId,
        'caption': '',
        'timestamp': FieldValue.serverTimestamp(),
        'approved': false,
        'rejected': false,
      });

      // Recompute milestone + project metrics
      await _recomputeMilestoneAndProject(
        projectId: _selectedProjectId!,
        milestoneId: _selectedMilestoneId,
      );

      // 🔔 Create alert for client
      final projectDoc = await FirebaseFirestore.instance
          .collection("projects")
          .doc(_selectedProjectId)
          .get();

      final clientId = projectDoc.data()?["clientId"];
      final contractorId = projectDoc.data()?["contractorId"];
      final projectName = projectDoc.data()?["name"] ?? "";

// fetch milestone title like in _updateApproval
      final milestoneDoc = await FirebaseFirestore.instance
          .collection("projects")
          .doc(_selectedProjectId)
          .collection("milestones")
          .doc(_selectedMilestoneId)
          .get();

      final milestoneTitle = milestoneDoc.data()?["title"] ?? "Milestone";
      print("Project: $projectName, Milestone: $milestoneTitle");

// save alert
      await FirebaseFirestore.instance.collection("alerts").add({
        "type": "new_upload",
        "projectId": _selectedProjectId,
        "milestoneId": _selectedMilestoneId,
        "milestoneTitle": milestoneTitle,
        "projectName": projectName,
        "imageId": docRef.id,
        "clientId": clientId,
        "contractorId": contractorId,
        "timestamp": FieldValue.serverTimestamp(),
      });




      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded successfully!',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('Upload failed: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRejectedImage(
      BuildContext context, String docId, String imageUrl) async {
    try {
      // 1. Delete Firestore document
      await FirebaseFirestore.instance.collection('site_images').doc(docId).delete();

      // 2. Recompute milestone & project progress
      if (_selectedProjectId != null) {
        await _recomputeMilestoneAndProject(
          projectId: _selectedProjectId!,
          milestoneId: _selectedMilestoneId,
        );
      }

      // 3. Notify user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rejected image deleted'
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Error deleting rejected image: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: $e')),
        );
      }
    }
  }


  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Upload Image"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _uploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _uploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null || _selectedMilestoneId.isEmpty) {
      return const Center(child: Text('No project/milestone selected.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("GalleryTab", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007D7B),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('site_images')
            .where('projectId', isEqualTo: _selectedProjectId)
            .where('milestoneId', isEqualTo: _selectedMilestoneId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final photos = snapshot.data?.docs ?? [];
          if (photos.isEmpty) {
            return const Center(child: Text('No images found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: photos.length,
            itemBuilder: (_, index) {
              final doc = photos[index];
              final data = doc.data() as Map<String, dynamic>;
              final imageUrl = (data['url'] ?? '') as String;
              final caption = (data['caption'] ?? '') as String;
              final approved = (data['approved'] ?? false) as bool;
              final rejected = (data['rejected'] ?? false) as bool;

              // Image card widget
              final imageCard = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenImagePage(
                            imageUrl: imageUrl,
                            docRef: doc.reference,
                            isClientView: widget.isClientView,
                            approved: approved,
                            rejected: rejected,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            height: 250,
                            width: double.infinity,
                          ),
                        ),
                        if (!approved && !rejected)
                          _statusBadge("PENDING APPROVAL", Colors.redAccent),
                        if (rejected)
                          _statusBadge("REJECTED", Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(caption, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                ],
              );

              // If rejected, wrap in Slidable
              return rejected
                  ? Slidable(
                key: ValueKey(doc.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) async {
                        await _deleteRejectedImage(context, doc.id, imageUrl);
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: imageCard,
              )
                  : imageCard;
            },
          );

        },
      ),
      floatingActionButton: widget.isClientView
          ? null
          : FloatingActionButton(
        onPressed: _showUploadDialog,
        backgroundColor: const Color(0xFF007D7B),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class FullscreenImagePage extends StatefulWidget {
  final String imageUrl;
  final DocumentReference docRef;
  final bool isClientView;
  final bool approved;
  final bool rejected;

  const FullscreenImagePage({
    super.key,
    required this.imageUrl,
    required this.docRef,
    this.isClientView = false,
    this.approved = false,
    this.rejected = false,
  });

  @override
  State<FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<FullscreenImagePage> {
  bool _approved = false;
  bool _rejected = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _approved = widget.approved;
    _rejected = widget.rejected;

    // Move eviction to initState so we don't evict on every rebuild.
    CachedNetworkImage.evictFromCache(widget.imageUrl);
  }

  Future<void> _recomputeAfterApproval({
    required String projectId,
    required String milestoneId,
  }) async {
    // Recompute milestone totals from site_images
    final milestoneImagesSnap = await FirebaseFirestore.instance
        .collection('site_images')
        .where('milestoneId', isEqualTo: milestoneId)
        .get();

    final totalImages = milestoneImagesSnap.docs.length;
    final approvedImages = milestoneImagesSnap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['approved'] ?? false) == true;
    }).length;

    final milestoneRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('milestones')
        .doc(milestoneId);

    await milestoneRef.set({
      'totalImages': totalImages,
      'approvedImages': approvedImages,
      'isCompleted': totalImages > 0 && approvedImages == totalImages,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Recompute project progress from all site_images in this project
    final projectImagesSnap = await FirebaseFirestore.instance
        .collection('site_images')
        .where('projectId', isEqualTo: projectId)
        .get();

    final pTotal = projectImagesSnap.docs.length;
    final pApproved = projectImagesSnap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return (data['approved'] ?? false) == true;
    }).length;

    final progress = pTotal == 0 ? 0.0 : (pApproved / pTotal);

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .update({'progress': progress});
  }

  Future<void> _updateApproval(bool approve) async {
    setState(() => _isUpdating = true);

    try {
      final docSnap = await widget.docRef.get();
      if (!docSnap.exists) {
        debugPrint("Approval failed: image document does not exist.");
        return;
      }

      final data = docSnap.data() as Map<String, dynamic>;
      final projectId = data['projectId'] as String?;
      final milestoneId = data['milestoneId'] as String?;

      if (projectId == null || milestoneId == null) {
        debugPrint("Approval failed: missing projectId or milestoneId.");
        return;
      }

      String? rejectionReason;

      if (!approve) {
        // --- REJECTION FLOW ---
        final controller = TextEditingController();
        rejectionReason = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Reject Image"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "Enter reason"),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text("Submit"),
              ),
            ],
          ),
        );
        if (rejectionReason == null || rejectionReason.isEmpty) {
          setState(() => _isUpdating = false);
          return;
        }
      }

      // fetch milestone title
      final milestoneDoc = await FirebaseFirestore.instance
          .collection("projects")
          .doc(projectId)
          .collection("milestones")
          .doc(milestoneId)
          .get();
      final milestoneTitleFinal = milestoneDoc.data()?["title"] ?? "Milestone";

      // fetch contractorId from project
      final projectDoc = await FirebaseFirestore.instance
          .collection("projects")
          .doc(projectId)
          .get();
      final contractorId = projectDoc.data()?["contractorId"];

      // compute image position
      final imagesSnap = await FirebaseFirestore.instance
          .collection("site_images")
          .where("milestoneId", isEqualTo: milestoneId)
          .orderBy("timestamp")
          .get();
      final index = imagesSnap.docs.indexWhere((d) => d.id == widget.docRef.id);
      final imagePosition = (index >= 0) ? index + 1 : 1;

      final clientId = FirebaseAuth.instance.currentUser!.uid;

      // --- SAVE ALERT ---
      await FirebaseFirestore.instance.collection("alerts").add({
        "type": approve ? "approval" : "rejection",
        "projectId": projectId,
        "milestoneId": milestoneId,
        "milestoneTitle": milestoneTitleFinal,
        "imageId": widget.docRef.id,
        "imagePosition": imagePosition,
        if (!approve) "reason": rejectionReason,
        "clientId": clientId,
        "contractorId": contractorId,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // Update image doc
      await widget.docRef.update({
        'approved': approve,
        'rejected': !approve,
      });

      // Update milestone/project counts
      await _recomputeAfterApproval(projectId: projectId, milestoneId: milestoneId);

      if (!mounted) return;
      setState(() {
        _approved = approve;
        _rejected = !approve;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Image approved' : 'Image rejected'),
          backgroundColor: approve ? Colors.green : Colors.red,
        ),
      );
    } catch (e, st) {
      debugPrint("Approval failed: $e\n$st");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Hero(
                tag: widget.imageUrl,
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (_, __, ___) => const Center(child: Icon(Icons.error, color: Colors.red, size: 50)),
                  ),
                ),
              ),
            ),
          ),
          if (widget.isClientView && !_approved && !_rejected)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isUpdating
                  ? const CircularProgressIndicator()
                  : Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateApproval(true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('APPROVE', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateApproval(false),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('REJECT', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
