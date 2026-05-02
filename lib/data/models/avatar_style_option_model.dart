import 'package:flutter/material.dart';

/// Represents an avatar style option with template ID, intimacy level, and display properties.
class AvatarStyleOption {
  final int templateId;
  final String nameKey; // localization key or fallback English label
  final String intimacyLevel; // 'romantic' | 'office' | 'erotic'
  final IconData icon;

  const AvatarStyleOption({
    required this.templateId,
    required this.nameKey,
    required this.intimacyLevel,
    required this.icon,
  });

  /// All 6 avatar style options for templates 122-127.
  static final List<AvatarStyleOption> allOptions = [
    AvatarStyleOption(
      templateId: 122,
      nameKey: 'avatarStyleEveningDress',
      intimacyLevel: 'romantic',
      icon: Icons.nightlife,
    ),
    AvatarStyleOption(
      templateId: 123,
      nameKey: 'avatarStyleSummerDress',
      intimacyLevel: 'office',
      icon: Icons.wb_sunny,
    ),
    AvatarStyleOption(
      templateId: 124,
      nameKey: 'avatarStyleOffice',
      intimacyLevel: 'office',
      icon: Icons.business_center,
    ),
    AvatarStyleOption(
      templateId: 129,
      nameKey: 'avatarStyleParisEvening',
      intimacyLevel: 'romantic',
      icon: Icons.location_city,
    ),
    AvatarStyleOption(
      templateId: 130,
      nameKey: 'avatarParisianCafe',
      intimacyLevel: 'romantic',
      icon: Icons.local_cafe ,
    ),
    AvatarStyleOption(
      templateId: 127,
      nameKey: 'avatarStyleMorningCoffee',
      intimacyLevel: 'romantic',
      icon: Icons.coffee,
    ),
    AvatarStyleOption(
      templateId: 125,
      nameKey: 'avatarStyleLingerie',
      intimacyLevel: 'erotic',
      icon: Icons.favorite,
    ),
    AvatarStyleOption(
      templateId: 126,
      nameKey: 'avatarStyleBikini',
      intimacyLevel: 'erotic',
      icon: Icons.beach_access,
    ),
    AvatarStyleOption(
      templateId: 128,
      nameKey: 'avatarStyleNude',
      intimacyLevel: 'nsfw',
      icon: Icons.shield_moon_outlined,
    ),
  ];

  static AvatarStyleOption? findByTemplateId(int templateId) {
    try {
      return allOptions.firstWhere((o) => o.templateId == templateId);
    } catch (_) {
      return null;
    }
  }

  static List<AvatarStyleOption> getByIntimacyLevel(String level) {
    return allOptions.where((o) => o.intimacyLevel == level).toList();
  }
}
