import 'package:flutter/material.dart';

import '../../core/config/app_theme.dart';

/// Рендер текста с разметкой `*...*`.
///
/// Речь и действия из пайплайна Adventure (превью `opening_text`,
/// greeting мультичата, сообщения мультичата) приходят завёрнутыми в
/// звёздочки, кавычки языка — внутри. Внутри звёздочек → голубой курсив,
/// снаружи → обычный нарратив. Маркер один (`*`), поэтому без markdown-
/// пакета: одна регулярка.
///
/// Переиспользуется и в превью Adventure, и в пузырях чата.
class SpeechText extends StatelessWidget {
  const SpeechText(
      this.text, {
        super.key,
        this.baseStyle,
        this.emphasisColor,
        this.textAlign,
      });

  final String text;

  /// Стиль нарратива (вне звёздочек). По умолчанию — основной текст 15/1.7.
  final TextStyle? baseStyle;

  /// Цвет речи/действий (внутри звёздочек). По умолчанию — голубой ниже.
  /// Подкрути под палитру / повесь на свой AppTheme-констант.
  final Color? emphasisColor;

  final TextAlign? textAlign;


  // dotAll НЕ включаем намеренно: одиночная «*» без пары не должна
  // проглатывать перенос строки и хватать целый абзац. Речь/действие
  // почти всегда в пределах строки. Если контент реально многострочный
  // внутри одной звёздочки — добавь dotAll: true и проверь на «сиротах».
  static final RegExp _marker = RegExp(r'\*(.+?)\*');

  /// Голый билдер спанов — без обёртки-виджета.
  ///
  /// Удобно, когда в [ChatBubble] уже есть свой `Text.rich`/`RichText`:
  /// отдать ему `children`, а `baseStyle` повесить на корневой span.
  /// Нарративные сегменты стиля не несут — наследуют корневой.
  static List<InlineSpan> spansOf(
      String text, {
        required TextStyle baseStyle,
        required Color emphasisColor,
      }) {
    final emphasis = baseStyle.copyWith(
      color: emphasisColor,
      fontStyle: FontStyle.italic,
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _marker.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(text: m.group(1), style: emphasis));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = baseStyle ??
        const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          height: 1.7,
        );
    final emphasis = emphasisColor ?? AppTheme.defaultEmphasis;

    return Text.rich(
      TextSpan(
        style: base,
        children: spansOf(text, baseStyle: base, emphasisColor: emphasis),
      ),
      textAlign: textAlign ?? TextAlign.start,
    );
  }
}