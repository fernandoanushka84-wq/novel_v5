import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

/// Developer Help tab — feature requests, bug reports, improvements.
class DeveloperHelpScreen extends StatefulWidget {
  const DeveloperHelpScreen({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<DeveloperHelpScreen> createState() => _DeveloperHelpScreenState();
}

class _DeveloperHelpScreenState extends State<DeveloperHelpScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _emailController = TextEditingController();
  String _category = 'feature';
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.apiService.submitDeveloperHelp(
        title: title,
        description: desc,
        category: _category,
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _titleController.clear();
      _descController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your request was sent to the development team.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Developer Help'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Send feature requests, bug reports, or improvement ideas. The Wingsaga team reviews these for future updates.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text('Category', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const [
                ('feature', 'Feature'),
                ('bug', 'Bug'),
                ('improvement', 'Improvement'),
              ])
                ChoiceChip(
                  label: Text(c.$2),
                  selected: _category == c.$1,
                  selectedColor: AppTheme.accent.withValues(alpha: 0.35),
                  onSelected: (_) => setState(() => _category = c.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Short summary',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What should we build or fix?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              hintText: 'So we can follow up',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit request'),
            ),
          ),
        ],
      ),
    );
  }
}
