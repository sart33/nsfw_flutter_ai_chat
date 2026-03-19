import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/core/services/novita_avatar_service.dart';
import 'package:nsfw_chat/core/services/prompt_cleaner_service.dart';
import 'package:nsfw_chat/core/utils/seed_utils.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Create or edit a persona.
/// Form: name (required), description (max 4000, char count, red if over),
/// greeting (max 200), behavior (optional), avatar picker with crop.
/// Avatar can be picked from gallery/camera OR generated via Novita AI.
class CreateEditPersonaScreen extends ConsumerStatefulWidget {
  final String? personaId;

  const CreateEditPersonaScreen({super.key, this.personaId});

  @override
  ConsumerState<CreateEditPersonaScreen> createState() =>
      _CreateEditPersonaScreenState();
}

class _CreateEditPersonaScreenState
    extends ConsumerState<CreateEditPersonaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _greetCtrl = TextEditingController();
  final _behaviorCtrl = TextEditingController();

  String? _avatarPath;
  bool _isGeneratingAvatar = false;
  String? _generatedAvatarPreviewPath;
  String _galleryMode = 'nude';

  bool get _isEdit => widget.personaId != null;

  static const int _descMax = 4000;
  static const int _greetMax = 200;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final persona =
            ref.read(personaProvider.notifier).getById(widget.personaId!);
        if (persona != null) {
          _nameCtrl.text = persona.name;
          _descCtrl.text = persona.description;
          _greetCtrl.text = persona.greeting;
          _behaviorCtrl.text = persona.behavior ?? '';
          setState(() {
            _avatarPath = persona.avatarPath;
            _galleryMode = persona.galleryMode;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _greetCtrl.dispose();
    _behaviorCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? context.l10n.editCharacter : context.l10n.newCharacter),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar section ─────────────────────────────────
              _buildAvatarSection(),
              const SizedBox(height: 20),

              // ── Name ───────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.nameLabel,
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                onChanged: (_) => setState(() {}), // rebuild to update button state
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? context.l10n.enterName : null,
              ),
              const SizedBox(height: 16),

              // ── Description ────────────────────────────────────
              _buildCountedField(
                controller: _descCtrl,
                label: context.l10n.description,
                maxChars: _descMax,
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // ── Greeting ───────────────────────────────────────
              _buildCountedField(
                controller: _greetCtrl,
                label: context.l10n.greeting,
                maxChars: _greetMax,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ── Behavior ───────────────────────────────────────
              TextFormField(
                controller: _behaviorCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: context.l10n.behaviorOptional,
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  hintText: context.l10n.aiInstructions,
                ),
              ),
              const SizedBox(height: 16),

              // ── Gallery mode selector ──────────────────────────
              Text(
                'Режим галереи',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'romantic',
                    label: Text('Романтика'),
                    icon: Icon(Icons.favorite_border, size: 16),
                  ),
                  ButtonSegment(
                    value: 'erotic',
                    label: Text('Эротика'),
                    icon: Icon(Icons.local_fire_department, size: 16),
                  ),
                  ButtonSegment(
                    value: 'office',
                    label: Text('Офис'),
                    icon: Icon(Icons.business_center_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'nude',
                    label: Text('NSFW'),
                    icon: Icon(Icons.whatshot, size: 16),
                  ),
                ],
                selected: {_galleryMode},
                onSelectionChanged: (Set<String> selected) {
                  setState(() => _galleryMode = selected.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF7C4DFF);
                    }
                    return const Color(0xFF1A1A1A);
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                  side: WidgetStateProperty.all(
                      const BorderSide(color: Color(0xFF333333))),
                ),
              ),
              const SizedBox(height: 24),

              // ── Save button ────────────────────────────────────
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isGeneratingAvatar ? null : _save,
                  child: Text(_isEdit ? context.l10n.save : context.l10n.create),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar section ────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    return Column(
      children: [
        // Preview area
        _buildAvatarPreview(),
        const SizedBox(height: 12),

        // Action buttons row: gallery | generate
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.photo_library,
              label: context.l10n.fromGallery,
              onPressed: _isGeneratingAvatar ? null : _pickFromGallery,
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              icon: Icons.auto_awesome,
              label: context.l10n.generate,
              onPressed: (_isGeneratingAvatar ||
                      _nameCtrl.text.trim().isEmpty ||
                      _descCtrl.text.trim().isEmpty)
                  ? null
                  : _generateAvatar,
            ),
          ],
        ),

        // Preview action buttons (shown only when a generated preview exists)
        if (_generatedAvatarPreviewPath != null && !_isGeneratingAvatar) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildIconLabelButton(
                  icon: Icons.refresh,
                  label: context.l10n.regenerate,
                  onPressed: _regenerateAvatar,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildIconLabelButton(
                  icon: Icons.crop,
                  label: context.l10n.cropAndSave,
                  onPressed: _cropGeneratedAvatar,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarPreview() {
    // Generation in progress
    if (_isGeneratingAvatar) {
      return Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.userBubble),
        ),
        child:  Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text(context.l10n.generatingAvatar,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Show generated preview (not yet cropped/confirmed)
    final previewPath = _generatedAvatarPreviewPath;
    if (previewPath != null && File(previewPath).existsSync()) {
      return Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.userBubble, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.file(
            File(previewPath),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Show confirmed avatar
    final hasAvatar =
        _avatarPath != null && File(_avatarPath!).existsSync();
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.userBubble),
        image: hasAvatar
            ? DecorationImage(
                image: FileImage(File(_avatarPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasAvatar
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, color: AppTheme.textSecondary),
                SizedBox(height: 4),
                Text(
                  context.l10n.avatar,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: onPressed == null
            ? AppTheme.textSecondary
            : AppTheme.textPrimary,
        side: BorderSide(
          color: onPressed == null
              ? AppTheme.textSecondary.withAlpha(80)
              : AppTheme.userBubble,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _buildIconLabelButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppTheme.userIcon),
      label: Text(
        label,
        style: const TextStyle(color: AppTheme.userIcon, fontSize: 13),
      ),
    );
  }

  // ── Avatar actions ────────────────────────────────────────────────────────

  /// Original gallery/camera picker (kept intact).
  Future<void> _pickFromGallery() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppTheme.textPrimary),
              title: Text(context.l10n.gallery,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppTheme.textPrimary),
              title: Text(context.l10n.camera,
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.l10n.cropAvatar,
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
        ),
        IOSUiSettings(title: context.l10n.cropAvatar),
      ],
    );
    if (cropped != null) {
      // Discard any pending generated preview
      _deleteTempPreview();
      setState(() {
        _avatarPath = cropped.path;
        _generatedAvatarPreviewPath = null;
      });
    }
  }

  /// Generate avatar via Novita AI.
  Future<void> _generateAvatar({int? seed}) async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.fillCharacterDescription)),
      );
      return;
    }

    setState(() => _isGeneratingAvatar = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = await NovitaAvatarService.generateAvatar(
        _descCtrl.text.trim(),
        dir.path,
        seed: seed ?? 101,
      );
      if (mounted) {
        setState(() => _generatedAvatarPreviewPath = path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.avatarGenerationError} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAvatar = false);
      }
    }
  }

  /// Delete old temp file and regenerate.
  Future<void> _regenerateAvatar() async {
    _deleteTempPreview();
    setState(() => _generatedAvatarPreviewPath = null);
    await _generateAvatar(seed: regenSeed());
  }

  /// Crop the generated preview and promote it to the confirmed avatar.
  Future<void> _cropGeneratedAvatar() async {
    final previewPath = _generatedAvatarPreviewPath;
    if (previewPath == null) return;

    // image_cropper not supported on desktop — use image as-is
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      setState(() {
        _avatarPath = previewPath;
        _generatedAvatarPreviewPath = null;
      });
      return;
    }

    final cropped = await ImageCropper().cropImage(
      sourcePath: previewPath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.l10n.cropAvatar,
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
        ),
        IOSUiSettings(title: context.l10n.cropAvatar),
      ],
    );

    if (cropped != null) {
      // Remove temp file only after a successful crop
      _deleteTempPreview();
      setState(() {
        _avatarPath = cropped.path;
        _generatedAvatarPreviewPath = null;
      });
    }
  }

  /// Silently deletes the temporary generated preview file if it exists.
  void _deleteTempPreview() {
    final p = _generatedAvatarPreviewPath;
    if (p != null) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildCountedField({
    required TextEditingController controller,
    required String label,
    required int maxChars,
    int maxLines = 1,
  }) {
    return StatefulBuilder(
      builder: (context, setInner) {
        final len = controller.text.length;
        final over = len > maxChars;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                labelStyle:
                    const TextStyle(color: AppTheme.textSecondary),
                enabledBorder: over
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      )
                    : null,
                focusedBorder: over
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.red, width: 2),
                      )
                    : null,
              ),
              onChanged: (_) => setInner(() {}),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$len / $maxChars',
                style: TextStyle(
                  color: over ? Colors.red : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Save ─────────────────
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_descCtrl.text.length > _descMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.descriptionLimitExceeded),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_greetCtrl.text.length > _greetMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.greetingLimitExceeded),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final entity = PersonaEntity(
      id: widget.personaId ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      greeting: _greetCtrl.text.trim(),
      avatarPath: _avatarPath,
      behavior: _behaviorCtrl.text.trim().isEmpty
          ? null
          : _behaviorCtrl.text.trim(),
      galleryMode: _galleryMode,
    );

    final notifier = ref.read(personaProvider.notifier);
    if (_isEdit) {
      notifier.update(entity);
    } else {
      notifier.create(entity);
    }

    // Fire and forget: clean description for image generation
    unawaited(
      PromptCleanerService.instance.cleanAndSave(
        entity.id,
        entity.description,
      ),
    );

    Navigator.pop(context);
  }
}
