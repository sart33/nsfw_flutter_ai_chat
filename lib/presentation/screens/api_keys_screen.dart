import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nsfw_chat/l10n/app_localizations.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';

import 'home_screen.dart';

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
  String _originalDeepSeekKey = '';
  String _originalNovitaKey = '';
  bool _deepSeekChanged = false;
  bool _novitaChanged = false;
  bool _showHomeButton = false;

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
        _originalDeepSeekKey = deepSeekKey;
        _originalNovitaKey = novitaKey;
        _deepSeekController.text =
            deepSeekKey.isNotEmpty ? _maskKey(deepSeekKey) : '';
        _novitaController.text =
            novitaKey.isNotEmpty ? _maskKey(novitaKey) : '';
      });
    } finally {
      setState(() {
        _loading = false;
      });
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
      _originalDeepSeekKey = trimmed;
      _deepSeekController.text = _maskKey(trimmed);
      _deepSeekObscure = true;
      _deepSeekChanged = false;
    });

    _showSnackBar(context.l10n.deepSeekKeySaved);
    // Show home button if this is the first time setting the key (i.e. we came from splash screen)
    if (!Navigator.canPop(context) && mounted) {
      setState(() => _showHomeButton = true);
    }
  }

  Future<void> _deleteDeepSeekKey() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(context.l10n.deleteDeepSeekKey),
                content: Text(context.l10n.chatWillStopWorking),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      context.l10n.delete,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    await _storage.delete(key: 'deepseek_api_key');
    setState(() {
      _deepSeekSaved = false;
      _originalDeepSeekKey = '';
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
      _originalNovitaKey = trimmed;
      _novitaController.text = _maskKey(trimmed);
      _novitaObscure = true;
      _novitaChanged = false;
    });
    _showSnackBar(context.l10n.novitaKeySaved);
  }

  Future<void> _deleteNovitaKey() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(context.l10n.deleteNovitaKey),
                content: Text(context.l10n.imageGenerationWillStop),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      context.l10n.delete,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    await _storage.delete(key: 'novita_api_key');
    setState(() {
      _novitaSaved = false;
      _originalNovitaKey = '';
      _novitaController.clear();
      _novitaChanged = false;
    });
    _showSnackBar(context.l10n.keyDeleted);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
    return Card(
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isSaved ? Icons.check_circle : Icons.cancel,
                  color: isSaved ? Colors.green : Colors.redAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isSaved ? context.l10n.keySaved : context.l10n.keyNotSet,
                  style: TextStyle(
                    color: isSaved ? Colors.green : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: obscure,
              onChanged: onChanged,
              // добавить это
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: emptyHint,
                hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF222222),
                suffixIcon: IconButton(
                  onPressed: toggleObscure,
                  icon: Icon(
                    obscure ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: canSave ? onSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB86FC),
                    foregroundColor: Colors.black,
                  ),
                  child: Text(context.l10n.save),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: canDelete ? onDelete : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                  child: Text(context.l10n.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(context.l10n.apiKeys)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.l10n.apiKeys),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKeyCard(
              title: context.l10n.deepSeekApi,
              subtitle: context.l10n.requiredForChat,
              isSaved: _deepSeekSaved,
              controller: _deepSeekController,
              obscure: _deepSeekObscure,
              toggleObscure:
                  () => setState(() => _deepSeekObscure = !_deepSeekObscure),
              onSave: _saveDeepSeekKey,
              onChanged: (_) => setState(() => _deepSeekChanged = true),
              canSave:
                  _deepSeekChanged &&
                  _deepSeekController.text.trim().isNotEmpty,
              onDelete: _deleteDeepSeekKey,
              canDelete: _deepSeekSaved,
              emptyHint: context.l10n.pasteDeepSeekKey,
            ),
            const SizedBox(height: 20),
            _buildKeyCard(
              title: context.l10n.novitaAi,
              subtitle: context.l10n.requiredForImageGeneration,
              isSaved: _novitaSaved,
              controller: _novitaController,
              obscure: _novitaObscure,
              toggleObscure:
                  () => setState(() => _novitaObscure = !_novitaObscure),
              onSave: _saveNovitaKey,
              onChanged: (_) => setState(() => _novitaChanged = true),
              canSave:
                  _novitaChanged && _novitaController.text.trim().isNotEmpty,
              onDelete: _deleteNovitaKey,
              canDelete: _novitaSaved,
              emptyHint: context.l10n.pasteNovitaKey,
            ),
            const SizedBox(height: 24),
            if (_showHomeButton)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: Text(context.l10n.goToApp),
                    onPressed:
                        () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.keysStoredSecurely,
                style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
