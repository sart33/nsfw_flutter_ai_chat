import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/widgets/custom_app_bar_widget.dart';
import '../../core/config/app_theme.dart';

class SupportProjectScreen extends StatelessWidget {
  const SupportProjectScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.supportProjectTitle),
      body: const SupportProjectContent(),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: AppTheme.cardBorder,
          indent: 0,
          endIndent: 0,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class SupportProjectContent extends StatelessWidget {
  const SupportProjectContent({Key? key}) : super(key: key);

  // ── Shared text styles ────────────────────────────────────────────────────
  static const _titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );

  static const _sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 16,
    color: AppTheme.textPrimary,
  );

  static const _bulletMarkerStyle = TextStyle(
    fontSize: 14,
    color: AppTheme.textPrimary,
  );

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context.l10n.supportProjectTitle), // "☕ Support the Project"

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: AppTheme.cardDecoration(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSupportIntroSection(context),
                  _Divider(),
                  _buildSupportOptionsSection(context),
                  _Divider(),
                  _buildWaysToSupportSection(context),
                  _Divider(),
                  _buildSupportSection(context),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Text(text, style: _titleStyle),
    );
  }

  Widget _buildSection(String title, {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(title, style: _sectionTitleStyle),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(text, style: _bodyStyle),
    );
  }

  Widget _buildBulletList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map(_buildBulletItem).toList(),
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: _bulletMarkerStyle),
          Expanded(child: Text(text, style: _bodyStyle)),
        ],
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────
  Widget _buildSupportIntroSection(BuildContext context) {
    return _buildSection(
      context.l10n.supportIntroTitle, // "☕ Support the Project" (или можно сделать без иконки)
      children: [
        _buildParagraph(context.l10n.supportDescription),
        // "This app is fully local, private, and has no subscriptions.\n\nIf the app is useful to you and you want new features and updates, you can support its development:"
      ],
    );
  }

  Widget _buildSupportOptionsSection(BuildContext context) {
    return _buildSection(
      context.l10n.supportOptionsTitle, // "💵 Support Options"
      children: [
        _buildBulletList([
          context.l10n.supportOption2,   // "$2 — support development"
          context.l10n.supportOption5,   // "$5 — faster updates"
          context.l10n.supportOption10,  // "$10 — serious support"
        ]),
        _buildParagraph(context.l10n.supportSmallContributions),
        // "Even small contributions make a big difference"
      ],
    );
  }

  Widget _buildWaysToSupportSection(BuildContext context) {
    return _buildSection(
      context.l10n.supportWaysTitle, // "💬 Ways to Support" (можно оставить или убрать заголовок)
      children: [
        _buildParagraph(context.l10n.supportQuickSupport), // "☕ Quick support"
        _buildBulletList([context.l10n.supportKofi]),     // "— Ko-fi (card, fast)"

        const SizedBox(height: 8),

        _buildParagraph(context.l10n.supportCrypto), // "💸 Crypto (lowest fees)"
        _buildBulletList([
          context.l10n.supportUsdt,
          context.l10n.supportTon,
        ]),

        const SizedBox(height: 8),

        _buildParagraph(context.l10n.supportInternational), // "🌍 International"
        _buildBulletList([context.l10n.supportPaypal]),

        const SizedBox(height: 8),

        _buildParagraph(context.l10n.supportBankTransfer), // "🏦 Bank transfer"
        _buildBulletList([context.l10n.supportIban]),

        const SizedBox(height: 8),

        _buildParagraph(context.l10n.supportAlternative), // "🧩 Alternative"
        _buildBulletList([context.l10n.supportBoosty]),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return _buildSection(
      context.l10n.contacts, // '💬 Support'
      children: [
        _buildParagraph(context.l10n.telegram),
        _buildParagraph(context.l10n.email),




      ],
    );
  }
}