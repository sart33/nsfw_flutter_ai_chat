import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/enums/quick_action_type.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/domain/entities/persona_entity.dart';
import 'package:nsfw_chat/domain/exceptions/app_exceptions.dart';
import 'package:nsfw_chat/main.dart';
import 'package:nsfw_chat/presentation/providers/branch_provider.dart';
import 'package:nsfw_chat/presentation/providers/chat_provider.dart';
import 'package:nsfw_chat/presentation/providers/gallery_provider.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/create_edit_persona_screen.dart';
import 'package:nsfw_chat/presentation/screens/gallery_fullscreen_screen.dart';
import 'package:nsfw_chat/presentation/screens/persona_view_screen.dart';
import 'package:nsfw_chat/presentation/screens/settings_screen.dart';
import 'package:nsfw_chat/presentation/screens/support_the_project_screen.dart';
import 'package:nsfw_chat/presentation/widgets/chat_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/factory/database_helper.dart';
import '../../core/services/demo_serviece.dart';
import '../../core/utils/app_snack_bar.dart';
import '../../data/models/persona_model.dart';
import '../../domain/mappers/persona_mapper.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/donate_banner_bubble.dart';
import 'about_app_screen.dart';
import 'chat_image_fullscreen_screen.dart';
import 'home_screen.dart';

bool get _isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

class ChatScreen extends ConsumerStatefulWidget {
  final String branchId;
  final String entityId;
  final bool isMulti;
  final String greeting;
  final String title;
  final String? demoJsonPath; // ← NEW


  const ChatScreen({
    super.key,
    required this.branchId,
    required this.entityId,
    this.isMulti = false,
    this.greeting = '',
    this.title = '',
    this.demoJsonPath, // ← NEW
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with RouteAware {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _initialized = false;

  bool _sidePanelCollapsed = false;
  DemoConfig? _demoConfig;


  PersonaEntity? _singlePersona;
  List<PersonaEntity> _multiPersonas = [];
  String _multiBehavior = '';


  void _markDonateBannerActedOn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('donate_banner_1_shown', true);
    await prefs.setBool('donate_banner_2_shown', true);
  }

  void _dismissDonateBanner(String bannerId) {
    // Просто убираем из state — нотифаер
    ref.read(chatProvider(widget.branchId).notifier).removeBanner(bannerId);
  }

  void _resolveEntities(WidgetRef ref) {
    final personasAsync = ref.watch(personaProvider);
    if (personasAsync.isLoading || personasAsync.hasError) {
      _singlePersona = null;
      _multiPersonas = [];
      return;
    }
    final personas = personasAsync.value ?? [];

    if (!widget.isMulti) {
      _singlePersona =
          personas.where((p) => p.id == widget.entityId).firstOrNull;
    } else {
      final preset =
          ref
              .watch(multiPresetProvider)
              .where((p) => p.id == widget.entityId)
              .firstOrNull;
      if (preset != null) {
        _multiPersonas =
            personas.where((p) => preset.personaIds.contains(p.id)).toList();
        final trimmed =
            preset.behavior!.trim().replaceFirst(RegExp(r'[,.]+$'), '').trim();
        _multiBehavior =
            trimmed.isNotEmpty
                ? '$trimmed. ${AppConfig.addToMultiChatBehavior}'
                : AppConfig.addToMultiChatBehavior;
      }
    }
  }

  int _maxTokens(SettingsState settings) =>
      settings.aiResponseLimit.clamp(1, 8192);

  void _initIfNeeded() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(chatProvider(widget.branchId).notifier);
      if (!widget.isMulti && _singlePersona != null) {
        notifier.init(
          greeting: _singlePersona!.greeting,
          personaId: _singlePersona!.id,
          personaName: _singlePersona!.name,
          isMulti: false,
        );
        // Start age verification for single persona if needed
        if (!_singlePersona!.ageVerified) {
          notifier.verifyPersonaIfNeeded(_singlePersona!);
        }
      } else if (widget.isMulti) {
        notifier.init(greeting: widget.greeting, isMulti: true);
        // Start age verification for each multi persona if needed
        for (final persona in _multiPersonas) {
          if (!persona.ageVerified) {
            notifier.verifyPersonaIfNeeded(persona);
          }
        }
      } else {
        notifier.init();
      }
// // ← NEW: загрузить demo config если путь передан
//       if (widget.demoJsonPath != null) {
//         debugPrint('[ChatScreen] demoJsonPath = ${widget.demoJsonPath}');
//
//         DemoService.instance.load(widget.demoJsonPath!).then((cfg) {
//           debugPrint('[ChatScreen] demo loaded: ${cfg.demoId}');
//
//           if (mounted) setState(() => _demoConfig = cfg);
//         }).catchError((e) {
//           debugPrint('[ChatScreen] demo load FAILED: $e');
//         });
//       }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }



  @override
  void didPopNext() {
    ref.read(chatProvider(widget.branchId).notifier).resetVerification();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(chatProvider(widget.branchId).notifier);

      if (!widget.isMulti) {
        final map = await DatabaseHelper.instance.getPersonaById(widget.entityId);
        if (!mounted || map == null) return;
        final fresh = PersonaMapper.toEntity(PersonaModel.fromMap(map));
        if (!fresh.ageVerified) notifier.verifyPersonaIfNeeded(fresh);
      } else {
        final preset = ref.read(multiPresetProvider)
            .where((p) => p.id == widget.entityId).firstOrNull;
        if (preset == null) return;
        for (final id in preset.personaIds) {
          final map = await DatabaseHelper.instance.getPersonaById(id);
          if (!mounted || map == null) continue;
          final fresh = PersonaMapper.toEntity(PersonaModel.fromMap(map));
          if (!fresh.ageVerified) notifier.verifyPersonaIfNeeded(fresh);
        }
      }
    });
  }
  // ── DELETE BRANCH ─────────────────────────────────────────────────────

