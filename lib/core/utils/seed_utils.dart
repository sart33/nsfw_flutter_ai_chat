import 'dart:math';

import 'package:nsfw_chat/core/config/app_config.dart';
/// Returns a randomised seed near the base value (101 ± 200).
/// Used for image regeneration to keep results visually close
/// to the original while avoiding duplicates.
int regenSeed({int? personaSeed}) {
  // Запиненный (не дефолтный) сид персонажа — отдаём как есть,
  // чтобы галерея совпадала со старым паком.
  if (personaSeed != null && personaSeed != AppConfig.defaultSeed) {
    return personaSeed;
  }
  const int seedBase  = AppConfig.defaultSeed;
  const int seedRange = AppConfig.seedRange;
  final int seedMin   = (seedBase - seedRange).clamp(1, seedBase);
  final int seedMax   = seedBase + seedRange;
  return seedMin + Random().nextInt(seedMax - seedMin + 1);
}