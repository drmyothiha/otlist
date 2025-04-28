import 'package:flutter/material.dart';
import '../services/local_cache_service.dart';
import '../services/auth_service.dart'; // For API call

import 'package:http/http.dart' as http;

Future<bool> isServerReachable(String url) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 3));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

class AddOperationScreen extends StatefulWidget {
  final String token;
  final Function(String title, String details) onOperationAdded;

  const AddOperationScreen({
    super.key,
    required this.token,  // Add token here
    required this.onOperationAdded,
  });

  @override
  State<AddOperationScreen> createState() => _AddOperationScreenState();
}


class _AddOperationScreenState extends State<AddOperationScreen> {
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

Future<void> _submitOperation() async {
  final title = _titleController.text.trim();
  final details = _detailsController.text.trim();

  // Validate input
  if (title.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
    }
    return;
  }

  final operation = {
    'title': title,
    'details': details,
    'created_at': DateTime.now().toIso8601String(),
    'user_id': 1,
    'hospital_id': 1,
  };

  try {
    // Try to send to server if connected
    final success = await AuthService().addOperation(widget.token, title, details);
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operation added successfully')),
      );
    } else {
      // Save to local if no connection or server failed
      await LocalCacheService.saveOperation(operation);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved locally - will sync later')),
      );
    }
  } catch (e) {
    // Fallback safety
    await LocalCacheService.saveOperation(operation);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved locally. Error: ${e.toString()}')),
    );
  }

  // Notify parent and close
  widget.onOperationAdded(title, details);
  if (mounted) Navigator.pop(context);
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Operation")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(labelText: 'Details'),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitOperation,
              child: const Text("Add Operation"),
            )
          ],
        ),
      ),
    );
  }
}
