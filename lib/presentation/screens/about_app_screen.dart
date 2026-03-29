import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/widgets/custom_app_bar_widget.dart';
import '../../core/config/app_theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: context.l10n.aboutAppTitle),
      body: const AboutAppContent(),
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
        SizedBox(height: 16),
      ],
    );
  }
}

class AboutAppContent extends StatelessWidget {
  const AboutAppContent({Key? key}) : super(key: key);

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

  static const _numberedMarkerStyle = TextStyle(
    fontSize: 16,
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
        _buildTitle(context.l10n.aboutAppTitle),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: AppTheme.cardDecoration(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAboutSection(context),
              _Divider(),
              _buildCostSection(context),
              _Divider(),
              _buildHowToStartSection(context),
              _Divider(),
              _buildPrivacySection(context),
              _Divider(),
              _buildSupportSection(context),
              _Divider(),
              _buildWaysToSupportSection(context),
            ],
          ),
        ),
      ),
      ]
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

  Widget _buildNumberedList(List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            items.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ', style: _numberedMarkerStyle),
                    Expanded(child: Text(entry.value, style: _bodyStyle)),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      context.l10n.aboutTitle, // '🧠 About the App'
      children: [
        _buildParagraph('Uncensored Souls v:${AppConfig.appVersion}'),
        _buildParagraph(context.l10n.aboutNoCensorshipTitle),
        // 'Uncensored AI Roleplay Chat'
        _buildBulletList([
          context.l10n.aboutNoCensorshipText,
          context.l10n.aboutNoCensorshipImages, // '✓ Fully local'
        ]),

        _buildParagraph(context.l10n.aboutStorage),
        // 'All chats, characters, images and API keys stored only on your device.'
        _buildParagraph(context.l10n.imagesWarningLabel),
        // '⚠️ Images:'
        _buildBulletList([
          context.l10n.imagesHiddenFromGallery,
          // 'Not visible in Android gallery'
          context.l10n.imagesVisibleInApp,
          // 'Accessible only inside the app'
        ]),
        _buildParagraph(context.l10n.aboutPlatforms),
        _buildBulletList([
          "Android", // '✓ Fully local'
          "Windows (Beta)",
          "macOS (Alpha)",
        ]),
      ],
    );
  }

  Widget _buildCostSection(BuildContext context) {
    return _buildSection(
      context.l10n.costTitle, // '💰 Cost'
      children: [
        _buildParagraph(context.l10n.costDescription),
        _buildBulletList([
          context.l10n.costChat, // 'Chat: ~0.2–0.5 cents / hour'
          context.l10n.costImage, // 'Images: ~0.5 cents / generation'
        ]),
        _buildParagraph(context.l10n.costAverage), // 'Average: ~$2–3 per month'
      ],
    );
  }

  Widget _buildHowToStartSection(BuildContext context) {
    return _buildSection(
      context.l10n.howToStartTitle, // '🚀 How to Start'
      children: [
        _buildNumberedList([
          context.l10n.howToStart1, // 'Enter your DeepSeek API key (required)'
          context.l10n.howToStart2, // '(Optional) Add Novita AI key'
          context.l10n.howToStart3, // 'Choose a character or create your own'
          context.l10n.howToStart4, // 'Start chatting or try multi-chat'
        ]),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return _buildSection(
      context.l10n.privacyTitle, // '🔒 Privacy'
      children: [
        _buildBulletList([
          context.l10n.privacyNoDataToDev,
          // 'Data is never sent to the developer'
          context.l10n.privacyDirectApi,
          // 'Requests go directly to DeepSeek / Novita AI'
          context.l10n.privacyNoAccess,
          // 'Developer has zero access to your data'
          context.l10n.privacyImagesHidden,
          // 'Generated images not visible in Android gallery'
        ]),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return _buildSection(
      context.l10n.support, // '💬 Support'
      children: [
        _buildParagraph(context.l10n.telegram),
        _buildParagraph(context.l10n.email),

        const SizedBox(height: 16),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 6,                    // твой Faba стиль
            backgroundColor: AppTheme.accentVivid,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () {

          },
          child:  Text(context.l10n.projectPage), // "Project page"
        ),

        const SizedBox(height: 16),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 6,
            backgroundColor: AppTheme.accentVivid,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () {

          } ,
          child: Text(context.l10n.instruction),
        ),
        const SizedBox(height: 24),
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
      context.l10n.supportIntroTitle, // "💬 Ways to Support" (можно оставить или убрать заголовок)
      children: [
        _buildParagraph(context.l10n.supportDescriptionLite),
        _buildSupportOptionsSection(context),
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
}
