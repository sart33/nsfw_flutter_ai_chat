import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/widgets/avatar_widget.dart';
import 'package:uuid/uuid.dart';

import '../widgets/custom_app_bar_widget.dart';

/// Create or edit a multi-persona preset.
/// Name, persona multi-select, greeting (pre-filled), behavior field.
class CreateEditMultiPresetScreen extends ConsumerStatefulWidget {
  final String? presetId;

  const CreateEditMultiPresetScreen({super.key, this.presetId});

  @override
  ConsumerState<CreateEditMultiPresetScreen> createState() =>
      _CreateEditMultiPresetScreenState();
}

class _CreateEditMultiPresetScreenState
    extends ConsumerState<CreateEditMultiPresetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _greetCtrl = TextEditingController();
  final _behaviorCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool get _isEdit => widget.presetId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final preset =
            ref.read(multiPresetProvider.notifier).getById(widget.presetId!);
        if (preset != null) {
          _nameCtrl.text = preset.name;
          _greetCtrl.text = preset.greeting;
          _behaviorCtrl.text = preset.behavior ?? '';
          setState(() => _selectedIds.addAll(preset.personaIds));
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _greetCtrl.dispose();
    _behaviorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personas = ref.watch(personaProvider);

    return Scaffold(
      appBar: CustomAppBar(title: _isEdit ? context.l10n.editPreset : context.l10n.newMultiPreset),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Name ───────────────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.presetNameLabel,
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Введите название' : null,
              ),
              const SizedBox(height: 20),

              // ── Persona selector ───────────────────────────────
              Text(
                context.l10n.selectCharacters,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...personas.map((p) => CheckboxListTile(
                    value: _selectedIds.contains(p.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(p.id);
                        } else {
                          _selectedIds.remove(p.id);
                        }
                        _updateGreeting();
                      });
                    },
                    secondary: AvatarWidget(
                      imagePath: p.avatarPath,
                      assetPath: p.avatarAssetPath,
                      name: p.name,
                      size: 40,
                    ),
                    title: Text(p.name,
                        style:
                            const TextStyle(color: AppTheme.textPrimary)),
                    activeColor: AppTheme.primaryAccent,
                    checkColor: Colors.black,
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
              const SizedBox(height: 16),

              // ── Greeting ───────────────────────────────────────
              TextFormField(
                controller: _greetCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.greeting,
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // ── Behavior ───────────────────────────────────────
              TextFormField(
                controller: _behaviorCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.behavior,
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  hintText:
                      context.l10n.describeBehavior,
                ),
              ),
              const SizedBox(height: 24),

              // ── Save ───────────────────────────────────────────
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(_isEdit ? context.l10n.save : context.l10n.create),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pre-fill greeting by joining selected personas' greetings.
  void _updateGreeting() {
    if (_isEdit) return; // don't overwrite on edit
    final personas = ref.read(personaProvider);
    final selected =
        personas.where((p) => _selectedIds.contains(p.id)).toList();
    final joined =
        selected.map((p) => '${p.name}: ${p.greeting}').join('\n');
    _greetCtrl.text = joined;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.selectAtLeast2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final entity = MultiPresetEntity(
      id: widget.presetId ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      personaIds: _selectedIds.toList(),
      greeting: _greetCtrl.text.trim(),
      behavior: _behaviorCtrl.text.trim().isEmpty
          ? null
          : _behaviorCtrl.text.trim(),
    );

    final notifier = ref.read(multiPresetProvider.notifier);
    if (_isEdit) {
      notifier.update(entity);
    } else {
      notifier.create(entity);
    }

    Navigator.pop(context);
  }
}
