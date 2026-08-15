import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.apiService,
    this.title = 'Contact support',
  });

  final ApiService apiService;
  final String title;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _issue = 'General support';
  String _deviceType = 'Android phone';
  String _attachmentPath = '';
  bool _submitting = false;

  Future<void> _pickAttachment() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    final payload = await widget.apiService.uploadSupportAttachment(
      bytes,
      picked.name,
    );
    final path = payload['path']?.toString() ?? '';
    if (!mounted || path.isEmpty) {
      return;
    }

    setState(() => _attachmentPath = path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attachment uploaded')),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (email.isEmpty || firstName.isEmpty || subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete every field.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.apiService.submitSupportRequest({
        'email': email,
        'first_name': firstName,
        'issue': _issue,
        'subject': subject,
        'description': description,
        'device_type': _deviceType,
        'attachment_path': _attachmentPath,
      });
      if (!mounted) {
        return;
      }
      _subjectController.clear();
      _descriptionController.clear();
      setState(() => _attachmentPath = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request submitted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
            ),
            child: const TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Submit a request',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Your email address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _issue,
            decoration: const InputDecoration(labelText: 'Customer Issue'),
            items: const [
              DropdownMenuItem(value: 'General support', child: Text('General support')),
              DropdownMenuItem(value: 'Billing', child: Text('Billing')),
              DropdownMenuItem(value: 'Story moderation', child: Text('Story moderation')),
              DropdownMenuItem(value: 'Account access', child: Text('Account access')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _issue = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 8),
          Text(
            'Please enter the details of your request. Please include any relevant details about your problem including the name(s) of the stories affected, chapter numbers, and any error messages you receive.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _deviceType,
            decoration: const InputDecoration(
              labelText: 'What type of device are you using?',
            ),
            items: const [
              DropdownMenuItem(value: 'Android phone', child: Text('Android phone')),
              DropdownMenuItem(value: 'Android tablet', child: Text('Android tablet')),
              DropdownMenuItem(value: 'iPhone', child: Text('iPhone')),
              DropdownMenuItem(value: 'iPad', child: Text('iPad')),
              DropdownMenuItem(value: 'Web browser', child: Text('Web browser')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _deviceType = value);
              }
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Attachments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickAttachment,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file_rounded, color: AppTheme.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _attachmentPath.isEmpty
                          ? 'Add file or drop file here'
                          : _attachmentPath.split('/').last,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.brand),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}