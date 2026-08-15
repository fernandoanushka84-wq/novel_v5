
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

class EditChapterScreen extends StatefulWidget {
  const EditChapterScreen({
    super.key,
    required this.apiService,
    required this.storyId,
    this.chapterId,
    this.chapterNumber,
    this.chapterTitle = 'Chapter 1',
    this.initialContent = '',
    this.createNew = false,
  });

  final ApiService apiService;
  final int storyId;
  /// When set, load/update this specific chapter.
  final int? chapterId;
  final int? chapterNumber;
  final String chapterTitle;
  final String initialContent;
  /// When true, start blank and POST a new chapter on save.
  final bool createNew;

  @override
  State<EditChapterScreen> createState() => _EditChapterScreenState();
}

class _EditChapterScreenState extends State<EditChapterScreen> {
  late TextEditingController _titleController;
  late TextEditingController _textController;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isLoading = true;
  bool _isSaving = false;

  int? _chapterId;
  int _chapterNumber = 1;
  String _chapterNotes = '';
  String _submissionStatus = 'draft';
  DateTime? _scheduledFor;

  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chapterTitle);
    _textController = TextEditingController(text: widget.initialContent);
    _textController.addListener(() => setState(() {}));
    _loadChapter();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    setState(() => _isLoading = true);
    try {
      // New chapter: pick next chapter number, leave editors blank.
      if (widget.createNew) {
        final chapters =
            await widget.apiService.fetchStoryChapters(widget.storyId);
        int next = 1;
        for (final c in chapters) {
          final n = (c['chapter_number'] as num?)?.toInt() ?? 0;
          if (n >= next) next = n + 1;
        }
        _chapterId = null;
        _chapterNumber = widget.chapterNumber ?? next;
        _titleController.text = widget.chapterTitle.isNotEmpty
            ? widget.chapterTitle
            : 'Chapter $_chapterNumber';
        _textController.text = widget.initialContent;
        _chapterNotes = '';
        _submissionStatus = 'draft';
        _scheduledFor = null;
        return;
      }

      final chapters =
          await widget.apiService.fetchStoryChapters(widget.storyId);
      Map<String, dynamic>? chapter;
      if (widget.chapterId != null) {
        for (final c in chapters) {
          if ((c['id'] as num?)?.toInt() == widget.chapterId) {
            chapter = c;
            break;
          }
        }
      }
      // Fall back to requested number, else first chapter.
      if (chapter == null && widget.chapterNumber != null) {
        for (final c in chapters) {
          if ((c['chapter_number'] as num?)?.toInt() == widget.chapterNumber) {
            chapter = c;
            break;
          }
        }
      }
      if (chapter == null && chapters.isNotEmpty && !widget.createNew) {
        chapter = chapters.first;
      }

      if (chapter != null) {
        _chapterId = (chapter['id'] as num?)?.toInt();
        _chapterNumber =
            (chapter['chapter_number'] as num?)?.toInt() ??
            widget.chapterNumber ??
            1;
        _titleController.text =
            chapter['title']?.toString().trim().isNotEmpty == true
            ? chapter['title'].toString()
            : widget.chapterTitle;
        _textController.text = chapter['content']?.toString() ?? '';
        _chapterNotes = chapter['notes']?.toString() ?? '';
        _submissionStatus =
            chapter['submission_status']?.toString().trim().isNotEmpty == true
            ? chapter['submission_status'].toString()
            : 'draft';
        final scheduledFor = chapter['scheduled_for']?.toString();
        _scheduledFor = scheduledFor != null && scheduledFor.isNotEmpty
            ? DateTime.tryParse(scheduledFor)
            : null;
      } else {
        // No chapters yet — prepare chapter 1 as new.
        _chapterId = null;
        _chapterNumber = widget.chapterNumber ?? 1;
        _titleController.text = widget.chapterTitle;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load chapter. You can still write and save.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChapter({
    String? submissionStatus,
    DateTime? scheduledFor,
    String? successMessage,
  }) async {
    final title = _titleController.text.trim();
    final content = _textController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter chapter title')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final nextSubmissionStatus = submissionStatus ?? _submissionStatus;
      final nextScheduledFor = scheduledFor ?? _scheduledFor;
      final payload = {
        'title': title,
        'content': content,
        'chapter_number': _chapterNumber,
        'notes': _chapterNotes,
        'submission_status': nextSubmissionStatus,
        'scheduled_for': nextScheduledFor?.toIso8601String(),
      };

      if (_chapterId == null) {
        _chapterId = await widget.apiService.createStoryChapter(
          widget.storyId,
          payload,
        );
      } else {
        await widget.apiService.updateStoryChapter(_chapterId!, payload);
      }

      _submissionStatus = nextSubmissionStatus;
      _scheduledFor = nextScheduledFor;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage ?? 'Chapter saved to database'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save chapter: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _editChapterNotes() async {
    final controller = TextEditingController(text: _chapterNotes);
    String? updatedNotes;
    try {
      updatedNotes = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chapter Notes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Add internal notes for this chapter...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('Save Notes'),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      // Dispose after the route is fully closed so TextField is not using it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
    if (updatedNotes == null) return;

    setState(() => _chapterNotes = updatedNotes!);
    await _saveChapter(successMessage: 'Chapter notes updated');
  }

  Future<void> _submitChapter() async {
    await _saveChapter(
      submissionStatus: 'submitted',
      scheduledFor: null,
      successMessage: 'Chapter submitted',
    );
    // Auto-publish parent story when a chapter is submitted (Inkitt-style).
    try {
      await widget.apiService.publishWriterStory(widget.storyId);
    } catch (_) {}
  }

  Future<void> _scheduleChapterSubmission() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledFor != null
          ? TimeOfDay.fromDateTime(_scheduledFor!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null) return;

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await _saveChapter(
      submissionStatus: 'scheduled',
      scheduledFor: scheduled,
      successMessage: 'Chapter scheduled for submission',
    );
  }

  Future<void> _showRevisions() async {
    if (_chapterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save this chapter first to view revisions')),
      );
      return;
    }

    final revisions = await widget.apiService.fetchStoryChapterRevisions(
      _chapterId!,
    );
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: revisions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No revisions yet.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final revision = revisions[index];
                  final createdAt = DateTime.tryParse(
                    revision['created_at']?.toString() ?? '',
                  );
                  final subtitleParts = <String>[
                    revision['submission_status']?.toString() ?? 'draft',
                    if (createdAt != null)
                      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                  ];
                  return ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(revision['title']?.toString() ?? 'Untitled'),
                    subtitle: Text(subtitleParts.join(' • ')),
                  );
                },
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemCount: revisions.length,
              ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'scheduled':
        return 'Scheduled';
      default:
        return 'Draft';
    }
  }

  String _scheduledLabel() {
    final scheduledFor = _scheduledFor;
    if (scheduledFor == null) return 'Not scheduled';
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatShortDate(scheduledFor)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(scheduledFor))}';
  }

  Future<void> _deleteChapter() async {
    if (_chapterId == null) {
      Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: const Text('Delete this chapter from database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.apiService.deleteStoryChapter(_chapterId!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete chapter')),
        );
      }
    }
  }

  Future<bool?> _onWillPop() async {
    if (_textController.text.trim().isEmpty) return true;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_rounded),
              title: const Text('Save Chapter'),
              onTap: () async {
                Navigator.pop(context);
                await _saveChapter();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const Text('Add Chapter Notes'),
              onTap: () async {
                Navigator.pop(context);
                await _editChapterNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.publish_outlined),
              title: const Text('Submit Chapter'),
              onTap: () async {
                Navigator.pop(context);
                await _submitChapter();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Revisions'),
              onTap: () async {
                Navigator.pop(context);
                await _showRevisions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Schedule Submission'),
              onTap: () async {
                Navigator.pop(context);
                await _scheduleChapterSubmission();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text(
                'Delete Chapter',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteChapter();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop == true && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('Edit Chapter'),
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, color: AppTheme.brand),
              tooltip: 'Save',
              onPressed: _isSaving ? null : _saveChapter,
            ),
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: _showOptionsMenu,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.brand.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _statusLabel(_submissionStatus),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _scheduledLabel(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            'TITLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            'TEXT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                              fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                              color: AppTheme.ink,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                              border: InputBorder.none,
                              hintText: 'Start writing your story here...',
                              hintStyle: TextStyle(color: AppTheme.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'word count: $_wordCount',
                      style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.border)),
                      color: Color(0xFFFAFAFA),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          _ToolbarButton(icon: Icons.undo_rounded, onPressed: () {}),
                          _ToolbarButton(icon: Icons.redo_rounded, onPressed: () {}),
                          _ToolbarButton(
                            icon: Icons.format_bold_rounded,
                            onPressed: () => setState(() => _isBold = !_isBold),
                            isActive: _isBold,
                          ),
                          _ToolbarButton(
                            icon: Icons.format_italic_rounded,
                            onPressed: () => setState(() => _isItalic = !_isItalic),
                            isActive: _isItalic,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppTheme.border,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          _ToolbarButton(
                            icon: Icons.delete_outline_rounded,
                            onPressed: _deleteChapter,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 22,
        color: isActive ? AppTheme.brand : AppTheme.muted,
      ),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}

