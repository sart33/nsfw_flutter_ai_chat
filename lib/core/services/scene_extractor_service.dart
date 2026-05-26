import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;
import 'package:http/http.dart' as http;
import 'package:nsfw_chat/core/config/app_config.dart';
import 'package:nsfw_chat/data/models/chat_message_model.dart';

import '../../domain/exceptions/app_exceptions.dart';
import '../config/scene_switch_patterns.dart';

class SceneSnapshot {
  final String? location;
  final String? locationDetails;
  final String? pose;
  final String? activity;
  final String? clothingState;
  final String? clothingDetails;
  final int intimacyLevel;
  final String? charactersPositioning;
  final String? timeOfDay;
  final double confidence;

  const SceneSnapshot({
    this.location,
    this.locationDetails,
    this.pose,
    this.activity,
    this.clothingState,
    this.clothingDetails,
    this.intimacyLevel = 0,
    this.charactersPositioning,
    this.timeOfDay,
    this.confidence = 0.0,
  });

  factory SceneSnapshot.fromJson(Map<String, dynamic> json) {
    return SceneSnapshot(
      location: json['location'] as String?,
      locationDetails: json['locationDetails'] as String?,
      pose: json['pose'] as String?,
      activity: json['activity'] as String?,
      clothingState: json['clothingState'] as String?,
      clothingDetails: json['clothingDetails'] as String?,
      intimacyLevel: (json['intimacyLevel'] as int? ?? 0).clamp(0, 4),
      charactersPositioning: json['charactersPositioning'] as String?,
      timeOfDay: json['timeOfDay'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Fallback when extraction fails
  static const SceneSnapshot fallback = SceneSnapshot(
    location: 'room',
    pose: 'standing',
    activity: 'smiling_at_you',
    intimacyLevel: 0,
    confidence: 0.5,
  );

  SceneSnapshot copyWith({
    String? location,
    String? locationDetails,
    String? pose,
    String? activity,
    String? clothingState,
    String? clothingDetails,
    int? intimacyLevel,
    String? charactersPositioning,
    String? timeOfDay,
    double? confidence,
  }) {
    return SceneSnapshot(
      location: location ?? this.location,
      locationDetails: locationDetails ?? this.locationDetails,
      pose: pose ?? this.pose,
      activity: activity ?? this.activity,
      clothingState: clothingState ?? this.clothingState,
      clothingDetails: clothingDetails ?? this.clothingDetails,
      intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      charactersPositioning:
          charactersPositioning ?? this.charactersPositioning,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      confidence: confidence ?? this.confidence,
    );
  }

  int get selectLevel {
    if (clothingState?.toLowerCase() == 'nude') {
      return 3;
    }
    if (clothingState?.toLowerCase() == 'light_dressed') {
      return 1;
    }
    if (clothingState?.toLowerCase() == 'fully_dressed') {
      return 0;
    }
    //if (intimacyLevel >= 3) return 2;
    final cl = (clothingState ?? '').toLowerCase();
    if (cl.contains('lingerie') ||
        cl.contains('bikini') ||
        cl.contains('swimsuit')) {
      return 2;
    }
    return intimacyLevel.clamp(0, 1);
  }

  bool get _isExplicitIntercourse {
    final fields =
        [activity ?? '', charactersPositioning ?? ''].join(' ').toLowerCase();

    // Убрать исключение для blowjob — оно блокировало детектор
    return RegExp(
      r'\b(penetrat|vaginal|anal\s+sex|anally|impaled\s+on|'
      r"(his|(male\s+)?character'?s?)\s+(cock|penis|dick|erection)|"
      r'insert[^,]*(finger|anus|anal)|'
      r'thrusting|'
      r'receiving\s+(\w+\s+){0,2}(sex|penetration)|'
      r'deep\s+penetration|vaginal\s+penetration|'
      r'mutual\s+oral|69[\s_]?position|'
      r'blowjob|blow\s+job|sucking\s+his|oral\s+sex|'
      r'spooning\s+sex|riding\s+user|cowgirl|'
      r'riding\s+user|'
      r'legs\s+wrapped\s+around|'
      r'vagin|fingers\s+touching|inviting\s+partner|'
      r'sex\s+in\s+\w+|'
      r'titjob|handjob|stroking\s+\w+s?\s+(cock|penis)|'
      r'tip\s+of\s+the|testicles|'
      r'scratching\s+his)\b',
      caseSensitive: false,
    ).hasMatch(fields);
  }

  static String _normalizeYouToUser(String s) {
    bool first = true;
    return s.replaceAllMapped(RegExp(r'\byou\b', caseSensitive: false), (m) {
      if (first) {
        first = false;
        return 'user';
      }
      return 'him';
    });
  }

  String toImagePrompt({String? userDescription}) {
    final parts = <String>[];
    final userRef = userDescription ?? '';

    // 1. Детект юзера в сцене
    final posLower = charactersPositioning?.toLowerCase() ?? '';
    final userInScene =
        userRef.isNotEmpty &&
        (posLower.contains('user') ||
            RegExp(r'\bhim\b').hasMatch(posLower) ||
            RegExp(r'\byou\b').hasMatch(posLower));
    final isMovementActivity =
        activity != null &&
        RegExp(
          r'\b(walk|run|swim|swim|ride|cycle|drive|climb|descend|ascend|'
          r'stroll|jog|hike|skate|ski|surf|sail|fly|jump|dance|'
          r'going|moving|traveling|heading)\w*\b',
          caseSensitive: false,
        ).hasMatch(activity!);

    // 2. Location — пропускаем если locationDetails уже содержит это слово
    if (location != null) {
      final locLower = location!.toLowerCase();
      final detailsLower = (locationDetails ?? '').toLowerCase();
      if (!detailsLower.contains(locLower) &&
          !detailsLower.contains(locLower.replaceAll('cafe', 'café'))) {
        parts.add(location!);
      }
    }
    if (locationDetails != null) parts.add(locationDetails!);

    if (pose != null) {
      var s = pose!;
      if (userRef.isEmpty) {
        s = s.replaceAll(
          RegExp(r'\b(passionate\s+)?kissing\b', caseSensitive: false),
          'blowing a kiss',
        );
      }
      s = s.replaceAll(RegExp(r'\bdoggy_?style\b', caseSensitive: false), '');
      s = s.replaceAll(
        RegExp(r'\bmissionary\b', caseSensitive: false),
        'lying_on_back',
      );
      s = s.replaceAll(
        RegExp(r'\bspooning\b', caseSensitive: false),
        'lying_on_side',
      );
      s = s.replaceAll(
        RegExp(r'\bcowgirl\b', caseSensitive: false),
        'sitting upright',
      );
      s = s.replaceAll(
        RegExp(r'\b69_?position\b', caseSensitive: false),
        'lying_on_back',
      );
      if (userRef.isEmpty) {
        s = s.replaceAll(
          RegExp(
            r'\b(together|sitting together|with user|holding user|beside user)\b',
            caseSensitive: false,
          ),
          'alone',
        );
        s = s.replaceAll(
          RegExp(r'\bwith\b', caseSensitive: false),
          'by herself',
        );
      } else {
        s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef);
      }
      final trimmed = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (trimmed.isNotEmpty) parts.add(trimmed);
    }
    final bool hadBlowjob =
        activity != null &&
        RegExp(
          r'\b(blowjob|blow\s+job|deepthroat|oral\s+sex|sucking)\b',
          caseSensitive: false,
        ).hasMatch(activity!);

    if (activity != null) {
      var s = _normalizeYouToUser(activity!);
      if (_isExplicitIntercourse) s = _cleanExplicitIntercourse(s);

      // titjob, handjob, standing doggy
      s = s.replaceAll(
        RegExp(r'\b(titjob|handjob)\b[^,]*', caseSensitive: false),
        '',
      );
      s = s.replaceAll(
        RegExp(r'\bstanding\s+doggy\b[^,]*', caseSensitive: false),
        '',
      );

      // deepthroat перед blowjob — чтобы не было "deepthroat deepthroating"
      // Сначала убрать blowjob/oral sex
      s = s.replaceAll(
        RegExp(
          r'\b(blowjob|blow\s+job|giving\s+head|oral\s+sex|mutual\s+oral\s+sex)\b',
          caseSensitive: false,
        ),
        '',
      );
      // Потом заменить deepthroat → deepthroating
      s = s.replaceAll(
        RegExp(r'\bdeepthroat\b', caseSensitive: false),
        'deepthroating',
      );
      // vaginal/anal/deep penetration — вся клауза
      s = s.replaceAll(
        RegExp(
          r'\b(vaginal|anal|deep|ass)\s+penetration\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );

      // cowgirl → sitting upright
      s = s.replaceAll(
        RegExp(r'\bcowgirl\b', caseSensitive: false),
        'sitting upright',
      );

      // riding user/him → убрать всю клаузу
      s = s.replaceAll(
        RegExp(r'\briding\s+(users?|him)\b[^,]*', caseSensitive: false),
        '',
      );

      // user везде где остался

      s = s.replaceAll(
        RegExp(r'\b(cock|penis|dick|erection)\b', caseSensitive: false),
        '',
      );

      // mutual oral sex целиком → deepthroating:
      s = s.replaceAll(
        RegExp(r'\bmutual\s+oral\s+sex\b', caseSensitive: false),
        'deepthroating',
      );
      s = s.replaceAll(
        RegExp(
          r'\b(blowjob|blow\s+job|giving\s+head|oral\s+sex)\b',
          caseSensitive: false,
        ),
        'deepthroating',
      );

      if (userRef.isEmpty) {
        s = s.replaceAll(
          RegExp(r'\b(passionate\s+)?kissing\b', caseSensitive: false),
          'blowing a kiss',
        );
        s = s.replaceAll(
          RegExp(
            r'\b(together|sitting together|with user|talking with|holding arm with)\b',
            caseSensitive: false,
          ),
          'alone',
        );
        s = s.replaceAll(
          RegExp(r'\bwith\b', caseSensitive: false),
          'by herself',
        );
        s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), '');
      } else {
        s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef);
      }
      s = s.replaceAll(RegExp(r'\bwith\b', caseSensitive: false), 'by herself');
      // Безусловно — эти слова нигде кроме секса не нужны
      s = s.replaceAll(
        RegExp(
          r'\b(anal|vaginal|deep|ass)\s+(sex|penetration)\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
      s = s.replaceAll(
        RegExp(r'\bpenetrat\w*\b[^,]*', caseSensitive: false),
        '',
      );
      s = s.replaceAll(
        RegExp(r'\b(anal|vaginal|anus)\b', caseSensitive: false),
        '',
      );
      s = s.replaceAll(
        RegExp(r'\bdeeply\s+inside\b[^,]*', caseSensitive: false),
        '',
      );

      s = s.replaceAll(
        RegExp(r'\binviting\s+partner\b[^,]*', caseSensitive: false),
        '',
      );
      s = s.replaceAll(RegExp(r'\bpartner\b', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (s.isNotEmpty &&
          (!userInScene || intimacyLevel >= 2 || isMovementActivity)) {
        parts.add(s);
      }
    }

    if (clothingDetails != null) parts.add(clothingDetails!);
    if (clothingState?.toLowerCase() == 'nude') parts.add('nude, naked');

    if (charactersPositioning != null) {
      var pos = _normalizeYouToUser(charactersPositioning!);
      if (_isExplicitIntercourse) pos = _cleanExplicitIntercourse(pos);
      if (pose?.toLowerCase() == 'standing')
        pos = _cleanStandingContext(pos, userRef: userRef);
      var cleaned = _cleanPositioning(pos, userRef: userRef);
      // Добавить deepthroating если был blowjob
      if (hadBlowjob) {
        cleaned = cleaned.isEmpty ? 'deepthroating' : '$cleaned, deepthroating';
      }
      if (cleaned.isNotEmpty) parts.add(cleaned);
    }

    if (timeOfDay != null) parts.add(timeOfDay!);
    return parts.join(', ');
  }

  static String _cleanExplicitIntercourse(String raw) {
    var s = raw;

    // Разбить по ; как по ,
    s = s.replaceAll(';', ',');
    // stroking and sucking user's cock — вся клауза

    s = s.replaceAll(
      RegExp(r'\bblowjob\b[^,]*', caseSensitive: false),
      'deepthroating',
    );
    s = s.replaceAll(
      RegExp(r'\bgiving\s+the\b[^,]*', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\bentire\s+(cock|penis|dick)\b[^,]*', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\bdeep\s+in\s+her\s+throat\b[^,]*', caseSensitive: false),
      '',
    );
    // Дублирующиеся слова рядом
    s = s.replaceAll(RegExp(r'\b(\w+)\s+\1\b', caseSensitive: false), r'\1');

    s = s.replaceAll(
      RegExp(
        r"\b(stroking|sucking)\s+\w+\'?s?\s+(cock|penis|dick)\b[^,]*",
        caseSensitive: false,
      ),
      '',
    );

    // titjob — убрать
    s = s.replaceAll(RegExp(r'\btitjob\b[^,]*', caseSensitive: false), '');

    // testicles/balls — убрать клаузу
    s = s.replaceAll(
      RegExp(r'\b(testicles|balls|inner\s+thigh)\b[^,]*', caseSensitive: false),
      '',
    );

    // tip of the penis — убрать клаузу
    s = s.replaceAll(
      RegExp(
        r'\btip\s+of\s+the\s+(cock|penis|dick)\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // licking the tip — убрать клаузу
    s = s.replaceAll(
      RegExp(r'\blicking\s+the\s+tip\b[^,]*', caseSensitive: false),
      '',
    );
    // 69 позиция
    s = s.replaceAll(
      RegExp(r'\bin\s+69\s+position\b[^,]*', caseSensitive: false),
      'lying on back, spreading legs',
    );

    // sucking/licking cock — вся клауза
    s = s.replaceAll(
      RegExp(
        r'\b(sucking|licking)\s+(his\s+)?(cock|penis|dick)\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // while he ... — вся клауза
    s = s.replaceAll(
      RegExp(r'\b(while\s+)?he\s+\w+[^,]*', caseSensitive: false),
      '',
    );

    // его член — расширенный паттерн
    s = s.replaceAll(
      RegExp(
        r"\b(his|(the\s+)?(male\s+)?(character'?s?|partner'?s?))\s+"
        r'(cock|penis|dick|erection)\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // проникновение — вся клауза
    s = s.replaceAll(RegExp(r'\bpenetrat\w*\b[^,]*', caseSensitive: false), '');

    // receiving ... sex/penetration — расширен на несколько слов
    s = s.replaceAll(
      RegExp(
        r'\breceiving\s+(\w+\s+)?(sex|penetration)\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // on top thrusting deeply ... — расширен
    s = s.replaceAll(
      RegExp(r'\bon\s+top\s+thrusting\b[^,]*', caseSensitive: false),
      '',
    );

    // thrusting ... inside — вся клауза
    s = s.replaceAll(RegExp(r'\bthrusting\b[^,]*', caseSensitive: false), '');

    // impaled
    s = s.replaceAll(
      RegExp(r'\bimpaled\s+on\b[^,]*', caseSensitive: false),
      '',
    );

    // пальцы в отверстия
    s = s.replaceAll(
      RegExp(
        r'\binsert\w*\b[^,]*(finger|anus|anal)\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // legs wrapped around → legs raised
    s = s.replaceAll(
      RegExp(
        r'\blegs?\s+(tightly\s+)?wrapped\s+around\b[^,]*',
        caseSensitive: false,
      ),
      'legs raised',
    );

    // legs over shoulders → legs spread
    s = s.replaceAll(
      RegExp(r'\blegs?\s+over\b[^,]*', caseSensitive: false),
      'legs spread',
    );
    // vaginal/anal/deep penetration — вся клауза
    s = s.replaceAll(
      RegExp(
        r'\b(vaginal|anal|deep|ass)\s+penetration\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // sex in bathtub/shower/etc — вся клауза
    s = s.replaceAll(
      RegExp(r'\bsex\s+in\s+\w+\b[^,]*', caseSensitive: false),
      '',
    );

    // partner в сексуальном контексте
    s = s.replaceAll(
      RegExp(r'\b(around|with|on)\s+partner\b[^,]*', caseSensitive: false),
      '',
    );

    // riding user/him
    s = s.replaceAll(
      RegExp(r'\briding\s+(users?|him)\b[^,]*', caseSensitive: false),
      '',
    );

    // user везде где остался
    s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), '');
    // scratching his back
    s = s.replaceAll(
      RegExp(r'\bscratching\s+his\s+\w+\b[^,]*', caseSensitive: false),
      '',
    );

    // holds her up → pressed against the wall
    s = s.replaceAll(
      RegExp(r'\bholds?\s+her\s+up\b[^,]*', caseSensitive: false),
      'pressed against the wall',
    );

    // все клаузы где he — субъект
    s = s.replaceAll(RegExp(r'\bhe\s+\w+[^,]*', caseSensitive: false), '');

    // его руки
    s = s.replaceAll(
      RegExp(
        r'\bhis\s+arms?\s+(around|wrapped\s+around)\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );

    // остатки his/he/erect
    s = s.replaceAll(RegExp(r'\bhis\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\bhe\b', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r',?\s*\berect\b', caseSensitive: false), '');

    // зачистка мусора
    s = s.replaceAll(
      RegExp(
        r'\b(and|but|while|from|on|of|at|to|for|with|by|the|into|'
        r'behind|against|alongside|deeply|inside)\s*(?=,|$)',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    s = s.replaceAll(RegExp(r',\s*,'), ',');
    s = s.trim().replaceAll(RegExp(r'^,+|,+$'), '');

    return s;
  }

  static String _cleanStandingContext(String raw, {String userRef = ''}) {
    var s = raw;
    bool firstUser = true;
    s = s.replaceAllMapped(RegExp(r'\buser\b', caseSensitive: false), (m) {
      if (firstUser) {
        firstUser = false;
        return userRef;
      }
      return 'him';
    });
    if (userRef.isNotEmpty) {
      s = s.replaceAllMapped(
        RegExp(
          r'\b(right\s+)?(very\s+close\s+to|close\s+to|next\s+to|near)\s+(the\s+)?users?\b[^,]*',
          caseSensitive: false,
        ),
        (m) => '${m.group(1) ?? ''}${m.group(2)} $userRef',
      );
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bright?\s*\b(very\s+close\s+to|close\s+to|next\s+to|near)\s+(the\s+)?users?\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }
    // guiding/correcting — убирать всегда
    s = s.replaceAll(
      RegExp(
        r'\b(guiding|correcting|adjusting|directing|coaching)\s+(his|her)\s+\w+\b[^,]*',
        caseSensitive: false,
      ),
      '',
    );
    return s;
  }

  static String _cleanPositioning(String raw, {String userRef = ''}) {
    var s = raw;
    final hasUser = userRef.isNotEmpty;
    bool firstUser = true;
    s = s.replaceAllMapped(RegExp(r'\buser\b', caseSensitive: false), (m) {
      if (firstUser) {
        firstUser = false;
        return userRef;
      }
      return 'him';
    });
    // Баг 1 — только для sitting
    if (raw.toLowerCase().contains('sitting')) {
      if (hasUser) {
        s = s.replaceAllMapped(
          RegExp(
            r'\b(across\s+from|next\s+to|beside|opposite|in\s+front\s+of|'
            r'close\s+to|near|behind)\s+(the\s+)?users?\b',
            caseSensitive: false,
          ),
          (m) => '${m.group(1)!} $userRef', // сохраняем предлог
        );
      } else {
        s = s.replaceAll(
          RegExp(
            r'\b(across\s+from|next\s+to|beside|opposite|in\s+front\s+of|'
            r'close\s+to|near|behind)\s+(the\s+)?users?\b',
            caseSensitive: false,
          ),
          '',
        );
      }
    }

    // links her arm — убирать всегда (нет визуального смысла)
    s = s.replaceAll(
      RegExp(r'\blinks?\s+her\s+arm\b[^,]*', caseSensitive: false),
      '',
    );

    // 1. Физконтакт holds/grabs/etc
    if (hasUser) {
      // заменяем только user/him внутри клаузы
      // 1. Физконтакт
      s = s.replaceAllMapped(
        RegExp(
          r'\b(holds?|grabs?|pulls?|pushes?|leads?|drags?|guides?|takes?|wraps?|climbs?|presses?|pins?)\s[^,]*\busers?\b[^,]*',
          caseSensitive: false,
        ),
        (m) => m
            .group(0)!
            .replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef),
      );
      // him оставляем как есть — это может быть не юзер
    } else {
      s = s.replaceAll(
        RegExp(
          r'\b(holds?|grabs?|pulls?|pushes?|leads?|drags?|guides?|takes?|wraps?|climbs?|presses?|pins?)\s[^,]*\b(users?|him)\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // 2. holding his hand ... and
    if (hasUser) {
      // оставляем, him → userRef
      s = s.replaceAll(
        RegExp(r'\bhis\s+hand\b', caseSensitive: false),
        '$userRef hand',
      );
    } else {
      s = s.replaceAll(
        RegExp(r'\bholding\s+his\s+hand\b[^,]*?\band\s+', caseSensitive: false),
        '',
      );
    }

    // 3. holding user's/user hand ... and
    if (hasUser) {
      s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef);
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bholding\s+users?\s+hand\b[^,]*?\band\s+',
          caseSensitive: false,
        ),
        '',
      );
    }

    // 4. hand in hand / holding hands
    if (hasUser) {
      // оставляем как есть — визуально понятно
    } else {
      s = s.replaceAll(
        RegExp(r'\b(holding hands?|hand in hand)\b', caseSensitive: false),
        '',
      );
    }

    // 4b. side by side / arms brushing — убирать всегда (нет чёткого визуала)
    s = s.replaceAll(
      RegExp(r'\bside\s+by\s+side\b[^,]*', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r',?\s*\barms?\s+brushing\b[^,]*', caseSensitive: false),
      '',
    );

    // 5. Объятия hugs/embraces
    if (hasUser) {
      s = s.replaceAllMapped(
        RegExp(
          r'\b(hugs?|embraces?)\s[^,]*\busers?\b[^,]*',
          caseSensitive: false,
        ),
        (m) => m
            .group(0)!
            .replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef),
      );
      // him оставляем
    } else {
      s = s.replaceAll(
        RegExp(
          r'\b(hugs?|embraces?)\s[^,]*\b(users?|him)\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // 5b. while [кто-то] kneels beside/next to her — убирать только kneels
    // stands/sits/walks — оставлять
    if (hasUser) {
      // оставляем всё
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bwhile\s+(the\s+)?\w+\s+(kneels?)\s+(beside|next\s+to|behind|in\s+front\s+of)\s+her\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // 6. Поцелуй
    if (hasUser) {
      s = s.replaceAllMapped(
        RegExp(r'\bkisses?\s+users?\b[^,]*', caseSensitive: false),
        (m) => m
            .group(0)!
            .replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef),
      );
      // him оставляем
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bkisses?\s+(users?|him|his\s+\w+)\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // 7. jumps into user's arms
    if (hasUser) {
      s = s.replaceAll(RegExp(r"user's", caseSensitive: false), '$userRef\'s');
      s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef);
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bjumps?\s+into\s+(the\s+)?users?\s+\w+\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // 8. sits on user's lap
    if (hasUser) {
      s = s.replaceAll(RegExp(r"user's", caseSensitive: false), '$userRef\'s');
      s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef);
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bsits?\s+on\s+(the\s+)?users?\s+\w+\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
      s = s.replaceAll(RegExp(r"user's", caseSensitive: false), 'user');
    }

    // wrapping her arms around his — если юзер есть, оставляем (his → userRef)
    if (hasUser) {
      s = s.replaceAll(RegExp(r'\bhis\b', caseSensitive: false), userRef);
    } else {
      s = s.replaceAll(
        RegExp(
          r'\bwrapping\s+her\s+arms\s+around\s+his\s+\w+\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // whispering
    if (hasUser) {
      s = s.replaceAllMapped(
        RegExp(r'\bwhispering\b[^,]*\busers?\b[^,]*', caseSensitive: false),
        (m) => m
            .group(0)!
            .replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef),
      );
      // him оставляем как есть
    } else {
      // убираем только если есть упоминание user/him, иначе оставляем
      s = s.replaceAll(
        RegExp(
          r'\bwhispering\b[^,]*\b(users?|him)\b[^,]*',
          caseSensitive: false,
        ),
        '',
      );
    }

    // Шаг 9 — финальная зачистка user/him
    if (hasUser) {
      s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), userRef);
      s = s.replaceAll(RegExp(r'\byou\b', caseSensitive: false), userRef);
    } else {
      s = s.replaceAll(RegExp(r'\busers?\b', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'\bhim\b', caseSensitive: false), '');
      s = s.replaceAll(RegExp(r'\byou\b', caseSensitive: false), '');
    }

    // 10. Танцевальный контекст — восстанавливаем партнёра
    // "dancing closely with the ," → "dancing closely with a partner,"
    s = s.replaceAll(
      RegExp(r'\b(dancing[\w\s]+with)\s+(the\s+)?,', caseSensitive: false),
      'dancing closely with a partner,',
    );
    s = s.replaceAll(
      RegExp(r'\b(dancing[\w\s]+with)\s*$', caseSensitive: false),
      'dancing closely with a partner',
    );

    // 11. Висячие предлоги/союзы перед запятой или концом
    s = s.replaceAll(
      RegExp(
        r'\b(and|but|while|in front of|on top of|of|at|to|for|with|by|the|into|onto|behind|against)\s*(?=,|$)',
        caseSensitive: false,
      ),
      '',
    );
    // В _cleanPositioning, перед зачисткой мусора:
    s = s.replaceAll(RegExp(r'\bpenetrat\w*\b[^,]*', caseSensitive: false), '');
    s = s.replaceAll(
      RegExp(r'\b(anus|anal|vaginal)\b[^,]*', caseSensitive: false),
      '',
    );
    s = s.replaceAll(
      RegExp(r'\bdeeply\s+inside\b[^,]*', caseSensitive: false),
      '',
    );
    // 12. Зачистка мусора
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    s = s.replaceAll(RegExp(r',\s*,'), ',');
    s = s.trim().replaceAll(RegExp(r'^,+|,+$'), '');

    return s;
  }

  Map<String, dynamic> toMap() => {
    'location': location,
    'locationDetails': locationDetails,
    'pose': pose,
    'activity': activity,
    'clothingState': clothingState,
    'clothingDetails': clothingDetails,
    'intimacyLevel': intimacyLevel,
    'charactersPositioning': charactersPositioning,
    'timeOfDay': timeOfDay,
    'confidence': confidence,
  };
}

class SceneExtractorService {
  SceneExtractorService._();

  static final SceneExtractorService instance = SceneExtractorService._();

  static String buildUserDescription({
    required String gender,
    required String age,
    required String hairColor,
    required String ethnicity,
  }) {
    // 1. Этничность → слово для промпта
    final ethnicityWord = switch (ethnicity) {
      'white' || 'slavic' => 'european',
      'latino' => gender == 'woman' ? 'latina' : 'latino',
      'arab' => 'middle eastern',
      'asian' => 'asian',
      'black' => 'black',
      _ => ethnicity,
    };

    // 2. Нужно ли указывать волосы
    final isOld = age == 'old';
    final isObviousHair = switch (ethnicity) {
      'black' || 'latino' || 'asian' => hairColor == 'black',
      _ => false,
    };

    final String hairDesc;
    if (hairColor == 'bald') {
      hairDesc = 'bald';
    } else if (hairColor == 'gray' && isOld) {
      hairDesc = '';
    } else if (isObviousHair) {
      hairDesc = '';
    } else {
      hairDesc = switch (hairColor) {
        'red' => 'redhead',
        'blonde' => 'blonde',
        'black' => 'dark-haired',
        'gray' => 'gray-haired',
        'brown' => 'brown-haired',
        _ => '$hairColor-haired',
      };
    }

    // 3. Собираем: age + ethnicity + hair + gender
    final parts = [
      age,
      ethnicityWord,
      if (hairDesc.isNotEmpty) hairDesc,
      gender == 'woman' ? 'woman' : 'man',
    ];

    return parts.join(' ');
    // → 'young European redhead man'
    // → 'adult Middle Eastern dark-haired man'
    // → 'old Black woman'
  }

  // ── Scene switch detection patterns ────────────────────────────────
  // These patterns are used to detect when a new scene begins in the chat history.
  // Everything before the first matching pattern is considered part of the previous scene
  // and will be ignored for image generation. This helps keep the image prompt relevant
  // to the current location, time and context.

  // ── DeepSeek prompt ─────────────────────────────────────────────────

  static String _buildExtractionPrompt(String current, String context) => '''
You are a scene extraction engine for image generation.

INPUT STRUCTURE:
1) CURRENT MESSAGE — highest priority
2) PREVIOUS CONTEXT — fallback for missing fields only

────────────────────
PRIORITY RULES:

- ALWAYS use CURRENT MESSAGE over PREVIOUS CONTEXT
- Conflict → CURRENT MESSAGE wins
- activity → MUST come from CURRENT MESSAGE
- pose, location → persist from context only if not redefined

────────────────────
STRICT RULES:

1. Use ONLY provided text. NEVER invent.
2. Missing data → null
3. Output ONLY valid JSON, no commentary
4. Do NOT translate or modify text inside double quotes
5. ALL text fields MUST be in English only
6. Do NOT include "confidence" field
────────────────────
ALLOWED VALUES:

clothingState:

"fully_dressed" — clothing covers most body areas (jackets, jeans, coats, long dresses, layered clothing)

"light_dressed" — exposed arms and/or legs (shorts, t-shirts, sleeveless dresses, summer clothing)

"partially_undressed" | "underwear" | "topless" | "nude"

intimacyLevel:
  0 — neutral, no physical contact
  1 — light contact (holding hands, hugging, kissing)
  2 — intimate contact, partially undressed, foreplay
  3 — explicit sexual activity

pose: "sitting" | "standing" | "lying_on_back" | "lying_on_side" |
      "lying_on_stomach" | "kneeling" | "bending_over" | "crouching"

location: "cafe" | "restaurant" | "bar" | "street" | "park" | "car" |
          "lobby" | "elevator" | "bedroom" | "room" | "bathroom" |
          "shower" | "sofa" | "kitchen" | "balcony" | "beach" | "office"

PUBLIC locations (intimacyLevel max 1):
  cafe, restaurant, bar, street, park, lobby, beach, office

timeOfDay: "morning" | "afternoon" | "evening" | "night"

activity: short English phrase, what character does RIGHT NOW
  Examples: "running into waves", "turning back to look", 
            "kissing", "lying on stomach receiving oral"

────────────────────
OUTPUT — ONLY JSON:

{
  "location": "...",
  "locationDetails": "brief EN description of setting, e.g. 'dimly lit hallway, wooden door'",
  "timeOfDay": "...",
  "pose": "...",
  "activity": "...",
  "clothingState": "...",
  "clothingDetails": "brief EN description, e.g. 'red dress, heels' or null",
  "charactersPositioning": "brief EN spatial relation, e.g. 'she faces user, arms around his neck'",
  "intimacyLevel": 0
}

INPUT:

CURRENT MESSAGE:
$current

PREVIOUS CONTEXT:
$context
''';

  // ── In-memory cache: branchId → (snapshot, messageCount) ───────────
  final _cache = <String, (SceneSnapshot, int)>{};

  // ── Public API ──────────────────────────────────────────────────────

  /// Main entry point. Called by ChatImageService.
  /// Returns SceneSnapshot (replaces old SceneData).
  ///
  /// Algorithm:
  /// 1. Find current scene window (messages since last scene switch)
  /// 2. Check cache — if no new signals, return cached
  /// 3. Try DeepSeek extraction
  /// 4. Validate and fix result
  /// 5. Return result (or fallback on error)
  Future<SceneSnapshot> extractScene({
    required String branchId,
    required List<ChatMessageModel> messages,
  }) async {
    if (messages.isEmpty) return SceneSnapshot.fallback;

    // Remove image-only messages from ALL processing
    final textOnly =
        messages
            .where(
              (m) => m.imageLocalPath == null && m.content.trim().isNotEmpty,
            )
            .toList();
    if (textOnly.isEmpty) return SceneSnapshot.fallback;
    // Step 1: detect language
    final lastCharMsg = _getLastCharacterMessage(textOnly);
    final detectedLang =
        lastCharMsg != null ? langdetect.detect(lastCharMsg.content) : 'en';
    // Step 2: find current scene window
    final sceneWindow = _extractCurrentSceneWindow(textOnly, detectedLang);

    // Step 3: check cache
    final cached = _cache[branchId];
    if (cached != null && cached.$2 == _computeWindowHash(sceneWindow)) {
      return cached.$1;
    }

    // Step 3: prepare text and call DeepSeek
    // Split: last message = CURRENT (highest priority)
    // Everything before = PREVIOUS CONTEXT (lower priority)
    final lastMsg = sceneWindow.last;
    final previousMsgs =
        sceneWindow.length > 1
            ? sceneWindow.sublist(0, sceneWindow.length - 1)
            : <ChatMessageModel>[];

    final currentText = _formatMessage(lastMsg);
    final contextText = previousMsgs.map(_formatMessage).join('\n');

    try {
      final rawSnapshot = await _extractWithLLM(currentText, contextText);

      // Step 4: validate
      final validated = _validateAndFix(rawSnapshot);
      assert(() {
        debugPrint(
          '[SceneExtractor] Final snapshot: '
          '${jsonEncode(validated.toMap())}',
        );
        return true;
      }());

      // Step 5: cache and return
      final cacheKey = _computeWindowHash(sceneWindow);
      _cache[branchId] = (validated, cacheKey);
      return validated;
    } on NetworkException {
      rethrow;
    } on DeepSeekApiException {
      rethrow;
    } catch (e) {
      if (e is SocketException ||
          e is http.ClientException ||
          e is DioException && e.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      return SceneSnapshot.fallback;
    }
  }

  int _computeWindowHash(List<ChatMessageModel> window) {
    final content = window.map((m) => '${m.id}:${m.content}').join('|');
    return content.hashCode;
  }

  // ── Scene window extraction ─────────────────────────────────────────
  ChatMessageModel? _getLastCharacterMessage(List<ChatMessageModel> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isUser &&
          !m.isHidden &&
          m.imageLocalPath == null &&
          m.content.trim().isNotEmpty) {
        return m;
      }
    }
    return null;
  }

  /// Finds where the current scene starts.
  /// Scans messages from newest to oldest.
  /// When a scene-switch pattern is found in a message,
  /// everything from that message forward = current scene.
  /// If no switch found, returns last 6 messages.
  List<ChatMessageModel> _extractCurrentSceneWindow(
    List<ChatMessageModel> messages,
    String lang,
  ) {
    final textMessages =
        messages
            .where(
              (m) => m.imageLocalPath == null && m.content.trim().isNotEmpty,
            )
            .toList();
    if (textMessages.isEmpty) return [];

    final pattern = SceneSwitchPatterns.forLang(lang);
    if (pattern == null) {
      return textMessages.length > 6
          ? textMessages.sublist(textMessages.length - 6)
          : textMessages;
    }

    for (int i = textMessages.length - 1; i >= 0; i--) {
      if (pattern.hasMatch(textMessages[i].content)) {
        final window = textMessages.sublist(i);
        final limited =
            window.length > AppConfig.maxSceneWindowSize
                ? window.sublist(window.length - AppConfig.maxSceneWindowSize)
                : window;
        return limited;
      }
    }

    final fallback =
        textMessages.length > 6
            ? textMessages.sublist(textMessages.length - 6)
            : textMessages;
    return fallback;
  }

  String _formatMessage(ChatMessageModel m) {
    final role = m.isUser ? 'User' : 'Character';
    return '$role: ${m.content}';
  }

  // ── LLM extraction ──────────────────────────────────────────────────

  Future<SceneSnapshot> _extractWithLLM(
    String currentText,
    String contextText,
  ) async {
    final apiKey = await AppConfig.getDeepSeekApiKey();
    if (apiKey.isEmpty) throw const DeepSeekApiException('key_not_set');

    final response = await http.post(
      Uri.parse('${AppConfig.deepSeekBaseUrl}/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {
            'role': 'user',
            'content': _buildExtractionPrompt(currentText, contextText),
          },
        ],
        'max_tokens': 800,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode == 401) {
      throw const DeepSeekApiException('key_invalid');
    }
    if (response.statusCode == 402) {
      throw const DeepSeekApiException('insufficient_balance');
    }
    if (response.statusCode == 504 || response.statusCode == 503) {
      throw const DeepSeekApiException('service_unavailable');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DeepSeekApiException('http_error', statusCode: response.statusCode);
    }

    /// ----demonstration Snapshot for presentation----
    ///
//     final demoJson = '''
// {
//   "choices": [
//     {
//       "message": {
// "content": "{\\"location\\":\\"cafe\\",\\"locationDetails\\":\\"a cozy cafe with a blue awning, quiet late afternoon\\",\\"pose\\":\\"sitting\\",\\"activity\\":\\"sliding into the seat across from you, setting down her bag\\",\\"clothingState\\":\\"fully_dressed\\",\\"clothingDetails\\":\\"worn denim jacket over a simple sweater, messenger bag slung across her body\\",\\"intimacyLevel\\":0,\\"charactersPositioning\\":\\"she sits across the table from you, facing you\\",\\"timeOfDay\\":\\"afternoon\\",\\"confidence\\":0.0}"
//       }
//     }
//   ]
// }''';

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final rawContent =
        (responseJson['choices'] as List).first['message']['content'] as String;

    assert(() {
      debugPrint('[SceneExtractor] Raw LLM response: $rawContent');
      return true;
    }());

    final cleaned =
        rawContent.replaceAll('```json', '').replaceAll('```', '').trim();

    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    return SceneSnapshot.fromJson(map);
  }

  // ── Validation ──────────────────────────────────────────────────────

  /// Fixes logical contradictions in the extracted snapshot.
  SceneSnapshot _validateAndFix(SceneSnapshot raw) {
    var s = raw;

    // Public locations: intimacyLevel 3 → cap to 1
    final publicLocations = {
      'cafe',
      'street',
      'park',
      'restaurant',
      'office',
      'supermarket',
    };
    if (s.location != null &&
        publicLocations.contains(s.location!.toLowerCase())) {
      if (s.intimacyLevel >= 3) {
        s = s.copyWith(intimacyLevel: 1);
      }
    }

    // Bed/bedroom + intimacyLevel 0 → force selectLevel 2
    if (s.location != null && (s.location!.toLowerCase() == 'bed')) {
      if (s.intimacyLevel == 0) {
        s = s.copyWith(intimacyLevel: 2);
      }
    }

    // Баг 2: Минет в спальне/ванной → добавить floor в locationDetails
    if (s.pose?.toLowerCase() == 'kneeling' &&
            s.activity?.toLowerCase().contains('blowjob') == true ||
        s.activity?.toLowerCase().contains('oral') == true &&
            s.activity?.toLowerCase().contains('mutual') != true) {
      if (s.location != null &&
          (s.location!.toLowerCase().contains('bedroom') ||
              s.location!.toLowerCase().contains('bathroom') ||
              s.location!.toLowerCase().contains('room'))) {
        s = s.copyWith(
          locationDetails:
              s.locationDetails != null
                  ? '${s.locationDetails}, floor'
                  : 'floor',
        );
      }
    }

    return s;
  }
}
