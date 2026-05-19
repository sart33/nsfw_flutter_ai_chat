// ── Hair color — горизонтальный скролл с чипами ─────────

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';

import '../../core/config/app_theme.dart';
import '../../domain/entities/persona_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/persona_provider.dart';
import '../providers/settings_provider.dart';

class UserAppearanceCard extends ConsumerStatefulWidget {
  const UserAppearanceCard({
    this.expanded = false,
    this.onSaved,
    super.key,
    this.persona, // null → режим Settings
  });

  final PersonaEntity? persona;
  final bool expanded; // для коллапсибла — влияет на отображение заголовка и отступы
  final VoidCallback? onSaved;


  @override
  ConsumerState<UserAppearanceCard> createState() => _UserAppearanceCardState();
}

class _UserAppearanceCardState extends ConsumerState<UserAppearanceCard> {
  // Локальное состояние — правится до нажатия Save
  late bool _enabled;
  late String _gender;
  late String _age;
  late String _ethnicity;
  late String _hairColor;

  bool get _expanded => widget.expanded;
  bool get _isPersonaMode => widget.persona != null;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initFromSources();
  }

  void _initFromSources() {
    final settings = ref.read(settingsProvider);
    final p = widget.persona;

    _enabled   = p?.userAppearanceEnabled ?? settings.userAppearanceEnabled;
    _gender    = p?.userGender            ?? settings.userGender;
    _age       = p?.userAge               ?? settings.userAge;
    _ethnicity = p?.userEthnicity         ?? settings.userEthnicity;
    _hairColor = p?.userHairColor         ?? settings.userHairColor;
  }

  // ── Сохранение ──────────────────────────────────────────────────────────────

  void _save() {
    if (_isPersonaMode) {
      // Пишем в PersonaEntity
      final updated = widget.persona!.copyWith(
        userAppearanceEnabled: _enabled,
        userGender:            _gender,
        userAge:               _age,
        userEthnicity:         _ethnicity,
        userHairColor:         _hairColor,
      );

      ref.read(personaProvider.notifier).updatePersona(updated);
      widget.onSaved?.call();
    } else {
      // Пишем в Settings
      final notifier = ref.read(settingsProvider.notifier);
      notifier.setUserAppearanceEnabled(_enabled);
      notifier.setUserGender(_gender);
      notifier.setUserAge(_age);
      notifier.setUserEthnicity(_ethnicity);
      notifier.setUserHairColor(_hairColor);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // В режиме Settings — реагируем на изменения снаружи (другой экран и т.д.)
    // В режиме Persona — читаем только при инициализации, локальный стейт правится вручную
    if (!_isPersonaMode) {
      final settings = ref.watch(settingsProvider);
      _enabled   = settings.userAppearanceEnabled;
      _gender    = settings.userGender;
      _age       = settings.userAge;
      _ethnicity = settings.userEthnicity;
      _hairColor = settings.userHairColor;
    }


    final items =  [
      _SwitchTile(
        title: _isPersonaMode && !_expanded ? '' : context.l10n.userShowInImagesTitle,
        // В режиме персонажа subtitle убираем — коллапсибл снаружи уже объясняет контекст
        subtitle: context.l10n.userShowInImagesSubtitle,
        value: _enabled,
        onChanged: (v) {
          if (_isPersonaMode) {
            setState(() => _enabled = v);
          } else {
            ref.read(settingsProvider.notifier).setUserAppearanceEnabled(v);
          }
        },
        isDesktop: _isDesktop(context),
      ),
        _Divider(),
        _AppearanceToggleRow(
          label: context.l10n.userGender,
          options: const ['man', 'woman'],
          labels: [context.l10n.userGenderMan, context.l10n.userGenderWoman],
          value: _gender,
          onChanged: (v) => _isPersonaMode
              ? setState(() => _gender = v)
              : ref.read(settingsProvider.notifier).setUserGender(v),
        ),
        _Divider(),
        _AppearanceToggleRow(
          label: context.l10n.userAge,
          options: const ['young', 'adult', 'mature', 'senior', 'elderly'],
          labels: [context.l10n.userAgeYoung, context.l10n.userAgeAdult, context.l10n.userAgeMature, context.l10n.userAgeSenior, context.l10n.userAgeElderly],
          value: _age,
          onChanged: (v) => _isPersonaMode
              ? setState(() => _age = v)
              : ref.read(settingsProvider.notifier).setUserAge(v),
        ),
        _Divider(),
        _EthnicityRow(
          value: _ethnicity,
          onChanged: (v) => _isPersonaMode
              ? setState(() => _ethnicity = v)
              : ref.read(settingsProvider.notifier).setUserEthnicity(v),
        ),
        _Divider(),
        _HairColorRow(
          value: _hairColor,
          onChanged: (v) => _isPersonaMode
              ? setState(() => _hairColor = v)
              : ref.read(settingsProvider.notifier).setUserHairColor(v),
        ),
        // Кнопка Save — только в режиме персонажа
        if (_isPersonaMode) ...[
          _Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentVivid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  elevation: 0,
                ),
                onPressed: _save,
                child: Text(
                  context.l10n.save,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],

    ];
    final card = _isPersonaMode
        ? _PlainCard(children: items)
        : _SettingsCard(children: items);
    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Коллапсибл-обёртка для PersonaViewScreen
// Вставляй её и на десктопе (в левую панель), и на мобиле (в самый низ)
// ─────────────────────────────────────────────────────────────────────────────

class PersonaAppearanceCollapsible extends StatefulWidget {
  const PersonaAppearanceCollapsible({
    super.key,
    required this.persona,
  });

  final PersonaEntity persona;

  @override
  State<PersonaAppearanceCollapsible> createState() =>
      _PersonaAppearanceCollapsibleState();
}

class _PersonaAppearanceCollapsibleState
    extends State<PersonaAppearanceCollapsible> {
  bool _expanded = false;
  bool _wasExpanded = false;
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
    return Container(
      padding: _isDesktop(context) ? EdgeInsets.symmetric(horizontal: 16, vertical: 8): EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      // отступ от других карточек
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Кнопка-тоггл (стиль как в чате)
          GestureDetector(
            onTap: () => setState(() {
              _wasExpanded = _expanded;
              _expanded = !_expanded;
            }),
            child: AnimatedContainer(
              duration: Duration(milliseconds: _expanded ? 260 : 260),
              curve: Curves.easeInOut,
              // В свёрнутом — margin как у Edit/Delete (horizontal: 16)
              // В развёрнутом — margin 0, растягивается на всю ширину

              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: _expanded ? Radius.zero : const Radius.circular(16),
                ),
                border: Border.all(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.primaryAccent,
                    size: _expanded ? 24 : 24,
                  ),
                  const SizedBox(width: 6),
                  if (!_expanded)
                  Expanded(
                    child: Text(
                      context.l10n.userShowInImagesTitle, // "Присутствие на изображениях в чате"
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                    ),
                  ),

                ],
              ),
            ),
          ),

          // Содержимое
          AnimatedSize(
            duration: Duration(milliseconds: _expanded ? 1200 : 2600),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border.all(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.5),
                ),
              ),
              // убираем верхний бордер чтобы не дублировался с кнопкой
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: UserAppearanceCard(persona: widget.persona, expanded: _expanded,  onSaved: () => setState(() => _expanded = false),),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    color: AppTheme.cardBorder,
    indent: 16,
    endIndent: 16,
  );
}