  void _deleteBranch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(
              context.l10n.deleteBranch,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            content: Text(
              context.l10n.allMessagesWillBeDeleted,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  context.l10n.cancel,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  context.l10n.delete,
                  style: const TextStyle(color: AppTheme.warning),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      final entityId =
          widget.isMulti
              ? 'multi:${widget.entityId}'
              : 'single:${widget.entityId}';
      ref.read(branchProvider(entityId).notifier).deleteBranch(widget.branchId);
      Navigator.pop(context);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(chatProvider(widget.branchId), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final l10n = context.l10n;
        switch (next.error) {
          case NetworkException():
            AppSnackBar.show(l10n.networkError, isError: true);
          case DeepSeekApiException():
            AppSnackBar.showDeepSeekError(next.error! as DeepSeekApiException, l10n);

          case NovitaApiException():
            AppSnackBar.showNovitaError(next.error! as NovitaApiException, l10n);

          case AgeVerificationException(:final reason):
            final failedPersonas = next.failedPersonas;
              widget.isMulti
                  ? AppSnackBar.showAgeConflictMulti(l10n, failedPersonas, reason)
                  : AppSnackBar.showAgeConflictSingle(l10n, _singlePersona!.id, reason);

          case HistoryException():
            AppSnackBar.show(l10n.errorHistory);

          default:
            AppSnackBar.show(l10n.errorUnknown);
        }
        ref.read(chatProvider(widget.branchId).notifier).clearError();
      }
    });

    // Listen for verification success
    ref.listen<ChatState>(chatProvider(widget.branchId), (prev, next) {
      // Show success snackbar when verification completes successfully
      if (prev?.isVerifying == true &&
          next.isVerifying == false &&
          next.verificationFailed == false &&
          prev?.error == null &&
          next.error == null) {
        AppSnackBar.showSuccess(context.l10n.personaValidated, isIcon: true);
      }
    });

