import 'package:flutter/material.dart';
import '../services/feedback_service.dart';

/// Screen allowing the user to write and submit feedback/bug reports.
class FeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> diagnostics;
  final FeedbackService? feedbackService;

  const FeedbackScreen({
    super.key,
    required this.diagnostics,
    this.feedbackService,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _emailController = TextEditingController();

  String _feedbackType = 'Bug Report';
  bool _attachDiagnostics = true;
  bool _isSubmitting = false;
  
  FeedbackResponse? _submissionResult;

  late final FeedbackService _feedbackService;

  @override
  void initState() {
    super.initState();
    _feedbackService = widget.feedbackService ?? FeedbackService();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionResult = null;
    });

    final response = await _feedbackService.submitFeedback(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      feedbackType: _feedbackType,
      email: _emailController.text.trim(),
      scoresTelemetry: _attachDiagnostics ? widget.diagnostics : null,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _submissionResult = response;
      });

      if (!response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${response.errorMessage}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Feedback'),
        elevation: 0,
      ),
      body: _submissionResult != null && _submissionResult!.isSuccess
          ? _buildSuccessView(theme, isDark)
          : _buildFormView(theme, isDark),
    );
  }

  Widget _buildSuccessView(ThemeData theme, bool isDark) {
    final result = _submissionResult!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Feedback Submitted!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for helping us improve Gridmind! A public GitHub issue has been created to track this feedback. Anyone can view it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (result.issueNumber != null) ...[
              const SizedBox(height: 16),
              Chip(
                label: Text(
                  'Issue #${result.issueNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ],
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                setState(() {
                  _titleController.clear();
                  _bodyController.clear();
                  _emailController.clear();
                  _submissionResult = null;
                });
              },
              child: const Text('Submit Another Report'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(ThemeData theme, bool isDark) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Elegant Header card explaining feedback routing
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public GitHub issue',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your feedback is posted as a public issue at github.com/sentientbeingsoftware/gridmind. '
                          'Anyone can read it. Please do not include personal information '
                          '(names, email addresses, passwords) in the title or description. '
                          'Your optional email address is never posted; it is stored privately '
                          'and used only to reply to you if needed.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Feedback type selection title
          Text(
            'Feedback Type',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              _buildFeedbackTypeChip(theme, 'Bug Report', Icons.bug_report),
              _buildFeedbackTypeChip(theme, 'Feature Request', Icons.add_moderator),
              _buildFeedbackTypeChip(theme, 'Suggestion', Icons.lightbulb_outline),
            ],
          ),
          const SizedBox(height: 24),

          // Title field
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Summary / Title',
              hintText: 'Briefly explain the issue or idea...',
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a summary title';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Email field (optional)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address (Optional)',
              hintText: 'To receive updates on this issue...',
              helperText: 'Optional. Not posted publicly. Stored privately so we can reply if needed.',
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Description field
          TextFormField(
            controller: _bodyController,
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(
              labelText: 'Details / Description',
              hintText: 'Describe the details. If a bug, include steps to reproduce...',
              helperText: 'Public: do not include personal information.',
              helperMaxLines: 2,
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60.0),
                child: Icon(Icons.description),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter detailed feedback details';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Switch for attaching diagnostics
          SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            secondary: Icon(
              Icons.perm_device_information,
              color: theme.colorScheme.secondary,
            ),
            title: const Text('Attach diagnostic metadata'),
            subtitle: const Text('Adds your game settings and high scores to the public issue (no personal details).'),
            value: _attachDiagnostics,
            onChanged: (val) {
              setState(() {
                _attachDiagnostics = val;
              });
            },
          ),
          const SizedBox(height: 32),

          // Submission Action Button
          _isSubmitting
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Submit Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTypeChip(ThemeData theme, String type, IconData icon) {
    final isSelected = _feedbackType == type;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
      label: Text(type),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _feedbackType = type;
          });
        }
      },
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
