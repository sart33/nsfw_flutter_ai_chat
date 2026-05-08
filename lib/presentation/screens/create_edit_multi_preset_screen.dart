import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/multi_preset_entity.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/screens/persona_view_screen.dart';
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

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktopLayout = _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;

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
          if (useDesktopLayout) {
            return _buildDesktopLayout(personas);
          } else {
            return _buildMobileLayout(personas);
          }
        },
      ),
    );
  }

  // ── Desktop layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(List<PersonaEntity> personas) {
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                  const SizedBox(height: 24),

                  // ── Persona carousel ──────────────────────────────
                  Text(
                    context.l10n.selectCharacters,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DesktopPersonaCarousel(
                    personas: personas,
                    selectedIds: _selectedIds,
                    onToggle: (id) {
                      setState(() {
                        if (_selectedIds.contains(id)) {
                          _selectedIds.remove(id);
                        } else {
                          _selectedIds.add(id);
                        }
                        _updateGreeting(personas);
                      });
                    },
                    onView: (persona) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PersonaViewScreen(persona: persona),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

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
                  const SizedBox(height: 32),

                  // ── Save button — centered 260px ──────────────────
                  Center(
                    child: SizedBox(
                      width: 260,
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
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(List<PersonaEntity> personas) {
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
                  final isSelected = _selectedIds.contains(p.id);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            AvatarWidget(
                              imagePath: p.avatarPath,
                              assetPath: p.avatarAssetPath,
                              name: p.name,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary),
                              ),
                            ),
                            Switch(
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked) {
                                    _selectedIds.add(p.id);
                                  } else {
                                    _selectedIds.remove(p.id);
                                  }
                                  _updateGreeting(personas);
                                });
                              },
                              activeColor: AppTheme.accentVivid,
                            ),
                          ],
                        ),
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

// ── Desktop Persona Carousel ──────────────────────────────────────────────────

class _DesktopPersonaCarousel extends StatefulWidget {
  final List<PersonaEntity> personas;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;
  final void Function(PersonaEntity persona) onView;

  const _DesktopPersonaCarousel({
    required this.personas,
    required this.selectedIds,
    required this.onToggle,
    required this.onView,
  });

  @override
  State<_DesktopPersonaCarousel> createState() =>
      _DesktopPersonaCarouselState();
}

class _DesktopPersonaCarouselState extends State<_DesktopPersonaCarousel> {
  late final ScrollController _scrollCtrl;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  static const double _cardWidth = 170;
  static const double _cardGap = 12;
  static const double _scrollStep = _cardWidth + _cardGap;
  // Высота карточек без скроллбара — скроллбар идёт снизу отдельно
  static const double _cardHeight = 330;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final left = pos.pixels > 0;
    final right = pos.pixels < pos.maxScrollExtent;
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  void _scrollBy(double delta) {
    _scrollCtrl.animateTo(
      (_scrollCtrl.offset + delta).clamp(
        0.0,
        _scrollCtrl.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Карточки + стрелки поверху ─────────────────────
        SizedBox(
          height: _cardHeight,
          child: Stack(
            children: [
              // Список
              Scrollbar(
                controller: _scrollCtrl,
                thumbVisibility: false, // скроллбар внизу не нужен — есть стрелки
                child: ListView.separated(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: widget.personas.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(width: _cardGap),
                  itemBuilder: (context, index) {
                    final p = widget.personas[index];
                    final isSelected = widget.selectedIds.contains(p.id);
                    return SizedBox(
                      width: _cardWidth,
                      child: _DesktopPersonaCard(
                        persona: p,
                        isSelected: isSelected,
                        onToggle: () => widget.onToggle(p.id),
                        onView: () => widget.onView(p),
                      ),
                    );
                  },
                ),
              ),

              // Левая стрелка поверх — прижата к левому краю изображения
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _OverlayArrow(
                    icon: Icons.chevron_left_rounded,
                    visible: _canScrollLeft,
                    onTap: () => _scrollBy(-_scrollStep),
                  ),
                ),
              ),

              // Правая стрелка поверх — прижата к правому краю
              Positioned(
                right: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _OverlayArrow(
                    icon: Icons.chevron_right_rounded,
                    visible: _canScrollRight,
                    onTap: () => _scrollBy(_scrollStep),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Стрелка-оверлей поверх карточек ─────────────────────────────────────────

class _OverlayArrow extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onTap;

  const _OverlayArrow({
    required this.icon,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.cardBg.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder, width: 1),
            ),
            child: Icon(
              icon,
              color: AppTheme.textPrimary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
class _DesktopPersonaCard extends StatelessWidget {
  final PersonaEntity persona;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onView;

  const _DesktopPersonaCard({
    required this.persona,
    required this.isSelected,
    required this.onToggle,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 170,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.accentVivid : AppTheme.cardBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: AppTheme.accentVivid.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
          )
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Avatar area ────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: _PersonaImage(persona: persona),
            ),
          ),

          // ── Name + short description ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              persona.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (persona.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                persona.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const SizedBox(height: 8),

          // ── Controls row ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 8, 10),
            child: Row(
              children: [
                // View button
                InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.cardBorder, width: 1),
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                // Select toggle
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: isSelected,
                    onChanged: (_) => onToggle(),
                    activeColor: AppTheme.accentVivid,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders persona image from file path or asset path.
class _PersonaImage extends StatelessWidget {
  final PersonaEntity persona;

  const _PersonaImage({required this.persona});

  @override
  Widget build(BuildContext context) {
    if (persona.avatarPath != null && persona.avatarPath!.isNotEmpty) {
      return Image.file(
        // ignore: deprecated_member_use
        File(persona.avatarPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (persona.avatarAssetPath != null &&
        persona.avatarAssetPath!.isNotEmpty) {
      return Image.asset(
        persona.avatarAssetPath!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: AppTheme.cardBg,
      child: Center(
        child: Text(
          persona.name.isNotEmpty ? persona.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