class _HairColorRow extends StatelessWidget {
  const _HairColorRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;



  @override
  Widget build(BuildContext context) {
    var _options = [
      ('black', context.l10n.userHairBlack),
      ('brown', context.l10n.userHairBrown),
      ('blonde', context.l10n.userHairBlonde),
      ('red', context.l10n.userHairRed),
      ('gray', context.l10n.userHairGray),
      ('white', context.l10n.userHairWhite),
      ('bald', context.l10n.userHairBald),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.userHair,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options.map((opt) {
              final selected = value == opt.$1;
              return GestureDetector(
                onTap: () => onChanged(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accentVividButton : AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? AppTheme.accentVividButton : AppTheme.cardBorder,
                    ),
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Ethnicity — bottom sheet ─────────────────────────────

class _EthnicityRow extends StatelessWidget {
  const _EthnicityRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;


  static List<(String, String)> _getOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      ('white', l10n.userEthnicityWhite),
      ('black', l10n.userEthnicityBlack),
      ('asian', l10n.userEthnicityAsian),
      ('arab', l10n.userEthnicityArab),
      ('indian', l10n.userEthnicityIndian),
      ('latino', l10n.userEthnicityLatino),
      ('slavic', l10n.userEthnicitySlavic),
    ];
  }

  String _currentLabel (BuildContext context) {
    final _options = _getOptions(context);
    return _options.firstWhere((o) => o.$1 == value, orElse: () => _options.first).$2;

  }
  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ..._getOptions(context).map((opt) {
              final selected = value == opt.$1;
              return ListTile(
                title: Text(opt.$2,
                  style: TextStyle(
                    color: selected
                        ? AppTheme.accentVividButton
                        : AppTheme.textPrimary,
                    fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check, color: AppTheme.accentVividButton)
                    : null,
                onTap: () {
                  onChanged(opt.$1);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.userEthnicity,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showPicker(context),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentLabel(context),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.expand_more,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceToggleRow extends StatelessWidget {
  const _AppearanceToggleRow({
    required this.label,
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final List<String> labels;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final toggle = _MultiToggle(
      options: options,
      labels: labels,
      value: value,
      onChanged: onChanged,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // если тоггл не влезает рядом с лейблом — идём в колонку
          final tight = constraints.maxWidth < 360;
          if (tight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _labelStyle),
                const SizedBox(height: 8),
                toggle,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: Text(label, style: _labelStyle)),
              const SizedBox(width: 12),
              toggle,
            ],
          );
        },
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

}

// ── MultiToggle — расширение _SizeToggle на N вариантов ─

class _MultiToggle extends StatelessWidget {
  const _MultiToggle({
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> labels;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final isFirst = i == 0;
          final isLast = i == options.length - 1;
          return _ToggleSegment(
            label: labels[i],
            selected: value == options[i],
            isLeft: isFirst,
            isRight: isLast,
            onTap: () => onChanged(options[i]),
          );
        }),
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.isLeft,
    required this.onTap,
    this.isRight = false, // новый параметр

  });

  final String label;
  final bool selected;
  final bool isLeft;
  final bool isRight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentVividButton : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(isLeft ? 16 : 0),
            right: Radius.circular(isRight ? 16 : 0),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _PlainCard extends StatelessWidget {
  final List<Widget> children;
  const _PlainCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:  EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

BoxDecoration cardUserAppearanceDecoration({double radius = 16}) =>
    BoxDecoration(
// color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppTheme.lightBorder, width: 1),
    );


class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDesktop;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 14),
      child: !isDesktop
      ? Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ) : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SizedBox(height: 1,)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}