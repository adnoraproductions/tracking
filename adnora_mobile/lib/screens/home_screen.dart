import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _status = 'unknown'; // working, on_break, ended, unknown
  String _sessionType = ''; // office, remote
  bool _isActionLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentStatus();
  }

  Future<void> _fetchCurrentStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Find active work session for today
      final response = await Supabase.instance.client
          .from('work_sessions')
          .select()
          .eq('employee_id', userId)
          .inFilter('status', ['working', 'on_break'])
          .limit(1)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _status = response['status'] as String;
          _sessionType = response['session_type'] as String;
        });
      } else {
        setState(() {
          _status = 'ended';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load status: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Position?> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _errorMessage = 'Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _errorMessage = 'Location permissions are denied');
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() => _errorMessage = 'Location permissions are permanently denied, we cannot request permissions.');
      return null;
    } 

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _handleAction(String action) async {
    setState(() {
      _isActionLoading = true;
      _errorMessage = '';
    });

    try {
      final position = await _getLocation();
      if (position == null) {
        setState(() => _isActionLoading = false);
        return; // Error already set
      }

      if (action == 'start_office' || action == 'start_remote') {
        final sessionType = action == 'start_office' ? 'office' : 'remote';
        await Supabase.instance.client.rpc('rpc_start_session', params: {
          'p_session_type': sessionType,
          'p_lat': position.latitude,
          'p_lng': position.longitude,
        });
      } else if (action == 'end') {
        await Supabase.instance.client.rpc('rpc_end_session', params: {
          'p_lat': position.latitude,
          'p_lng': position.longitude,
        });
      }

      await _fetchCurrentStatus();
    } catch (e) {
      setState(() {
        _errorMessage = 'Action failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1e293b),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchCurrentStatus,
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                // Status Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Current Status',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status == 'working' ? 'Active ($_sessionType)' 
                        : _status == 'on_break' ? 'On Break' 
                        : 'Not Working',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _status == 'working' ? Colors.green 
                              : _status == 'on_break' ? Colors.orange 
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),

                // Action Buttons
                if (_status == 'ended' || _status == 'unknown') ...[
                  _buildActionButton(
                    title: 'Punch In (Office)',
                    icon: Icons.business,
                    color: const Color(0xFF10b981),
                    onPressed: () => _handleAction('start_office'),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    title: 'Punch In (Remote)',
                    icon: Icons.home,
                    color: const Color(0xFF3b82f6),
                    onPressed: () => _handleAction('start_remote'),
                  ),
                ] else if (_status == 'working' || _status == 'on_break') ...[
                  _buildActionButton(
                    title: 'Punch Out',
                    icon: Icons.exit_to_app,
                    color: Colors.red,
                    onPressed: () => _handleAction('end'),
                  ),
                  // Note: Break functionality can be added here if rpc_toggle_break exists
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: _isActionLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: _isActionLoading
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