    final chatState = ref.watch(chatProvider(widget.branchId));
    final settings = ref.watch(settingsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktop =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;

    if (_singlePersona != null) {
      ref.watch(
        galleryProvider(
          GalleryKey(_singlePersona!.id, _singlePersona!.galleryMode),
        ),
      );
    }
    for (final p in _multiPersonas) {
      ref.watch(galleryProvider(GalleryKey(p.id, p.galleryMode)));
    }
    _resolveEntities(ref);
    _initIfNeeded();

    const whiteStyle = TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w400,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        centerTitle: true,
        title:
            !widget.isMulti && _singlePersona != null
                ? GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  PersonaViewScreen(persona: _singlePersona!),
                        ),
                      ),
                  child: Text(widget.title, style: whiteStyle),
                )
                : Text(widget.title, style: whiteStyle),
        actions: [
          // Удалить чат — только на мобайле (на десктопе кнопка в панели)
          (!useDesktop)
              ? IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 24,
                  color: AppTheme.warning,
                ),
                tooltip: context.l10n.deleteBranch,
                onPressed: _deleteBranch,
              )
              : IconButton(
                icon: const Icon(
                  Icons.home_outlined,
                  size: 26,
                  color: AppTheme.textPrimary,
                ),
                tooltip: 'Home',
                onPressed:
                    () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    ),
              ),
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              size: useDesktop ? 26 : 24,
              color:
                  useDesktop ? AppTheme.primaryAccent : AppTheme.textSecondary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SupportProjectScreen()),
              );
            },
          ),
          if (useDesktop)
            IconButton(
              icon: const Icon(
                Icons.info_outline,
                size: 26,
                color: AppTheme.textSecondary,
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                  ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(
                Icons.settings,
                size: 26,
                color: AppTheme.textPrimary,
              ),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
            ),
          ),
        ],
      ),
      body:
          useDesktop
              ? _buildDesktopBody(context, chatState, settings)
              : _buildMobileBody(context, chatState, settings),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopBody(
    BuildContext context,
    ChatState chatState,
    SettingsState settings,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
        child: SizedBox(
          height: screenHeight - kToolbarHeight, // высота без AppBar
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Левая панель 300px — скроллируемая
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Скроллируемое содержимое — занимает всё доступное место
                    Expanded(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child:
                            _sidePanelCollapsed
                                ? const SizedBox(width: 300, height: 0)
                                : _buildDesktopSidePanel(context),
                      ),
                    ),
                    // Кнопка-стрелка прибита к низу
                    GestureDetector(
                      onTap:
                          () => setState(
                            () => _sidePanelCollapsed = !_sidePanelCollapsed,
                          ),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primaryAccent.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _sidePanelCollapsed
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: AppTheme.primaryAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _sidePanelCollapsed
                                  ? context.l10n.expandPanel
                                  : context.l10n.collapsePanel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(width: 1, color: AppTheme.cardBorder),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildChatContent(
                    context,
                    chatState,
                    settings,
                    showHeader: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Левая панель — single: аватар+кнопки; multi: скролл-список карточек
  Widget _buildDesktopSidePanel(BuildContext context) {
    if (!widget.isMulti) {
      return _buildSingleSidePanel(context);
    } else {
      return _buildMultiSidePanel(context);
    }
  }

  // ── SINGLE: аватар 3:4 + кнопки ─────────────────────────────────────

  Widget _buildSingleSidePanel(BuildContext context) {
    final p = _singlePersona;
    if (p == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => _openGalleryFromAvatar(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 9 / 14,
                      child: _buildAvatarImage(p),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (p.behavior != null && p.behavior!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.behavior!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentVivid,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(context.l10n.view),
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PersonaViewScreen(persona: p),
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(
                            context.l10n.editCharacter,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => CreateEditPersonaScreen(
                                        personaId: p.id,
                                      ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warning,
                          side: const BorderSide(color: AppTheme.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _deleteBranch,
                        child: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── MULTI: скролл-список карточек по каждому персонажу ───────────────

  Widget _buildMultiSidePanel(BuildContext context) {
    if (_multiPersonas.isEmpty) {
      return const Center(
        child: Icon(Icons.group, color: AppTheme.textSecondary, size: 48),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            itemCount: _multiPersonas.length,
            itemBuilder: (context, index) {
              final p = _multiPersonas[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => _openGalleryFromMultiAvatar(context, p.name),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 9 / 14,
                          child: _buildAvatarImage(p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentVivid,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text(
                          context.l10n.view,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonaViewScreen(persona: p),
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(
                          context.l10n.editCharacter,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => CreateEditPersonaScreen(
                                      personaId: p.id,
                                    ),
                              ),
                            ),
                      ),
                    ),
                    if (index < _multiPersonas.length - 1) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppTheme.cardBorder),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warning,
                side: const BorderSide(color: AppTheme.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                context.l10n.deleteBranch,
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: _deleteBranch,
            ),
          ),
        ),
      ],
    );
  }

  /// Общий виджет изображения аватара персонажа
  Widget _buildAvatarImage(PersonaEntity p) {
    final hasFile = p.avatarPath != null && File(p.avatarPath!).existsSync();
    final hasAsset = p.avatarAssetPath != null && p.avatarAssetPath!.isNotEmpty;

    if (hasFile) {
      return Image.file(
        File(p.avatarPath!),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
    }
    if (hasAsset) {
      return Image.asset(
        p.avatarAssetPath!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      );
    }
    return Container(
      color: AppTheme.cardBg,
      child: Center(
        child: Text(
          _initials(p.name),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — без изменений
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileBody(
    BuildContext context,
    ChatState chatState,
    SettingsState settings,
  ) {
    return _buildChatContent(context, chatState, settings);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT CONTENT — общий для обоих layout
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildChatContent(
    BuildContext context,
    ChatState chatState,
    SettingsState settings, {
    bool showHeader = true,
  }) {
    final inputLen = _inputCtrl.text.length;
    final inputLimit = settings.userInputLimit;
    final overLimit = inputLen > inputLimit;
    final canSend =
        !overLimit && !chatState.isLoading && _inputCtrl.text.trim().isNotEmpty;
    final lastAiIdx = chatState.messages.lastIndexWhere((m) => !m.isUser);
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktop =
        _isDesktopPlatform && screenWidth >= AppTheme.kDesktopBreakpoint;
    final bool isVerifyingOrFailed =
        chatState.isVerifying || chatState.verificationFailed;
    return Column(
      children: [
        // ── Messages ──────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            reverse: true,
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount:
                chatState.messages.length + (chatState.isLoading ? 1 : 0) + 1,
            itemBuilder: (context, index) {
              // Header item (bottom of reversed list = top of chat)
              if (index ==
                  chatState.messages.length + (chatState.isLoading ? 1 : 0)) {
                return showHeader
                    ? _buildChatHeader()
                    : const SizedBox.shrink();
              }

              // Loading indicator
              if (chatState.isLoading && index == 0) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final loadingOffset = chatState.isLoading ? 1 : 0;
              final msgIdx =
                  chatState.messages.length - 1 - (index - loadingOffset);
              final msg = chatState.messages[msgIdx];
              if (msg.isQuickAction || msg.isHidden) {
                return const SizedBox.shrink();
              }
              // Donate banner
              if (msg.isBanner) {
                return DonateBannerBubble(
                  isSecond: msg.content == 'banner_2',
                  onSupport: () {
                    _markDonateBannerActedOn();
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SupportProjectScreen()));
                  },
                  onDismiss: () => _dismissDonateBanner(msg.id),
                );
              }

              String? avatarPath;
              String? avatarAssetPath;
              if (!msg.isUser && !widget.isMulti && _singlePersona != null) {
                avatarPath = _singlePersona!.avatarPath;
                avatarAssetPath = _singlePersona!.avatarAssetPath;
              } else if (!msg.isUser && widget.isMulti) {
                final matched =
                    _multiPersonas
                        .where((p) => p.name == msg.senderName)
                        .firstOrNull;
                avatarPath = matched?.avatarPath;
                avatarAssetPath = matched?.avatarAssetPath;
              }

              final isLastAi = msgIdx == lastAiIdx && !chatState.isLoading;

              return ChatBubble(
                isUser: msg.isUser,
                senderName: msg.senderName,
                content: msg.content,
                avatarPath: avatarPath,
                avatarAssetPath: avatarAssetPath,
                imageLocalPath: msg.imageLocalPath,
                onImageTap:
                    msg.imageLocalPath != null
                        ? () =>
                            _openImageFullscreen(context, msg.imageLocalPath!)
                        : null,
                onImageRegen:
                    msg.imageLocalPath != null &&
                            !chatState.isLoading &&
                            isLastAi
                        ? () => _regenSceneImage(settings)
                        : null,
                chatFontSize: settings.chatFontSize,
                showRegenButton: isLastAi,
                onRegen: isLastAi ? () => _regenLastAI(settings) : null,
                onLongPress:
                    () => _showMessageActions(
                      context,
                      msg.id,
                      msg.content,
                      msg.isUser,
                      settings,
                    ),
                onAvatarTap:
                    (!msg.isUser && !widget.isMulti && _singlePersona != null)
                        ? () => _openGalleryFromAvatar(context)
                        : (!msg.isUser && widget.isMulti)
                        ? () =>
                            _openGalleryFromMultiAvatar(context, msg.senderName)
                        : null,
              );
            },
          ),
        ),
        if (chatState.isVerifying) ...[
          LinearProgressIndicator(
            backgroundColor: AppTheme.background,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
            minHeight: 2,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text(
                context.l10n.verifyingPersona,
                style: const TextStyle(
                  color: AppTheme.warning,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],

        // ── Input area ─────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    '$inputLen / $inputLimit',
                    style: TextStyle(
                      color: overLimit ? Colors.red : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!chatState.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickActionButton(
                            label: context.l10n.continueAction,
                            icon: Icons.play_arrow,
                            onTap:
                                isVerifyingOrFailed
                                    ? null
                                    : () => _sendQuick(
                                      context.l10n.continueAction,
                                      settings,
                                      quickActionType:
                                          QuickActionType.continueStory,
                                    ),
                          ),
                          const SizedBox(width: 8),
                          _QuickActionButton(
                            label: context.l10n.moreDetails,
                            icon: Icons.auto_stories,
                            onTap:
                                isVerifyingOrFailed
                                    ? null
                                    : () => _sendQuick(
                                      context.l10n.moreDetailsPrompt,
                                      settings,
                                      quickActionType:
                                          QuickActionType.moreDetails,
                                      tokenOverride: (_maxTokens(settings) * 2)
                                          .clamp(500, 2000),
                                      hiddenResetContent:
                                          context.l10n.resetNormalStyle,
                                    ),
                          ),
                          const SizedBox(width: 8),
                          if (useDesktop)
                            _QuickActionButton(
                              label: context.l10n.shorterAction,
                              onTap:
                                  isVerifyingOrFailed
                                      ? null
                                      : () => _sendQuick(
                                        context.l10n.shorterPrompt,
                                        settings,
                                        quickActionType: QuickActionType.shorter,
                                        tokenOverride: 150,
                                        hiddenResetContent:
                                            context.l10n.resetNormalStyle,
                                      ),
                              icon: Icons.compress,
                            ),
                          const SizedBox(width: 8),
                          if (!widget.isMulti)
                            _QuickActionButton(
                              label: context.l10n.photo,
                              icon: Icons.camera_alt_outlined,
                              onTap:
                                  isVerifyingOrFailed
                                      ? null
                                      : () => _generateSceneImage(settings),
                            ),

                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        enabled: !chatState.isLoading && !isVerifyingOrFailed,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText:
                                chatState.isLoading
                                    ? context.l10n.waitingForResponse
                                    : chatState.verificationFailed
                                        ? (chatState.failedPersonas.length == 1
                                            ? context.l10n.personaAgeConflictHint
                                            : context.l10n.personaAgeConflictHintPlural)
                                        : context.l10n.message,
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          canSend && !isVerifyingOrFailed
                              ? () => _send(settings)
                              : null,
                      icon: Icon(
                        Icons.send,
                        color:
                            canSend && !isVerifyingOrFailed
                                ? AppTheme.primaryAccent
                                : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Шапка чата (аватар + имя) — одинакова для мобайла и десктопа
  Widget _buildChatHeader() {
    if (!widget.isMulti && _singlePersona != null) {
      return GestureDetector(
        onTap: () => _openGalleryFromAvatar(context),
        onLongPress:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PersonaViewScreen(persona: _singlePersona!),
              ),
            ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: AvatarWidget(
                  imagePath: _singlePersona!.avatarPath,
                  assetPath: _singlePersona!.avatarAssetPath,
                  name: _singlePersona!.name,
                  size: 150,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _singlePersona!.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _singlePersona!.description.length > 100
                      ? '${_singlePersona!.description.substring(0, 100)}…'
                      : _singlePersona!.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isMulti && _multiPersonas.isNotEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    _multiPersonas.take(3).map((p) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap:
                              () => _openGalleryFromMultiAvatar(context, p.name),
                          onLongPress:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PersonaViewScreen(persona: p),
                                ),
                              ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: AvatarWidget(
                                  imagePath: p.avatarPath,
                                  assetPath: p.avatarAssetPath,
                                  name: p.name,
                                  size: 80,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }

    return const SizedBox.shrink();
  }

  // ── ACTIONS ───────────────────────────────────────────────────────────

  void _send(SettingsState settings) async {
    final content = _inputCtrl.text.trim();
    if (content.isEmpty) return;
    _inputCtrl.clear();
    setState(() {});

    // // ← NEW: demo mode intercept
    // final demo = _demoConfig;
    // if (demo != null && demo.textSequence != null) {
    //   ref.read(chatProvider(widget.branchId).notifier).addDemoExchange(
    //     userText: content,
    //     aiText: demo.textSequence!.aiResponse,
    //     personaName: _singlePersona?.name ?? 'Kristina',
    //     personaId: _singlePersona?.id ?? demo.personaId,
    //     thinkingMs: demo.textSequence!.thinkingDelayMs,
    //   );
    //   return; // не идём в реальный API
    // }

    final tokens = _maxTokens(settings);
    final notifier = ref.read(chatProvider(widget.branchId).notifier);
    if (!widget.isMulti && _singlePersona != null) {
      notifier.sendMessage(
        content: content,
        persona: _singlePersona!,
        maxTokens: tokens,
        quickActionType: QuickActionType.none,
      );
    } else if (widget.isMulti) {
      notifier.sendMultiMessage(
        content: content,
        personas: _multiPersonas,
        behavior: _multiBehavior,
        maxTokens: tokens,
        quickActionType: QuickActionType.none,
      );
    }
  }

  void _sendQuick(
    String content,
    SettingsState settings, {
    QuickActionType quickActionType = QuickActionType.continueStory,
    int? tokenOverride,
    String? hiddenResetContent,
  }) async {
    final tokens = tokenOverride ?? _maxTokens(settings);
    final notifier = ref.read(chatProvider(widget.branchId).notifier);

    if (!widget.isMulti && _singlePersona != null) {
      notifier.sendMessage(
        content: content,
        persona: _singlePersona!,
        maxTokens: tokens,
        isQuickAction: true,
        quickActionType: quickActionType,
        hiddenResetContent: hiddenResetContent,
      );
    } else if (widget.isMulti) {
      notifier.sendMultiMessage(
        content: content,
        personas: _multiPersonas,
        behavior: _multiBehavior,
        maxTokens: tokens,
        isQuickAction: true,
        quickActionType: quickActionType,
        hiddenResetContent: hiddenResetContent,
      );
    }
  }

  void _regenLastAI(SettingsState settings) {
    final tokens = _maxTokens(settings);
    final notifier = ref.read(chatProvider(widget.branchId).notifier);
    if (!widget.isMulti && _singlePersona != null) {
      notifier.regenLastAI(persona: _singlePersona, maxTokens: tokens);
    } else if (widget.isMulti) {
      notifier.regenLastAI(
        personas: _multiPersonas,
        behavior: _multiBehavior,
        maxTokens: tokens,
      );
    }
  }

  void _generateSceneImage(SettingsState settings) async {
    if (_singlePersona == null) return;
    // Demo mode: use pre-made images instead of real generation
    assert(() {
      debugPrint('[ChatScreen] demo config: $_demoConfig');
      return true;
    }());
    // final demo = _demoConfig;
    // if (demo != null && demo.photoSequence != null) {
    //   ref.read(chatProvider(widget.branchId).notifier).addDemoImageSequence(
    //     personaName: _singlePersona!.name,
    //     personaId: _singlePersona!.id,
    //     imagePaths: demo.photoSequence!.images,
    //     spinnerMs: demo.photoSequence!.spinnerDurationMs,
    //   );
    //   return;
    // }

    // Normal mode
    ref
        .read(chatProvider(widget.branchId).notifier)
        .generateSceneImage(persona: _singlePersona!, settings: settings);
  }

  void _regenSceneImage(SettingsState settings) async {
    if (_singlePersona == null) return;
    ref
        .read(chatProvider(widget.branchId).notifier)
        .generateSceneImage(persona: _singlePersona!, settings: settings, regen: true);
  }

  void _showMessageActions(
    BuildContext context,
    String messageId,
    String currentContent,
    bool isUser,
    SettingsState settings,
  ) {
    showModalBottomSheet(
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
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.copy,
                    color: AppTheme.primaryAccent,
                  ),
                  title: Text(
                    context.l10n.copy,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: currentContent));
                    if (!_isDesktopPlatform) {
                      Fluttertoast.showToast(
                          msg: context.l10n.copiedToClipboard);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                    color: AppTheme.primaryAccent,
                  ),
                  title: Text(
                    context.l10n.editCharacter,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(
                      context,
                      messageId,
                      currentContent,
                      settings,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: Text(
                    context.l10n.delete,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirm(context, messageId);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String messageId,
    String currentContent,
    SettingsState settings,
  ) {
    final editCtrl = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(
              context.l10n.editMessage,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
            content: TextField(
              controller: editCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 8,
              minLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  final newContent = editCtrl.text.trim();
                  if (newContent.isEmpty) return;
                  Navigator.pop(ctx);
                  ref
                      .read(chatProvider(widget.branchId).notifier)
                      .editMessage(
                        messageId: messageId,
                        newContent: newContent,
                        persona: !widget.isMulti ? _singlePersona : null,
                        personas: widget.isMulti ? _multiPersonas : null,
                        behavior: widget.isMulti ? _multiBehavior : null,
                        maxTokens: _maxTokens(settings),
                      );
                },
                child: Text(context.l10n.save),
              ),
            ],
          ),
    );
  }

  void _openGalleryFromAvatar(BuildContext context) {
    if (_singlePersona == null) return;
    final p = _singlePersona!;
    final gs = ref.read(
      galleryProvider(GalleryKey(p.id, p.galleryMode)),
    );

    final hasFile = p.avatarPath != null && File(p.avatarPath!).existsSync();
    final hasAsset = p.avatarAssetPath != null && p.avatarAssetPath!.isNotEmpty;
    // Если нет ни аватарки ни галереи — ничего не делаем
    if (!hasFile && !hasAsset && gs.images.isEmpty) {
      if (!_isDesktopPlatform) {
        Fluttertoast.showToast(msg: context.l10n.galleryEmpty);
      }
      return;
    }



    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryFullscreenScreen(
          images: gs.images,
          initialIndex: 0,
          personaDescription: p.description,
          personaId: p.id,
          galleryMode: p.galleryMode,
          avatarPath: hasFile ? p.avatarPath : (hasAsset ? p.avatarAssetPath : null),
        ),
      ),
    );
  }

  void _openGalleryFromMultiAvatar(BuildContext context, String senderName) {
    final persona =
        _multiPersonas.where((p) => p.name == senderName).firstOrNull;
    if (persona == null) return;
    final gs = ref.read(
      galleryProvider(GalleryKey(persona.id, persona.galleryMode)),
    );

    final hasFile = persona.avatarPath != null && File(persona.avatarPath!).existsSync();
    final hasAsset = persona.avatarAssetPath != null && persona.avatarAssetPath!.isNotEmpty;


    if (gs.images.isNotEmpty || hasFile || hasAsset) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryFullscreenScreen(
            images: gs.images,
            initialIndex: 0,
            personaDescription: persona.description,
            personaId: persona.id,
            galleryMode: persona.galleryMode,
            avatarPath: hasFile ? persona.avatarPath : (hasAsset ? persona.avatarAssetPath : null),
          ),
        ),
      );
    } else {
      if (!_isDesktopPlatform) {
        Fluttertoast.showToast(
            msg: context.l10n.galleryNameEmpty(persona.name));
      }
    }
  }

  void _openImageFullscreen(BuildContext context, String imagePath) {
    final chatState = ref.read(chatProvider(widget.branchId));
    final imagePaths = chatState.messages
        .where((m) => m.imageLocalPath != null)
        .map((m) => m.imageLocalPath!)
        .toList();
    final initialIndex = imagePaths.indexOf(imagePath);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatImageFullscreenScreen(
          imageProviders: imagePaths
          .map((p) => FileImage(File(p)) as ImageProvider)
          .toList(),
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String messageId) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(
              context.l10n.deleteMessage,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
            content: Text(
              context.l10n.messageAndFollowingWillBeDeleted,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref
                      .read(chatProvider(widget.branchId).notifier)
                      .deleteMessage(messageId);
                },
                child: Text(
                  context.l10n.delete,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }


}

// ── Quick action button ────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
