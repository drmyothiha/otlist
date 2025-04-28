import 'package:flutter/material.dart';
import 'package:modern_auth_app/services/auth_service.dart';
import 'login_screen.dart';
import 'add_operation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../services/local_cache_service.dart';

class OperationsScreen extends StatefulWidget {
  final String token;

  const OperationsScreen({super.key, required this.token});

  @override
  _OperationsScreenState createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  late Future<List<dynamic>> _operations;
  List<dynamic> _selectedOperations = [];
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _operations = _fetchOperations();
  }

  Future<List<dynamic>> _fetchOperations() async {
    final authService = AuthService();
    final prefs = await SharedPreferences.getInstance();

    try {
      final data = await authService.fetchOperations(widget.token);
      await prefs.setString('cached_operations', jsonEncode(data));
      return data;
    } catch (e) {
      final cached = prefs.getString('cached_operations');
      if (cached != null) {
        return jsonDecode(cached);
      } else {
        throw Exception('Unable to load data. Please check your internet connection.');
      }
    }
  }

  Future<void> _refreshOperations() async {
    await _syncOfflineOperations();
    setState(() {
      _operations = _fetchOperations();
    });
  }

  Future<void> _syncOfflineOperations() async {
    if (!await InternetConnectionChecker().hasConnection) return;

    final unsyncedOps = await LocalCacheService.getCachedOperations();
    if (unsyncedOps.isEmpty) return;

    bool anySyncFailed = false;
    int successfulSyncs = 0;

    for (final op in unsyncedOps) {
      if (!await InternetConnectionChecker().hasConnection) {
        anySyncFailed = true;
        debugPrint("⏸️ Sync paused - lost internet connection");
        break;
      }

      final success = await AuthService().addOperation(
        widget.token,
        op['title'] as String,
        op['details'] as String,
      );

      if (success) {
        await LocalCacheService.removeOperation(op);
        successfulSyncs++;
      } else {
        anySyncFailed = true;
        debugPrint("❌ Failed to sync operation: ${op['title']}");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          anySyncFailed
            ? 'Synced $successfulSyncs operations (some failed)'
            : 'Successfully synced $successfulSyncs operations',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _navigateToAddOperation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddOperationScreen(
          token: widget.token,
          onOperationAdded: (title, details) async {
            await _refreshOperations();
          },
        ),
      ),
    );
    await _refreshOperations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelecting 
            ? Text('${_selectedOperations.length} selected')
            : const Text("Operations"),
        actions: [
          if (_isSelecting)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDeleteSelected,
              tooltip: 'Delete Selected',
            ),
          IconButton(
            icon: _isSelecting 
                ? const Icon(Icons.close)
                : const Icon(Icons.logout),
            onPressed: _isSelecting ? _cancelSelection : _logout,
            tooltip: _isSelecting ? 'Cancel' : 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOperations,
        child: FutureBuilder<List<dynamic>>(
          future: _operations,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No operations found.'));
            }

            final operations = snapshot.data!;
            return ListView.builder(
              itemCount: operations.length,
              itemBuilder: (context, index) {
                final operation = operations[index];
                final isSelected = _selectedOperations.contains(operation);

                return ListTile(
                  title: Text(operation['title']),
                  subtitle: Text(operation['details']),
                  trailing: _isSelecting
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleOperationSelection(operation),
                        )
                      : Text(operation['created_at']),
                  onLongPress: () => _startSelection(operation),
                  onTap: () => _isSelecting 
                      ? _toggleOperationSelection(operation)
                      : _viewOperationDetails(operation),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              onPressed: _navigateToAddOperation,
              tooltip: 'Add Operation',
              child: const Icon(Icons.add),
            ),
    );
  }

  void _startSelection(dynamic operation) {
    setState(() {
      _isSelecting = true;
      _selectedOperations = [operation];
    });
  }

  void _toggleOperationSelection(dynamic operation) {
    setState(() {
      if (_selectedOperations.contains(operation)) {
        _selectedOperations.remove(operation);
        if (_selectedOperations.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedOperations.add(operation);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _selectedOperations.clear();
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedOperations.length} operations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSelectedOperations();
    }
  }

Future<void> _deleteSelectedOperations() async {
  try {
    bool allDeleted = true;
    final isConnected = await InternetConnectionChecker().hasConnection;

    if (!isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
      return;
    }

    for (final op in _selectedOperations) {
      final success = await AuthService().deleteOperation(
        widget.token, 
        op['id'].toString(),
      );
      if (!success) allDeleted = false;
    }

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allDeleted
            ? 'Deleted ${_selectedOperations.length} operations'
            : 'Some deletions failed',
        ),
      ),
    );

    await _refreshOperations();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deletion error: ${e.toString()}')),
    );
  } finally {
    setState(() {
      _isSelecting = false;
      _selectedOperations.clear();
    });
  }
}

  void _viewOperationDetails(dynamic operation) {
    // Implement your operation details view here
  }
}