import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
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

  // ── Shared InputDecoration theme ─────────────────────────────────────────

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.background,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.cardBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentVivid, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personasAsync = ref.watch(personaProvider);

    return Scaffold(
      appBar: CustomAppBar(
          title: _isEdit
              ? context.l10n.editPreset
              : context.l10n.newMultiPreset),
      body: personasAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentVivid),
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            '${context.l10n.errorLoadingCharacters} ${error.toString()}',
            style: const TextStyle(color: AppTheme.warning),
          ),
        ),
        data: (personas) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Name ─────────────────────────────────────────
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _fieldDecoration(context.l10n.presetNameLabel),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.enterTitle
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Persona selector ──────────────────────────────
                  Text(
                    context.l10n.selectCharacters,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Чекбокс-список в карточке с бордером
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder, width: 1),
                    ),
                    child: Column(
                      children: personas.asMap().entries.map((entry) {
                        final index = entry.key;
                        final p = entry.value;
                        final isLast = index == personas.length - 1;
                        return Column(
                          children: [
                            CheckboxListTile(
                              value: _selectedIds.contains(p.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedIds.add(p.id);
                                  } else {
                                    _selectedIds.remove(p.id);
                                  }
                                  _updateGreeting(personas);
                                });
                              },
                              secondary: AvatarWidget(
                                imagePath: p.avatarPath,
                                assetPath: p.avatarAssetPath,
                                name: p.name,
                                size: 40,
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary),
                              ),
                              activeColor: AppTheme.accentVivid,
                              checkColor: Colors.white,
                              controlAffinity:
                              ListTileControlAffinity.leading,
                            ),
                            if (!isLast)
                              Divider(
                                height: 1,
                                color: AppTheme.cardBorder,
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Greeting ──────────────────────────────────────
                  TextFormField(
                    controller: _greetCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 4,
                    decoration: _fieldDecoration(context.l10n.greeting),
                  ),
                  const SizedBox(height: 16),

                  // ── Behavior ──────────────────────────────────────
                  TextFormField(
                    controller: _behaviorCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 4,
                    decoration: _fieldDecoration(
                      context.l10n.behavior,
                      hint: context.l10n.describeBehavior,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save ──────────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _save(personas),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentVivid,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.cardBg,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: Text(
                        _isEdit ? context.l10n.save : context.l10n.create,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pre-fill greeting by joining selected personas' greetings.
  void _updateGreeting(List<PersonaEntity> personas) {
    if (_isEdit) return;
    final selected =
    personas.where((p) => _selectedIds.contains(p.id)).toList();
    final joined =
    selected.map((p) => '${p.name}: ${p.greeting}').join('\n');
    _greetCtrl.text = joined;
  }

  void _save(List<PersonaEntity> personas) {
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