import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/presentation/widgets/custom_app_bar_widget.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _QrToggle extends StatefulWidget {
  final String qrAsset; // путь к assets, напр. 'assets/icons/ton_qr.png'
  final bool isDesktop;

  const _QrToggle({required this.qrAsset, required this.isDesktop});

  @override
  State<_QrToggle> createState() => _QrToggleState();
}

class _QrToggleState extends State<_QrToggle> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    // на десктопе QR всегда виден, кнопка не нужна
    if (widget.isDesktop) {
      return _buildQr();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _show = !_show),
          child: Text(
            _show ? context.l10n.hideQr : context.l10n.showQr,
            style: const TextStyle(
              color: AppTheme.primaryAccent,
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              _show
                  ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildQr(),
                  )
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildQr() {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset(widget.qrAsset, fit: BoxFit.contain),
      ),
    );
  }
}

class _TelegramButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TelegramButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.background, width: 1),
      ),
      child: Material(
        color: const Color(0xFF2a2a2b),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/telegram_icon.webp',
                  width: 22,
                  height: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  context.l10n.sendTon,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== AMOUNT BUTTON =====================

class _LightningAmountButton extends StatelessWidget {
  final int amount;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  const _LightningAmountButton({
    required this.amount,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.textPrimary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isDisabled
                    ? AppTheme.cardBorder.withValues(alpha: 0.4)
                    : AppTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (isLoading) ...[
              const SizedBox(width: 28),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 28),
            ] else ...[
              Image.asset('assets/icons/blink_all.webp', height: 22),
              const SizedBox(width: 10),
            ],
            Text(
              context.l10n.supportLightningDonateAmount(amount),
              style: TextStyle(
                color:
                    isDisabled
                        ? AppTheme.background.withValues(alpha: 0.4)
                        : AppTheme.background,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== LIGHTNING WIDGET =====================

class _LightningDonateWidget extends StatefulWidget {
  final bool isDesktop;

  const _LightningDonateWidget({required this.isDesktop});

  @override
  State<_LightningDonateWidget> createState() => _LightningDonateWidgetState();
}

class _LightningDonateWidgetState extends State<_LightningDonateWidget> {
  bool _isLoading = false;
  int? _loadingAmount;

  // данные инвойса
  String? _paymentRequest;
  String? _deepLink;
  String? _qrUrl;
  int? _invoiceAmount;

  Future<void> _donate(int amountUsd) async {
    setState(() {
      _isLoading = true;
      _loadingAmount = amountUsd;
      // сбрасываем предыдущий инвойс
      _paymentRequest = null;
      _deepLink = null;
      _qrUrl = null;
      _invoiceAmount = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://beauty-finder.com.ua/api/donate/lightning'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amountUsd}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _paymentRequest = data['payment_request'] as String;
          _deepLink = data['deep_link'] as String;
          _qrUrl = data['qr_url'] as String;
          _invoiceAmount = amountUsd;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.supportLightningError)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.supportLightningError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingAmount = null;
        });
      }
    }
  }

  void _copyInvoice(BuildContext context) {
    if (_paymentRequest == null) return;
    Clipboard.setData(ClipboardData(text: _paymentRequest!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.supportLightningCopied,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWallet(BuildContext context) async {
    if (_deepLink == null) return;
    try {
      await launchUrl(
        Uri.parse(_deepLink!),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.supportLightningNoWallet)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amounts = [2, 5, 10];
    final hasInvoice = _paymentRequest != null;

    Widget buttons = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children:
          amounts.map((amount) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: amount != amounts.last ? 16.0 : 0,
              ),
              child: _LightningAmountButton(
                amount: amount,
                isLoading: _isLoading && _loadingAmount == amount,
                isDisabled: _isLoading,
                onTap: () => _donate(amount),
              ),
            );
          }).toList(),
    );

    if (widget.isDesktop) {
      buttons = Center(child: SizedBox(width: 260, child: buttons));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buttons,
        if (_isLoading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (hasInvoice) ...[
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '\$${_invoiceAmount} ${context.l10n.viaLightning}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.supportLightningScanOrOpen,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.network(
                    _qrUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder:
                        (_, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                    errorBuilder:
                        (_, __, ___) => const Icon(Icons.qr_code, size: 60),
                  ),
                ),
                const SizedBox(height: 16),

              widget.isDesktop
                  ? Center(
                    child: SizedBox(
                      width: 350,
                      child: GestureDetector(
                        onTap: () => _copyInvoice(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _paymentRequest!,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.copy,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  : GestureDetector(
                    onTap: () => _copyInvoice(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _paymentRequest!,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
              if (!widget.isDesktop) ...[
                const SizedBox(height: 16),

                SizedBox(
                  width: 260,
                  child: GestureDetector(
                    onTap: () => _openWallet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentVivid,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.supportLightningOpenWallet,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: 260,
                  child: GestureDetector(
                    onTap: () => _copyInvoice(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppTheme.accentVivid),
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.supportLightningCopyInvoice,
                          style: const TextStyle(
                            color: AppTheme.accentVivid,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _KofiButton extends StatelessWidget {
  final VoidCallback onTap;

  const _KofiButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icons/ko_fi.webp', width: 28, height: 28),
              const SizedBox(width: 10),
              Text(
                context.l10n.supportKofiButton,
                style: const TextStyle(
                  color: Color(0xFF434B57),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class _BoostyButton extends StatelessWidget {
//   final VoidCallback onTap;
//
//   const _BoostyButton({required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: AppTheme.textPrimary,
//       borderRadius: BorderRadius.circular(14),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(14),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 14),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.start,
//             children: [
//               Image.asset(
//                 'assets/icons/boosty_logo.webp',
//                 width: 100,
//                 height: 24,
//               ),
//               // const SizedBox(width: 10),
//               const Text(
//                 'Donate on Boosty',
//                 style: TextStyle(
//                   color: AppTheme.background,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   letterSpacing: 0.2,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

class SupportProjectContent extends StatelessWidget {
  const SupportProjectContent({Key? key}) : super(key: key);


  static const _sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );

  static const _bodyStyleBold = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
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
                // _buildTitle(context.l10n.supportProjectTitle),
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
                        _buildWaysToSupportSectionKofiCard(context),
                        _Divider(),
                        Center(
                          child: _buildParagraphBold(
                            context.l10n.supportCryptoTitle,
                          ),
                        ),
                        _buildWaysToSupportSectionLightningCard(context),
                        _Divider(),
                        _buildWaysToSupportSectionUSDT(context),
                        _Divider(),
                        _buildWaysToSupportSectionTON(context),
                        _Divider(),
                        Center(
                          child: _buildParagraphBold(
                            context.l10n.supportAdditionalTitle,
                          ),
                        ),
                        _buildWaysToSupportSectionNOWPayments(context),
                        _Divider(),
                        _buildWaysToSupportSectionCard(context),
                        _Divider(),
                        _buildWaysToSupportSectionIBAN(context),
                        _Divider(),
                        _buildSupportSection(context),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(text, style: _bodyStyleBold, textAlign: TextAlign.center),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: AppTheme.lightBorder,
          indent: 200,
          endIndent: 200,
        ),
        SizedBox(height: 16),
      ],
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

  Widget _buildSupportIntroSection(BuildContext context) {
    return _buildSection(
      context.l10n.supportIntroTitle,
      children: [_buildParagraph(context.l10n.supportDescription)],
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
        // _buildParagraph(context.l10n.supportSmallContributions),
      ],
    );
  }

  Widget _buildWaysToSupportSectionUSDT(BuildContext context) {
    final desktop = _isDesktop(context);
    const usdtAddress = 'TCAPRirtjDJ7qa1WYHhVwKwmmoC17Fepfe';

    return _buildSection(
      context.l10n.supportUsdtTitle,
      children: [
        _buildParagraph(context.l10n.supportUsdtDescription),
        const SizedBox(height: 8),

          // QR-код
          Center(
            child: _QrToggle(
              qrAsset: 'assets/icons/usdt_qr.webp',
              isDesktop: desktop,
            ),
          ),
        const SizedBox(height: 12),

        // --- Адрес USDT ---
        desktop
            ? Center(
              child: SizedBox(
                width: 350,
                child: _buildCopyAddressField(context, usdtAddress),
              ),
            )
            : _buildCopyAddressField(context, usdtAddress),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCopyAddressField(BuildContext context, String address) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.walletAddressCopied,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                address,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWaysToSupportSectionKofiCard(BuildContext context) {
    final desktop = _isDesktop(context);

    return _buildSection(
      context.l10n.supportKofiTitle,
      children: [
        _buildParagraph(context.l10n.supportKofiDescription),
        const SizedBox(height: 20),
        if (!desktop) _KofiButton(onTap: () => _openKofi(context)),
        if (desktop)
          Center(
            child: SizedBox(
              width: 260,
              child: _KofiButton(onTap: () => _openKofi(context)),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _openKofi(BuildContext context) async {
    final uri = Uri.parse('https://ko-fi.com/usoulsai');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open Ko-fi')));
      }
    }
  }

  Widget _buildWaysToSupportSectionLightningCard(BuildContext context) {
    final desktop = _isDesktop(context);
    return _buildSection(
      'Lightning',
      children: [
        _buildParagraph(context.l10n.supportLightningDescription),
        const SizedBox(height: 20),
        _LightningDonateWidget(isDesktop: desktop),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWaysToSupportSectionNOWPayments(BuildContext context) {
    return _buildSection(
      context.l10n.supportNowPaymentsTitle,
      children: [
        _buildParagraph(context.l10n.supportNowpaymentsDescription),
        GestureDetector(
          onTap:
              () => launchUrl(
                Uri.parse(
                  'https://nowpayments.io/donation?api_key=68b5b9ab-d6d3-41a2-9c85-e91e0e367028',
                ),
                mode: LaunchMode.externalApplication,
              ),
          child: Center(
            child: Image.asset(
              'assets/icons/now_payments_button.webp',
              width: 240,
              height: 60,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  static const _walletAddress =
      'UQAFGVcmkQv1_iteb8HF17H2lwrHw8Ywbp-5epEMZ-qaUFWP';

  Future<void> _openTon(BuildContext ctx) async {
    final tonUri = Uri.parse('ton://transfer/$_walletAddress');

    try {
      final launched = await launchUrl(
        tonUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception();
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _walletAddress));
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              ctx.l10n.walletAddressCopied,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
        // показать SnackBar
      }
    }
  }

  Widget _buildWaysToSupportSectionTON(BuildContext context) {
    final desktop = _isDesktop(context);

    return _buildSection(
      context.l10n.supportTonTitle,
      children: [
        _buildParagraph(context.l10n.supportTonDescription),

        // --- Кнопка ---
        desktop
            ? const SizedBox(height: 20)
            : _TelegramButton(onTap: () => _openTon(context)),

          const SizedBox(height: 20),
          // --- QR-код ---
          Center(
            child: _QrToggle(
              qrAsset: 'assets/icons/ton_qr.webp',
              isDesktop: desktop,
            ),
          ),
        const SizedBox(height: 12),

        // --- Адрес кошелька ---
        desktop
            ? Center(
              child: SizedBox(
                width: 350,
                child: _buildTonAddressField(context),
              ),
            )
            : _buildTonAddressField(context),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTonAddressField(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(const ClipboardData(text: _walletAddress));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.walletAddressCopied,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _walletAddress,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  // Widget _buildWaysToSupportSectionBoostyCard(BuildContext context) {
  //   final desktop = _isDesktop(context);
  //
  //   return _buildSection(
  //     'Boosty',
  //     children: [
  //       _buildParagraph(context.l10n.supportBoostyDescription),
  //
  //       const SizedBox(height: 20),
  //
  //       // --- Кнопка ---
  //       if (!desktop) _BoostyButton(onTap: () => _openBoosty(context)),
  //
  //       if (desktop) ...[
  //         Center(
  //           child: SizedBox(
  //             width: 260,
  //             child: _BoostyButton(onTap: () => _openBoosty(context)),
  //           ),
  //         ),
  //         const SizedBox(height: 20),
  //         // --- QR-код ---
  //         Center(
  //           child: Container(
  //             width: 180,
  //             height: 180,
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             padding: const EdgeInsets.all(8),
  //             child: _QrToggle(
  //               qrAsset: 'assets/icons/boosty_qr.png',
  //               isDesktop: desktop,
  //             ),
  //           ),
  //         ),
  //       ],
  //
  //       const SizedBox(height: 8),
  //     ],
  //   );
  // }
  //
  // Future<void> _openBoosty(BuildContext context) async {
  //   final uri = Uri.parse('https://boosty.to/uncensoredsouls/donate');
  //   try {
  //     await launchUrl(uri, mode: LaunchMode.externalApplication);
  //   } catch (_) {
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Не удалось открыть Boosty')),
  //       );
  //     }
  //   }
  // }

  Widget _buildWaysToSupportSectionCard(BuildContext context) {
    return _buildSection(
      context.l10n.supportCardTitle,
      children: [
        _buildParagraph(context.l10n.supportCardDescription),
        _buildBulletList([
          '${context.l10n.supportCardNumber} 4441 1110 8136 7306',
          '${context.l10n.supportCardName} GLIB IVANCHYK',
        ]),
      ],
    );
  }

  Widget _buildWaysToSupportSectionIBAN(BuildContext context) {
    return _buildSection(
      context.l10n.supportIbanTitle,
      children: [
        _buildParagraph(context.l10n.supportIbanDescription),
        _buildBulletList([
          '${context.l10n.supportIban} UA103220010000026209341508272',
          '${context.l10n.supportRecipient} IVANCHYK GLIB',
        ]),

        const SizedBox(height: 16),
      ],
    );
  }

  // Widget _buildWaysToSupportSection(BuildContext context) {
  //   return _buildSection(
  //     context.l10n.supportWaysTitle,
  //     children: [
  //       _buildParagraph(context.l10n.supportQuickSupport),
  //       _buildBulletList([context.l10n.supportKofi]),
  //       const SizedBox(height: 8),
  //       _buildParagraph(context.l10n.supportCrypto),
  //       _buildBulletList([
  //         context.l10n.supportUsdt,
  //         context.l10n.supportTon,
  //       ]),
  //       const SizedBox(height: 8),
  //       _buildParagraph(context.l10n.supportInternational),
  //       _buildBulletList([context.l10n.supportPaypal]),
  //       const SizedBox(height: 8),
  //       _buildParagraph(context.l10n.supportBankTransfer),
  //       _buildBulletList([context.l10n.supportIban]),
  //       const SizedBox(height: 8),
  //       _buildParagraph(context.l10n.supportAlternative),
  //       _buildBulletList([context.l10n.supportBoosty]),
  //     ],
  //   );
  // }

  Widget _buildSupportSection(BuildContext context) {
    return _buildSection(
      context.l10n.contacts,
      children: [
        _buildParagraph(context.l10n.telegram),
        _buildParagraph(context.l10n.email),
      ],
    );
  }
}
