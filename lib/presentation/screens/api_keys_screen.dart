import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'dart:io' show Platform;

import '../widgets/custom_app_bar_widget.dart';

/// Screen for managing API keys stored securely.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _deepSeekController = TextEditingController();
  final TextEditingController _novitaController = TextEditingController();
  bool _deepSeekObscure = true;
  bool _novitaObscure = true;
  bool _deepSeekSaved = false;
  bool _novitaSaved = false;
  bool _loading = true;
  bool _deepSeekChanged = false;
  bool _novitaChanged = false;

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    try {
      if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return MediaQuery.of(context).size.width >= AppTheme.kDesktopBreakpoint;
  }

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final deepSeekKey = await _storage.read(key: 'deepseek_api_key') ?? '';
      final novitaKey = await _storage.read(key: 'novita_api_key') ?? '';
      setState(() {
        _deepSeekSaved = deepSeekKey.isNotEmpty;
        _novitaSaved = novitaKey.isNotEmpty;
        _deepSeekController.text =
        deepSeekKey.isNotEmpty ? _maskKey(deepSeekKey) : '';
        _novitaController.text =
        novitaKey.isNotEmpty ? _maskKey(novitaKey) : '';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 8)}••••••••';
  }

  Future<void> _saveDeepSeekKey() async {
    final trimmed = _deepSeekController.text.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: 'deepseek_api_key', value: trimmed);
    setState(() {
      _deepSeekSaved = true;
      _deepSeekController.text = _maskKey(trimmed);
      _deepSeekObscure = true;
      _deepSeekChanged = false;
    });
    _showSnackBar(context.l10n.deepSeekKeySaved);
  }

  Future<void> _deleteDeepSeekKey() async {
    final confirmed = await _confirmDelete(
      title: context.l10n.deleteDeepSeekKey,
      content: context.l10n.chatWillStopWorking,
    );
    if (!confirmed) return;
    await _storage.delete(key: 'deepseek_api_key');
    setState(() {
      _deepSeekSaved = false;
      _deepSeekController.clear();
      _deepSeekChanged = false;
    });
    _showSnackBar(context.l10n.keyDeleted);
  }

  Future<void> _saveNovitaKey() async {
    final trimmed = _novitaController.text.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: 'novita_api_key', value: trimmed);
    setState(() {
      _novitaSaved = true;
      _novitaController.text = _maskKey(trimmed);
      _novitaObscure = true;
      _novitaChanged = false;
    });
    _showSnackBar(context.l10n.novitaKeySaved);
  }

  Future<void> _deleteNovitaKey() async {
    final confirmed = await _confirmDelete(
      title: context.l10n.deleteNovitaKey,
      content: context.l10n.imageGenerationWillStop,
    );
    if (!confirmed) return;
    await _storage.delete(key: 'novita_api_key');
    setState(() {
      _novitaSaved = false;
      _novitaController.clear();
      _novitaChanged = false;
    });
    _showSnackBar(context.l10n.keyDeleted);
  }

  Future<bool> _confirmDelete({
    required String title,
    required String content,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title,
            style: const TextStyle(color: AppTheme.textPrimary)),
        content: Text(content,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel,
                style:
                const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete,
                style: const TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.success,
      content: Text(message, style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 3),
    ));
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback toggleObscure,
  }) {
    return InputDecoration(
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
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: IconButton(
        onPressed: toggleObscure,
        icon: Icon(
          obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppTheme.primaryAccent,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildKeyCard({
    required String title,
    required String subtitle,
    required bool isSaved,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggleObscure,
    required VoidCallback onSave,
    required bool canSave,
    required VoidCallback onDelete,
    required bool canDelete,
    required String emptyHint,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isSaved ? Icons.check_circle : Icons.cancel,
                color: isSaved ? Colors.green : AppTheme.warning,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isSaved ? context.l10n.keySaved : context.l10n.keyNotSet,
                style: TextStyle(
                  color: isSaved ? Colors.green : AppTheme.warning,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            obscureText: obscure,
            onChanged: onChanged,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _fieldDecoration(
              hint: emptyHint,
              obscure: obscure,
              toggleObscure: toggleObscure,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton(
                onPressed: canSave ? onSave : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  canSave ? AppTheme.accentVivid : Colors.transparent,
                  foregroundColor:
                  canSave ? Colors.white : AppTheme.textSecondary,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: AppTheme.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                    side: BorderSide(
                      color: canSave
                          ? Colors.transparent
                          : AppTheme.cardBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(context.l10n.save),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: canDelete ? onDelete : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: canDelete
                        ? AppTheme.warning
                        : AppTheme.warning.withAlpha(80),
                  ),
                  foregroundColor: canDelete
                      ? AppTheme.warning
                      : AppTheme.warning.withAlpha(80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: CustomAppBar(title: context.l10n.apiKeys),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentVivid),
        ),
      );
    }

    final desktop = _isDesktop(context);

    // ── Key card builders (reused in both layouts) ────────────────────────
    Widget deepSeekCard() => _buildKeyCard(
      title: context.l10n.deepSeekApi,
      subtitle: context.l10n.requiredForChat,
      isSaved: _deepSeekSaved,
      controller: _deepSeekController,
      obscure: _deepSeekObscure,
      toggleObscure: () =>
          setState(() => _deepSeekObscure = !_deepSeekObscure),
      onSave: _saveDeepSeekKey,
      onChanged: (_) => setState(() => _deepSeekChanged = true),
      canSave:
      _deepSeekChanged && _deepSeekController.text.trim().isNotEmpty,
      onDelete: _deleteDeepSeekKey,
      canDelete: _deepSeekSaved,
      emptyHint: context.l10n.pasteDeepSeekKey,
    );

    Widget novitaCard() => _buildKeyCard(
      title: context.l10n.novitaAi,
      subtitle: context.l10n.requiredForImageGeneration,
      isSaved: _novitaSaved,
      controller: _novitaController,
      obscure: _novitaObscure,
      toggleObscure: () =>
          setState(() => _novitaObscure = !_novitaObscure),
      onSave: _saveNovitaKey,
      onChanged: (_) => setState(() => _novitaChanged = true),
      canSave: _novitaChanged && _novitaController.text.trim().isNotEmpty,
      onDelete: _deleteNovitaKey,
      canDelete: _novitaSaved,
      emptyHint: context.l10n.pasteNovitaKey,
    );

    final footNote = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        context.l10n.keysStoredSecurely,
        style:
        const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(title: context.l10n.apiKeys),
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
              desktop ? AppTheme.kContentMaxWidth : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.all(desktop ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: deepSeekCard()),
                          const SizedBox(width: 16),
                          Expanded(child: novitaCard()),
                        ],
                      ),
                    )
                  else ...[
                    deepSeekCard(),
                    const SizedBox(height: 16),
                    novitaCard(),
                  ],
                  const SizedBox(height: 20),
                  footNote,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}