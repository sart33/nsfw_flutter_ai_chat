import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/core/services/novita_avatar_service.dart';
import 'package:nsfw_chat/core/services/prompt_cleaner_service.dart';
import 'package:nsfw_chat/core/utils/seed_utils.dart';
import 'package:nsfw_chat/data/models/avatar_style_option_model.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:uuid/uuid.dart';

import '../../core/factory/database_helper.dart';
import '../../core/utils/app_snack_bar.dart';
import '../../domain/exceptions/app_exceptions.dart';
import '../widgets/custom_app_bar_widget.dart';

/// Create or edit a persona.
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

  // --- Avatar style generation state ---
  String? _avatarPath;
  bool _isCheckingAge = false;
  bool _isGeneratingAvatar = false;
  bool _isCleaningPrompt = false; // отдельный флаг для DeepSeek фазы
  String? _generatedAvatarPreviewPath;
  String _galleryMode = 'nude';

  int? _selectedTemplateId;
  String? _cachedCleanedDescription; // описание, которое уже было очищено
  // String? _cachedCleanedLevel;
  String? _lastSentDescription; // то, что последний раз отправляли в DeepSeek

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool _isSaving = false; // block the button during testing

  // ── Style label (без l10n.getString — его не существует) ─────────────────

  String _getStyleLabel(BuildContext context, String nameKey) {
    return switch (nameKey) {
      'avatarStyleEveningDress' => context.l10n.avatarStyleEveningDress,
      'avatarStyleSummerDress' => context.l10n.avatarStyleSummerDress,
      'avatarStyleOffice' => context.l10n.avatarStyleOffice,
      'avatarStyleLingerie' => context.l10n.avatarStyleLingerie,
      'avatarStyleBikini' => context.l10n.avatarStyleBikini,
      'avatarStyleMorningCoffee'     => context.l10n.avatarStyleMorningCoffee,
      'avatarStyleParisEvening'     => context.l10n.avatarStyleParisEvening,
      'avatarParisianCafe' => context.l10n.avatarStyleCafeTerrace,
      'avatarStyleNude' => context.l10n.avatarStyleNude,
      _ => nameKey,
    };
  }

  // ── Style picker ─────────────────────────────────────────────────────────

  Future<void> showAvatarStylePicker(BuildContext ctx) async {
    if (_isGeneratingAvatar) return;

    var title = ctx.l10n.chooseAvatarStyle;

    if (_isDesktopPlatform && MediaQuery.of(ctx).size.width >= 600) {
      await showDialog<void>(
        context: ctx,
        builder:
            (dialogCtx) => AlertDialog(
              title: Text(title),
              content: SizedBox(width: 400, child: _buildStyleGrid(dialogCtx)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(ctx.l10n.cancel),
                ),
              ],
            ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: ctx,
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder:
            (sheetCtx) => SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        title,
                        style: Theme.of(sheetCtx).textTheme.titleMedium,
                      ),
                    ),
                    Flexible(child: _buildStyleGrid(sheetCtx)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      );
    }
  }

  Widget _buildStyleGrid(BuildContext ctx) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: AvatarStyleOption.allOptions.length,
      itemBuilder:
          (_, i) => _buildStyleCard(ctx, AvatarStyleOption.allOptions[i]),
    );
  }

  Widget _buildStyleCard(BuildContext ctx, AvatarStyleOption option) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.pop(ctx);
          _generateAvatarWithStyle(option);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                option.icon,
                size: 32,
                color: Theme.of(ctx).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                _getStyleLabel(ctx, option.nameKey),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Core generation ──────────────────────────────────────────────────────

  Future<String> _persistAvatarFile(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    // Используем уже известный id при редактировании, иначе временный
    final personaId = widget.personaId ?? 'avatar_preview';
    final dirPath = '${docsDir.path}/characters/$personaId/avatar';
    await Directory(dirPath).create(recursive: true);
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.webp';
    final destPath = '$dirPath/$fileName';
    await File(sourcePath).copy(destPath);
    // Удаляем источник только если это не тот же файл
    if (sourcePath != destPath) {
      try { File(sourcePath).deleteSync(); } catch (_) {}
    }
    return destPath;
  }

  Future<void> _generateAvatarWithStyle(AvatarStyleOption option) async {
    if (_isGeneratingAvatar) return;

    final description = _descCtrl.text.trim();
    if (description.isEmpty) return;

    final personaId = widget.personaId ?? 'avatar_preview_temp';
    final needsClean = description != _lastSentDescription;

    if (needsClean) {
      final apiKey = await AppConfig.getDeepSeekApiKey();
      if (apiKey.isEmpty) {
        // Ключа нет — дальше не идём, показываем ошибку
        if (!mounted) return;
        AppSnackBar.show(context.l10n.errorDeepSeekNotSet, isError: true, withSettings: true); // или твой existing ключ ошибки
        return;
      }
      // Фаза 0: проверка возраста
      setState(() {
        _isGeneratingAvatar = true;
        _isCheckingAge = true;
      });
      bool _earlyExit = false;

      try {
        final check = await PromptCleanerService.instance.checkForMinorSignals(description);
        if (check.hasConflict == true &&
            (check.severity == 'high' || check.severity == 'medium')) {
          if (!mounted) return;
          _earlyExit = true;
          if (check.severity == 'high') {
            AppSnackBar.show(context.l10n.personaDescriptionConflictHigh, isDuration: 10, isError: true);
          } else {
            AppSnackBar.show(context.l10n.personaDescriptionConflictMedium, isDuration: 10);
          }
          return;
        }

        if (!check.hasAge) {
          if (!mounted) return;
          _earlyExit = true;
          AppSnackBar.show(context.l10n.personaAgeMissing); // жёлтый/оранжевый
          return;
        }
      } on NetworkException catch (_) {
        _earlyExit = true;
        if (!mounted) return;
        AppSnackBar.show(context.l10n.networkError, isError: true);
        return;
      } on DeepSeekApiException catch (e) {
        _earlyExit = true;
        if (!mounted) return;
        AppSnackBar.showDeepSeekError(e, context.l10n);
        return;
      } finally {
        if (_earlyExit && mounted) {
          setState(() {
            _isGeneratingAvatar = false;
            _isCheckingAge = false;
          });
        } else if (mounted) {
          setState(() => _isCheckingAge = false);
        }
      }

      // Фаза 1: очистка промптов
      setState(() => _isCleaningPrompt = true);
      try {
        await PromptCleanerService.instance.cleanAndSave(personaId, description);
        if (mounted) setState(() => _lastSentDescription = description);
      } on DeepSeekApiException catch (e) {
        if (!mounted) return;
        AppSnackBar.showDeepSeekError(e, context.l10n);
        return;
      } finally {
        if (mounted) setState(() => _isCleaningPrompt = false);
      }

    } else {
      // description не менялся — сразу к Novita
      setState(() => _isGeneratingAvatar = true);
    }

    try {
      String cleaned;
      // Читаем из БД
      final prompts = await DatabaseHelper.instance.getPersonaPrompts(
        personaId,
      );
      cleaned = switch (option.intimacyLevel) {
        'erotic' => prompts?['erotic'] ?? description,
        'romantic' => prompts?['romantic'] ?? description,
        'office' => prompts?['office'] ?? description,
        'nsfw' => prompts?['nsfw'] ?? description,
        _ => description,
      };

      // Загружаем шаблон
      final jsonStr = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/json/image_templates.json');
      final templates = jsonDecode(jsonStr) as List<dynamic>;
      final template =
          templates.firstWhere(
                (t) => (t as Map<String, dynamic>)['id'] == option.templateId,
                orElse:
                    () =>
                        throw Exception(
                          'Template ${option.templateId} not found',
                        ),
              )
              as Map<String, dynamic>;

      final finalPrompt = (template['prompt_template'] as String).replaceAll(
        '{description}',
        cleaned,
      );

      // Кэшируем для регенерации
      setState(() {
        _selectedTemplateId = option.templateId;
        _cachedCleanedDescription = cleaned;
        // _cachedCleanedLevel = option.intimacyLevel;
      });

      // Фаза 2: Novita
      final dir = await getApplicationDocumentsDirectory();
      final path = await NovitaAvatarService.generateAvatarFromPrompt(
        finalPrompt,
        dir.path,
        seed: AppConfig.defaultSeed,
      );

      if (mounted) setState(() => _generatedAvatarPreviewPath = path);
    } on NetworkException catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context.l10n.networkError, isError: true);
    } on DeepSeekApiException catch (e) {
      if (!mounted) return;
      AppSnackBar.showDeepSeekError(e, context.l10n);
    } on NovitaApiException catch (e) {
      if (!mounted) return;
      AppSnackBar.showNovitaError(e, context.l10n);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context.l10n.errorImageGeneration);
    } finally {
      if (mounted)
        setState(() {
          _isGeneratingAvatar = false;
          _isCleaningPrompt = false;
          _isCheckingAge = false;
        });
    }
  }

  // ── Regenerate (без нового запроса в DeepSeek) ───────────────────────────
  Future<void> regenerateAvatarWithStyle() async {
    if (_isGeneratingAvatar) return;

    // Если стиль был выбран ранее — используем кэш, никакого DeepSeek
    if (_cachedCleanedDescription != null && _selectedTemplateId != null) {
      _deleteTempPreview();
      setState(() {
        _generatedAvatarPreviewPath = null;
        _isGeneratingAvatar = true;
        _isCleaningPrompt = false;
      });

      try {
        final jsonStr = await DefaultAssetBundle.of(
          context,
        ).loadString('assets/json/image_templates.json');
        final templates = jsonDecode(jsonStr) as List<dynamic>;
        final template =
            templates.firstWhere(
                  (t) =>
                      (t as Map<String, dynamic>)['id'] == _selectedTemplateId,
                  orElse:
                      () =>
                          throw Exception(
                            'Template $_selectedTemplateId not found',
                          ),
                )
                as Map<String, dynamic>;

        final finalPrompt = (template['prompt_template'] as String).replaceAll(
          '{description}',
          _cachedCleanedDescription!,
        );

        final dir = await getApplicationDocumentsDirectory();
        final path = await NovitaAvatarService.generateAvatarFromPrompt(
          finalPrompt,
          dir.path,
          seed: regenSeed(), // новый seed, всё остальное то же самое
        );

        if (mounted) setState(() => _generatedAvatarPreviewPath = path);
      } on NovitaApiException catch (e) {
        if (!mounted) return;
        AppSnackBar.showNovitaError(e, context.l10n);
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(context.l10n.errorImageGeneration);
      } finally {
        if (mounted) setState(() => _isGeneratingAvatar = false);
      }
    } else {
      // Стиль ещё не выбран — показываем picker заново
      await showAvatarStylePicker(context);
    }
  }

  bool get _isEdit => widget.personaId != null;

  static const int _descMax = 1000;
  static const int _greetMax = 600;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final persona = ref
            .read(personaProvider.notifier)
            .getById(widget.personaId!);
        if (persona != null) {
          _nameCtrl.text = persona.name;
          _descCtrl.text = persona.description;
          _lastSentDescription = persona.description; // <-- добавить
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

  // ── Shared InputDecoration ───────────────────────────────────────────────

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
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


  Widget _buildInfoHint(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktop =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;
    return Container(

      padding: EdgeInsets.symmetric(horizontal: useDesktop ? 28 : 8, vertical: useDesktop ? 12 : 6 ),
      decoration: useDesktop ? AppTheme.cardDecoration() : null,

    child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(height: useDesktop ? 2 : 2),
              Icon(
                Icons.info_outline,
                size: useDesktop ? 22 : 18,
                color: AppTheme.primaryAccent,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.primaryAccent,
                fontSize: useDesktop ? 15 : 14,

              ),
            ),
          ),
        ],
      ),
    );
  }
 Widget _buildInfoHintPreSave(String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktop =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;
    return Container(

      padding: EdgeInsets.symmetric(horizontal: useDesktop ? 28 : 0, vertical: useDesktop ? 6 : 6 ),

    child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: useDesktop ? 14 : 13,

              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktop =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;

    return Scaffold(
      appBar: CustomAppBar(
        title: _isEdit ? context.l10n.editCharacter : context.l10n.newCharacter,
      ),
      body: useDesktop ? _buildDesktopBody() : _buildMobileBody(),
    );
  }


  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAvatarSection(),
            const SizedBox(height: 12),
            _buildInfoHint(context.l10n.personaDescriptionAgeRequirement),

            const SizedBox(height: 16),

            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _fieldDecoration(context.l10n.nameLabel),
              onChanged: (_) => setState(() {}),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? context.l10n.enterName
                          : null,
            ),
            const SizedBox(height: 24),

            _buildCountedField(
              controller: _descCtrl,
              label: context.l10n.description,
              maxChars: _descMax,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            _buildCountedField(
              controller: _greetCtrl,
              label: context.l10n.greeting,
              maxChars: _greetMax,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _behaviorCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 6,
              decoration: _fieldDecoration(
                context.l10n.behaviorOptional,
              ).copyWith(hintText: context.l10n.aiInstructions),
            ),
            const SizedBox(height: 4),
            _buildInfoHintPreSave(context.l10n.personaAutoValidationInfo),
            const SizedBox(height: 16),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_isGeneratingAvatar || _isSaving) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentVivid,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.cardBg,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child:
                    _isSaving
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.accentVividInputBorder,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.l10n.verifyingPersona,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        )
                        : Text(
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

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopBody() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Левая колонка: аватар ──────────────────────────────────
                SizedBox(width: 280, child: _buildDesktopAvatarPanel()),
                const SizedBox(width: 20),

                // ── Правая колонка: поля + кнопка ─────────────────────────
                Expanded(child: _buildDesktopFormPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Левая панель: аватар + кнопки выбора/генерации, обёрнутые в карточку
  Widget _buildDesktopAvatarPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Аватар-превью
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 9 / 14,
              child: _buildAvatarPreviewWidget(),
            ),
          ),
          const SizedBox(height: 16),

          // Из галереи
          _buildActionButton(
            icon: Icons.photo_library,
            label: context.l10n.fromGallery,
            onPressed: _isGeneratingAvatar ? null : _pickFromGalleryDesktop,
            fullWidth: true,
          ),
          const SizedBox(height: 10),

          // Сгенерировать
          _buildActionButton(
            icon: Icons.auto_awesome,
            label: context.l10n.generate,
            onPressed:
                (_isGeneratingAvatar ||
                        _nameCtrl.text.trim().isEmpty ||
                        _descCtrl.text.trim().isEmpty)
                    ? null
                    : () => showAvatarStylePicker(context),
            fullWidth: true,
          ),

          // Regenerate / Crop (только если есть сгенерированный превью)
          if (_generatedAvatarPreviewPath != null && !_isGeneratingAvatar) ...[
            const SizedBox(height: 12),
            Column(
              children: [
                _buildIconLabelButton(
                  icon: Icons.refresh,
                  label: context.l10n.regenerate,
                  onPressed:
                      _isGeneratingAvatar ? null : regenerateAvatarWithStyle,
                  isPrimary: false,
                ),
                const SizedBox(height: 12),
                _buildIconLabelButton(
                  icon: Icons.save_alt_outlined,
                  label: context.l10n.save,
                  onPressed: _isGeneratingAvatar ? null : _cropGeneratedAvatar,
                  isPrimary: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Правая панель: все текстовые поля + кнопка Save, обёрнутые в карточку
  Widget _buildDesktopFormPanel() {
    return Column(
      children: [
        _buildInfoHint(context.l10n.personaDescriptionAgeRequirement),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // Имя
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _fieldDecoration(context.l10n.nameLabel),
                onChanged: (_) => setState(() {}),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? context.l10n.enterName
                            : null,
              ),
              const SizedBox(height: 20),

              // Описание
              _buildCountedField(
                controller: _descCtrl,
                label: context.l10n.description,
                maxChars: _descMax,
                maxLines: 5,
              ),
              const SizedBox(height: 16),

              // Приветствие
              _buildCountedField(
                controller: _greetCtrl,
                label: context.l10n.greeting,
                maxChars: _greetMax,
                maxLines: 5,
              ),
              const SizedBox(height: 16),

              // Поведение
              TextFormField(
                controller: _behaviorCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 8,
                decoration: _fieldDecoration(
                  context.l10n.behaviorOptional,
                ).copyWith(hintText: context.l10n.aiInstructions),
              ),
              const SizedBox(height: 8),
              _buildInfoHintPreSave(context.l10n.personaAutoValidationInfo),

              const SizedBox(height: 16),
              // Кнопка Save — фиксированная ширина, центр
              Center(
                child: SizedBox(
                  width: 260,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isGeneratingAvatar || _isSaving) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentVivid,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.cardBg,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child:
                        _isSaving
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme
                                          .accentVividInputBorder, // оранжевый — идёт процесс
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  context.l10n.verifyingPersona, // 'Валидация...'
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            )
                            : Text(
                              _isEdit ? context.l10n.save : context.l10n.create,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AVATAR SECTION (мобайл)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAvatarSection() {
    return Column(
      children: [
        _buildAvatarPreview(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.photo_library,
                label: context.l10n.fromGallery,
                onPressed: _isGeneratingAvatar ? null : _pickFromGallery,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.auto_awesome,
                label: context.l10n.generate,
                onPressed:
                    (_isGeneratingAvatar ||
                            _nameCtrl.text.trim().isEmpty ||
                            _descCtrl.text.trim().isEmpty)
                        ? null
                        : () => showAvatarStylePicker(context),
              ),
            ),
          ],
        ),
        if (_generatedAvatarPreviewPath != null && !_isGeneratingAvatar) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildIconLabelButton(
                  icon: Icons.refresh,
                  label: context.l10n.regenerate,
                  onPressed: regenerateAvatarWithStyle,
                ),
              ),
              const SizedBox(width: 12),
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

  // ── Avatar preview (мобайл — старый метод без AspectRatio) ───────────────

  Widget _buildAvatarPreview() {
    return SizedBox(
      width: 120,
      height: 160,
      child: _buildAvatarPreviewWidget(radius: 16),
    );
  }

  /// Общий виджет превью аватара — используется и мобайлом, и десктопом.
  Widget _buildAvatarPreviewWidget({double radius = 0}) {
    // Generation in progress
    if (_isGeneratingAvatar) {
      final String label;
      final Color color;

      if (_isCheckingAge) {
        label = context.l10n.avatarStatusCheckingAge; // новая строка локализации
        color = AppTheme.warning; // оранжевый, как у тебя был
      } else if (_isCleaningPrompt) {
        label = context.l10n.avatarStatusPreparingPrompts;
        color = AppTheme.primaryAccent;
      } else {
        label = context.l10n.avatarStatusGeneratingImage;
        color = AppTheme.accentVividInputBorder;
      }

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppTheme.userBubble),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Generated preview (not yet confirmed)
    final previewPath = _generatedAvatarPreviewPath;
    if (previewPath != null && File(previewPath).existsSync()) {
      final previewContainer = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppTheme.userBubble, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius > 0 ? radius - 1 : 0),
          child: Image.file(File(previewPath), fit: BoxFit.cover),
        ),
      );

      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const BackButton(color: Colors.white),
              ),
              body: PhotoView(
                imageProvider: FileImage(File(previewPath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4.0,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                filterQuality: FilterQuality.medium,

              ),
            ),
          ),
        ),
        child: previewContainer,
      );
    }

    // Confirmed avatar
    final hasFile = _avatarPath != null && File(_avatarPath!).existsSync();
    final persona =
        _isEdit
            ? ref.read(personaProvider.notifier).getById(widget.personaId!)
            : null;
    final assetPath = persona?.avatarAssetPath;
    final hasAsset = !hasFile && assetPath != null && assetPath.isNotEmpty;

    final container = Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.userBubble),
        image:
        hasFile
            ? DecorationImage(
          image: FileImage(File(_avatarPath!)),
          filterQuality: FilterQuality.medium,
          fit: BoxFit.cover,
        )
            : hasAsset
            ? DecorationImage(
          image: AssetImage(assetPath),
          filterQuality: FilterQuality.medium,
          fit: BoxFit.cover,
        )
            : null,
      ),
      child:
      (hasFile || hasAsset)
          ? null
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.avatar,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (!hasFile && !hasAsset) return container;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(color: Colors.white),
            ),
            body: PhotoView(
              imageProvider: hasFile
                  ? FileImage(File(_avatarPath!)) as ImageProvider
                  : AssetImage(assetPath!),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4.0,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        ),
      ),
      child: container,
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool fullWidth = false,
  }) {
    final btn = SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.cardBg,
          foregroundColor: Colors.white,
          side: BorderSide(
            color:
                onPressed == null
                    ? AppTheme.cardBorder.withAlpha(80)
                    : AppTheme.cardBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }

  Widget _buildIconLabelButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child:
          isPrimary
              ? ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18, color: Colors.white),
                label: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentVivid,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              )
              : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 18, color: Colors.white),
                label: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.cardBg,
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color:
                        onPressed == null
                            ? AppTheme.cardBorder.withAlpha(80)
                            : AppTheme.cardBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
    );
  }

  // ── Avatar actions ────────────────────────────────────────────────────────

  Future<void> _pickFromGalleryDesktop() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final persistedPath = await _persistAvatarFile(picked.path);
    setState(() {
      _avatarPath = persistedPath;
      _generatedAvatarPreviewPath = null;
    });
  }

  Future<void> _pickFromGallery() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: AppTheme.textPrimary,
                  ),
                  title: Text(
                    ctx.l10n.gallery,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                if (!_isDesktopPlatform)
                  ListTile(
                    leading: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppTheme.textPrimary,
                    ),
                    title: Text(
                      ctx.l10n.camera,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
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
      _deleteTempPreview();
      final persistedPath = await _persistAvatarFile(cropped.path);
      if (mounted) {
        setState(() {
        _avatarPath = persistedPath;
        _generatedAvatarPreviewPath = null;
      });
      }
    }
  }

  Future<void> _cropGeneratedAvatar() async {
    final previewPath = _generatedAvatarPreviewPath;
    if (previewPath == null) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final persistedPath = await _persistAvatarFile(previewPath);
      if (mounted) {
        setState(() {
        _avatarPath = persistedPath;
        _generatedAvatarPreviewPath = null;
      });
      }
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
      _deleteTempPreview();
      final persistedPath = await _persistAvatarFile(cropped.path);
      if (mounted) {
        setState(() {
        _avatarPath = persistedPath;
        _generatedAvatarPreviewPath = null;
      });
      }
    }
  }

  void _deleteTempPreview() {
    final p = _generatedAvatarPreviewPath;
    if (p != null) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  // ── Counted field ─────────────────────────────────────────────────────────

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
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.background,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: over ? Colors.red : AppTheme.cardBorder,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: over ? Colors.red : AppTheme.accentVivid,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving || _isGeneratingAvatar) return;
    if (!_formKey.currentState!.validate()) return;

    if (_descCtrl.text.length > _descMax) {
      AppSnackBar.show(context.l10n.descriptionLimitExceeded);
      return;
    }
    if (_greetCtrl.text.length > _greetMax) {
      AppSnackBar.show(context.l10n.greetingLimitExceeded);
      return;
    }

    setState(() => _isSaving = true);
    final l10n = context.l10n;
    bool ageVerified = false;

    try {
      final apiKey = await AppConfig.getDeepSeekApiKey();

      if (apiKey.isNotEmpty) {
        final combinedText = [
          _descCtrl.text.trim(),
          _behaviorCtrl.text.trim(),
          _greetCtrl.text.trim(),
        ].where((s) => s.isNotEmpty).join('\n\n');

        try {
          final check = await PromptCleanerService.instance
              .checkForMinorSignals(combinedText);


          if (check.hasConflict == true &&
              (check.severity == 'high' || check.severity == 'medium')) {
            // Реальный конфликт возраста — блокируем
            if (!mounted) return;
            if (check.severity == 'high') {
              AppSnackBar.show(context.l10n.personaDescriptionConflictHigh, isDuration: 10, isError: true);
            } else {
              AppSnackBar.show(context.l10n.personaDescriptionConflictMedium, isDuration: 10);
            }
            return;
          } else {
            if (!check.hasAge) {
              if (!mounted) return;
              AppSnackBar.show(l10n.personaAgeMissing); // жёлтый/оранжевый
              return;
            }
            ageVerified = true;
            if (mounted) {
              AppSnackBar.showSuccess(l10n.personaValidated, isIcon: true);
            }
          }
        }
        on NetworkException catch (_) {
          if (!mounted) return;
          AppSnackBar.showExtended(context.l10n.characterSavedNotVerifiedNetworkError, null);
        } on DeepSeekApiException catch (e) {
          // 401, 402, сеть — показываем ошибку, но НЕ блокируем сохранение
          AppSnackBar.showCreatePersonaValidationError(e, l10n);
          // ageVerified остаётся false, идём дальше
        }
       } else {
        AppSnackBar.show(l10n.characterSavedNotVerifiedGeneric);
        // ageVerified = false, идём дальше
      }
      if (!mounted) return;
      // --- Сохранение всегда доходит сюда, кроме реального конфликта ---
      final persona =
          _isEdit
              ? ref.read(personaProvider.notifier).getById(widget.personaId!)
              : null;

      final entity = PersonaEntity(
        id: widget.personaId ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        greeting: _greetCtrl.text.trim(),
        avatarPath: _avatarPath,
        avatarAssetPath: persona?.avatarAssetPath,
        behavior:
            _behaviorCtrl.text.trim().isEmpty
                ? null
                : _behaviorCtrl.text.trim(),
        galleryMode: _galleryMode,
        ageVerified: ageVerified,
      );

      if (!mounted) return;
      final notifier = ref.read(personaProvider.notifier);
      if (_isEdit) {
        notifier.updatePersona(entity);
      } else {
        notifier.create(entity);
      }

      if (mounted) Navigator.pop(context, true);
      final currentDesc = entity.description;
      if (currentDesc != _lastSentDescription) {
        PromptCleanerService.instance
            .cleanAndSave(entity.id, entity.description)
            .catchError((e) {
          if (e is NetworkException) {
            AppSnackBar.show(l10n.characterSavedNotVerifiedNetworkError);
          }
          if (e is DeepSeekApiException) {
            AppSnackBar.showCreatePersonaValidationError(e, l10n);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
