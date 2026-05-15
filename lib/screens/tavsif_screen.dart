import 'package:flutter/material.dart';
import '../core/theme.dart';

class TavsifScreen extends StatefulWidget {
  final String? initial;

  const TavsifScreen({super.key, this.initial});

  @override
  State<TavsifScreen> createState() => _TavsifScreenState();
}

class _TavsifScreenState extends State<TavsifScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _controller.text = widget.initial!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tavsif'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text("Qo'shish"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tavsif kiriting",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Masalan, hajmini o'zgartirishi mumkin",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
