import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pm_monitor/core/models/customer_survey_model.dart';

class CustomerSurveyScreen extends StatefulWidget {
  final String? maintenanceId;
  final String? equipmentId;
  final String? equipmentNumber;
  final String? technicianId;
  final String? technicianName;

  const CustomerSurveyScreen({
    super.key,
    this.maintenanceId,
    this.equipmentId,
    this.equipmentNumber,
    this.technicianId,
    this.technicianName,
  });

  @override
  State<CustomerSurveyScreen> createState() => _CustomerSurveyScreenState();
}

class _CustomerSurveyScreenState extends State<CustomerSurveyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _commentsController = TextEditingController();

  int _serviceQuality = 0;
  int _responseTime = 0;
  int _technicianProfessionalism = 0;
  int _problemResolution = 0;
  int _overallSatisfaction = 0;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor responde todas las preguntas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_serviceQuality == 0 ||
        _responseTime == 0 ||
        _technicianProfessionalism == 0 ||
        _problemResolution == 0 ||
        _overallSatisfaction == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor califica todas las preguntas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener datos del usuario
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();
      final clientName = userData?['name'] ?? 'Cliente';

      // Calcular promedio
      final average = CustomerSurvey.calculateAverage(
        _serviceQuality,
        _responseTime,
        _technicianProfessionalism,
        _problemResolution,
        _overallSatisfaction,
      );

      // Crear encuesta
      final survey = CustomerSurvey(
        clientId: currentUser.uid,
        clientName: clientName,
        maintenanceId: widget.maintenanceId ?? '',
        equipmentId: widget.equipmentId ?? '',
        equipmentNumber: widget.equipmentNumber ?? '',
        technicianId: widget.technicianId ?? '',
        technicianName: widget.technicianName ?? '',
        serviceQuality: _serviceQuality,
        responseTime: _responseTime,
        technicianProfessionalism: _technicianProfessionalism,
        problemResolution: _problemResolution,
        overallSatisfaction: _overallSatisfaction,
        comments: _commentsController.text.trim(),
        averageRating: average,
        createdAt: DateTime.now(),
        isCompleted: true,
      );

      // Guardar en Firestore
      await _firestore.collection('customerSurveys').add(survey.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias por tu evaluación!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error guardando encuesta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Encuesta de Satisfacción'),
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '¿Cómo fue tu experiencia?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu opinión nos ayuda a mejorar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Pregunta 1
              _buildQuestionCard(
                question: '1. ¿Cómo calificarías la calidad del servicio?',
                rating: _serviceQuality,
                onRatingChanged: (rating) {
                  setState(() {
                    _serviceQuality = rating;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Pregunta 2
              _buildQuestionCard(
                question:
                    '2. ¿Qué tan satisfecho estás con el tiempo de respuesta?',
                rating: _responseTime,
                onRatingChanged: (rating) {
                  setState(() {
                    _responseTime = rating;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Pregunta 3
              _buildQuestionCard(
                question:
                    '3. ¿Cómo calificarías el profesionalismo del técnico?',
                rating: _technicianProfessionalism,
                onRatingChanged: (rating) {
                  setState(() {
                    _technicianProfessionalism = rating;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Pregunta 4
              _buildQuestionCard(
                question: '4. ¿El problema fue resuelto satisfactoriamente?',
                rating: _problemResolution,
                onRatingChanged: (rating) {
                  setState(() {
                    _problemResolution = rating;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Pregunta 5
              _buildQuestionCard(
                question: '5. ¿Cuál es tu nivel de satisfacción general?',
                rating: _overallSatisfaction,
                onRatingChanged: (rating) {
                  setState(() {
                    _overallSatisfaction = rating;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Comentarios adicionales
              const Text(
                'Comentarios adicionales (opcional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _commentsController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Cuéntanos más sobre tu experiencia...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón enviar
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Enviar Evaluación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required String question,
    required int rating,
    required ValueChanged<int> onRatingChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(starValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    starValue <= rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color:
                        starValue <= rating ? Colors.amber : Colors.grey[300],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Muy malo',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Excelente',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
