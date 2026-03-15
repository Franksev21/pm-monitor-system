// lib/core/widgets/global_alert_listener.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/services/alert_service.dart';

class GlobalAlertListener extends StatefulWidget {
  final Widget child;
  const GlobalAlertListener({super.key, required this.child});

  @override
  State<GlobalAlertListener> createState() => _GlobalAlertListenerState();
}

class _GlobalAlertListenerState extends State<GlobalAlertListener> {
  bool _isShowingAlert = false;
  Stream<QuerySnapshot>? _stream;
  String? _uid;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print('🔔 GlobalAlertListener UID: $uid');
    if (uid != null) {
      _uid = uid;
      _stream = AlertService.unreadAlertsStream(uid);
    }
  }

  String _formatAlertDateTime(dynamic createdAt) {
    if (createdAt == null) return 'Ahora';
    try {
      final date = (createdAt as Timestamp).toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour =
          date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$day/$month/$year $hour:$minute $period';
    } catch (_) {
      return 'Ahora';
    }
  }

  void _handleAlert(DocumentSnapshot doc) {
    if (_isShowingAlert || !mounted) return;
    _isShowingAlert = true;

    final data = doc.data() as Map<String, dynamic>;
    final message = data['message'] ?? '';
    final sentBy = data['sentBy'] ?? 'Administrador';
    final priority = data['priority'] ?? 'high';

    final Color alertColor = priority == 'critical'
        ? Colors.red[700]!
        : priority == 'high'
            ? Colors.orange[700]!
            : Colors.blue[700]!;

    final IconData alertIcon = priority == 'critical'
        ? Icons.dangerous
        : priority == 'high'
            ? Icons.warning_amber_rounded
            : Icons.notifications_active;

    // Usamos el Navigator del contexto raíz — más estable
    final navigator = Navigator.of(context, rootNavigator: true);

    navigator
        .push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, _, __) => WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              width: double.maxFinite,
              height: double.maxFinite,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    alertColor.withOpacity(0.97),
                    alertColor.withOpacity(0.80),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PulsingIcon(icon: alertIcon, color: Colors.white),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 1.5),
                        ),
                        child: const Text(
                          '⚠️  ALERTA DEL SISTEMA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.maxFinite,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enviado por: $sentBy',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.white.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            _formatAlertDateTime(data['createdAt']),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.maxFinite,
                        child: ElevatedButton(
                          onPressed: () async {
                            navigator.pop();
                            _isShowingAlert = false;
                            await AlertService.markAsRead(doc.id);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: alertColor,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            '✓  ENTENDIDO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .then((_) {
      _isShowingAlert = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) return widget.child;

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        print(
            '🔔 Stream: ${snapshot.connectionState} | docs: ${snapshot.data?.docs.length ?? 0} | error: ${snapshot.error}');

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isShowingAlert && mounted) {
              _handleAlert(snapshot.data!.docs.first);
            }
          });
        }
        return widget.child;
      },
    );
  }
}

// Ícono con animación de pulso
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(widget.icon, size: 90, color: widget.color),
    );
  }
}
