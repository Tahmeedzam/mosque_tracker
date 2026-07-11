import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportFormScreen extends StatefulWidget {
  final String type;
  final String title;
  final String subtitle;
  final String placeholder;
  final String? mosqueName;
  final String? mosqueId;

  const ReportFormScreen({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.placeholder,
    this.mosqueName,
    this.mosqueId,
  });

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _messageController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  bool _submitted = false;

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      final email = _supabase.auth.currentUser?.email;

      await _supabase.from('feedback_reports').insert({
        'user_id': userId,
        'type': widget.type,
        'message': _messageController.text.trim(),
        'email': email,
        'mosque_id': widget.mosqueId,
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A14),
      body: SafeArea(child: _submitted ? _buildSuccess() : _buildForm()),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 24,
                    color: Color(0xFFF5F0E8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Show mosque info as a read-only chip when reporting a specific mosque
                if (widget.mosqueName != null) ...[
                  Text(
                    "REPORTING MOSQUE",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF52B788).withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text("🕌", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.mosqueName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFF5F0E8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Text(
                  "YOUR MESSAGE",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _messageController,
                  maxLines: 8,
                  autofocus: false,
                  style: const TextStyle(
                    color: Color(0xFFF5F0E8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                    filled: true,
                    fillColor: const Color(0xFF152419),
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.07),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF52B788)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF52B788).withOpacity(0.3),
                        ),
                      ),
                      child: _isSubmitting
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF5F0E8),
                                ),
                              ),
                            )
                          : const Text(
                              "Submit",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFF5F0E8),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF52B788).withOpacity(0.4),
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 32,
                color: Color(0xFF52B788),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Thank you",
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                color: Color(0xFFF5F0E8),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your message has been received.\nWe appreciate you helping us improve.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  "Done",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
