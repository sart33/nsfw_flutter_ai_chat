import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/widgets/custom_app_bar_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
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
        const SizedBox(height: 16),
      ],
    );
  }
}

class AboutAppContent extends StatelessWidget {
  const AboutAppContent({Key? key}) : super(key: key);

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

  static const _bodyStyleBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
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
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktop ? AppTheme.kContentMaxWidth : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.all(desktop ? 32 : 20),
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
                        _buildSupportSection(context, desktop),
                        _Divider(),
                        _buildWaysToSupportSection(context),
                        _Divider(),
                        _buildWaysToSupportSectionCrypto(context),
                        _Divider(),
                        _buildWaysToSupportSectionNOWPayments(context),
                        _Divider(),
                        _buildWaysToSupportSectionTON(context),
                        _Divider(),
                        _buildWaysToSupportSectionCard(context),
                        _Divider(),
                        _buildWaysToSupportSectionIBAN(context),
                        _Divider(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildParagraphBold(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(text, style: _bodyStyleBold),
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
        children: items.asMap().entries.map((entry) {
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

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      context.l10n.aboutTitle,
      children: [
        _buildParagraph('Uncensored Souls v:${AppConfig.appVersion}'),
        _buildParagraph(context.l10n.aboutNoCensorshipTitle),
        _buildBulletList([
          context.l10n.aboutNoCensorshipText,
          context.l10n.aboutNoCensorshipImages,
        ]),
        _buildParagraph(context.l10n.aboutStorage),
        _buildParagraph(context.l10n.imagesWarningLabel),
        _buildBulletList([
          context.l10n.imagesHiddenFromGallery,
          context.l10n.imagesVisibleInApp,
        ]),
        _buildParagraph(context.l10n.aboutPlatforms),
        _buildBulletList([
          "Android",
          "Windows (Beta)",
          "macOS (Alpha)",
        ]),
      ],
    );
  }

  Widget _buildCostSection(BuildContext context) {
    return _buildSection(
      context.l10n.costTitle,
      children: [
        _buildParagraph(context.l10n.costDescription),
        _buildBulletList([
          context.l10n.costChat,
          context.l10n.costImage,
        ]),
        _buildParagraph(context.l10n.costAverage),
      ],
    );
  }

  Widget _buildHowToStartSection(BuildContext context) {
    return _buildSection(
      context.l10n.howToStartTitle,
      children: [
        _buildNumberedList([
          context.l10n.howToStart1,
          context.l10n.howToStart2,
          context.l10n.howToStart3,
          context.l10n.howToStart4,
        ]),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return _buildSection(
      context.l10n.privacyTitle,
      children: [
        _buildBulletList([
          context.l10n.privacyNoDataToDev,
          context.l10n.privacyDirectApi,
          context.l10n.privacyNoAccess,
          context.l10n.privacyImagesHidden,
        ]),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context, bool desktop) {
    final buttonStyle = ElevatedButton.styleFrom(
      elevation: 6,
      backgroundColor: AppTheme.accentVivid,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
    );

    Widget projectButton = ElevatedButton(
      style: buttonStyle,
      onPressed: ()  => launchUrl(
        Uri.parse('https://sart33.github.io/uncensored-souls/')),
      child: Text(context.l10n.projectPage),

    );

    Widget instructionButton = ElevatedButton(
      style: buttonStyle,
      onPressed: ()  => launchUrl(
          Uri.parse('https://sart33.github.io/uncensored-souls/user-guide.html')),
      child: Text(context.l10n.instruction),
    );

    return _buildSection(
      context.l10n.support,
      children: [
        _buildParagraph(context.l10n.telegram),
        _buildParagraph(context.l10n.email),
        const SizedBox(height: 16),
        if (desktop)
          Center(
            child: SizedBox(
              width: 260,
              child: Column(
                children: [
                  projectButton,
                  const SizedBox(height: 12),
                  instructionButton,
                ],
              ),
            ),
          )
        else ...[
          projectButton,
          const SizedBox(height: 16),
          instructionButton,
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSupportOptionsSection(BuildContext context) {
    return _buildSection(
      context.l10n.supportOptionsTitle,
      children: [
        _buildBulletList([
          context.l10n.supportOption2,
          context.l10n.supportOption5,
          context.l10n.supportOption10,
        ]),
      ],
    );
  }

  Widget _buildWaysToSupportSection(BuildContext context) {
    return _buildSection(
      context.l10n.supportIntroTitle,
      children: [
        _buildParagraph(context.l10n.supportDescriptionLite),
        _buildSupportOptionsSection(context),
              ],
    );
  }

  Widget _buildWaysToSupportSectionCrypto(BuildContext context) {
    return _buildSection(
      context.l10n.supportCryptoTitle, // "Способы поддержки"
      children: [
        _buildParagraphBold(context.l10n.supportUsdtTitle),
        _buildParagraph(context.l10n.supportUsdtDescription),
        SizedBox(height: 8),
        // QR-код + адрес
        Center(
          child: Column(
            children: [
              Image.asset(
                'assets/images/usdt_qr.webp',
                // ← поменяй путь, если у тебя другой
                width: 240,
                height: 240,
              ),
              SizedBox(height: 12),
              const SelectableText(
                'TCAPRirtjDJ7qa1WYHhVwKwmmoC17Fepfe',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        _buildParagraph(context.l10n.supportUsdtFee),
      ],
    );
  }

  Widget _buildWaysToSupportSectionNOWPayments(BuildContext context) {
    return _buildSection(
      context.l10n.supportNowPaymentsTitle, // "Способы поддержки"
      children: [
        _buildParagraph(context.l10n.supportNowPaymentsDescription),
        Image.asset(
          'assets/images/now_payments_button_black.webp',
          width: 240,
          height: 60,
        ),
        // ← это просто картинка кнопки, она не кликабельная, кликабельная кнопка будет ниже'
      ],
    );
  }

  Widget _buildWaysToSupportSectionTON(BuildContext context) {
    return _buildSection(
      context.l10n.supportTonTitle,
      children: [
        _buildParagraph(context.l10n.supportTonDescription),
        _buildParagraph("[адрес / ссылка]"),
      ],
    );
  }

  Widget _buildWaysToSupportSectionCard(BuildContext context) {
    return _buildSection(
      context.l10n.supportCardTitle,
      children: [
        _buildBulletList([
          '${context.l10n.supportCardNumber} 4441 1110 8136 7306',
          '${context.l10n.supportCardName} HLIB IVANCHYK',
        ]),
      ],
    );
  }

  Widget _buildWaysToSupportSectionIBAN(BuildContext context) {
    return _buildSection(
      context.l10n.supportIbanTitle,
      children: [
        _buildBulletList([
          '${context.l10n.supportIban} UA103220010000026209341508272',
          '${context.l10n.supportSwift} SWIFT/BIC: UNJSUAUKXXX',
          '${context.l10n.supportRecipient} IVANCHYK HLIB',
        ]),

        const SizedBox(height: 16),
      ],
    );
  }
}