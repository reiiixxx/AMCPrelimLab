class ResponseValidator {
  static const Map<String, List<String>> domainKeywords = {
    'gamer': [
      'game', 'gaming', 'player', 'level', 'quest', 'mission', 'character',
      'controller', 'strategy', 'tactic', 'win', 'lose', 'score',
      'esports', 'competitive', 'fps', 'moba', 'rpg', 'mmorpg',
      'console', 'pc', 'playstation', 'xbox', 'nintendo', 'steam',
      'graphics', 'gameplay', 'multiplayer', 'campaign', 'dlc',
      'twitch', 'streamer', 'speedrun', 'raid', 'boss', 'loot',
    ],
    'daily_planner': [
      'schedule', 'calendar', 'appointment', 'meeting', 'task', 'todo',
      'deadline', 'priority', 'organize', 'plan', 'routine', 'habit',
      'productivity', 'time management', 'agenda', 'reminder', 'goals',
      'weekly', 'daily', 'monthly', 'timeline', 'milestone', 'tracking',
      'efficiency', 'workflow', 'planner', 'journal', 'bullet journal',
    ],
    'content_creator': [
      'video', 'youtube', 'tiktok', 'instagram', 'social media', 'content',
      'thumbnail', 'editing', 'camera', 'lighting', 'audio', 'microphone',
      'subscribers', 'views', 'engagement', 'algorithm', 'viral', 'trending',
      'monetization', 'adsense', 'sponsorship', 'brand', 'marketing',
      'premiere', 'photoshop', 'davinci', 'final cut', 'posting schedule',
      'analytics', 'seo', 'tags', 'description', 'caption', 'hashtag',
    ],
    'lawyer': [
      'law', 'legal', 'attorney', 'court', 'judge', 'lawsuit', 'litigation',
      'contract', 'agreement', 'clause', 'terms', 'liability', 'plaintiff',
      'defendant', 'civil', 'criminal', 'statute', 'regulation', 'ordinance',
      'jurisdiction', 'precedent', 'case law', 'brief', 'motion', 'discovery',
      'settlement', 'verdict', 'appeal', 'damages', 'tort', 'rights',
      'constitutional', 'federal', 'state', 'municipal', 'counsel',
    ],
    'artist': [
      'art', 'drawing', 'painting', 'sketch', 'canvas', 'brush', 'paint',
      'color', 'palette', 'composition', 'perspective', 'shading', 'anatomy',
      'portrait', 'landscape', 'still life', 'abstract', 'realism',
      'watercolor', 'acrylic', 'oil', 'digital art', 'illustration',
      'pencil', 'charcoal', 'pastel', 'easel', 'gallery', 'exhibition',
      'texture', 'contrast', 'saturation', 'hue', 'value', 'form',
    ],
  };

  // Check if response contains content from wrong domain
  static ValidationResult validateResponse(String personaId, String response) {
    response = response.toLowerCase();

    // If it's a refusal message, it's valid
    if (_isRefusalMessage(response)) {
      return ValidationResult(
        isValid: true,
        suggestedPersona: _extractSuggestedPersona(response),
      );
    }

    // Check for domain violations
    for (var entry in domainKeywords.entries) {
      String domain = entry.key;

      // Skip checking own domain
      if (domain == personaId) continue;

      // Count keyword matches from other domains
      int violations = 0;
      for (String keyword in entry.value) {
        if (response.contains(keyword)) {
          violations++;
        }
      }

      // If we find 3+ keywords from another domain, it's likely a violation
      if (violations >= 3) {
        return ValidationResult(
          isValid: false,
          violatingDomain: domain,
          suggestedPersona: _getDomainPersonaName(domain),
        );
      }
    }

    return ValidationResult(isValid: true);
  }

  static bool _isRefusalMessage(String response) {
    return response.contains('cannot help') ||
        response.contains('switch to') ||
        response.contains('i only handle');
  }

  static String? _extractSuggestedPersona(String response) {
    if (response.contains('gamer persona')) return 'Gamer';
    if (response.contains('daily planner persona')) return 'Daily Planner';
    if (response.contains('content creator persona')) return 'Content Creator';
    if (response.contains('lawyer persona')) return 'Lawyer';
    if (response.contains('artist persona')) return 'Artist';
    return null;
  }

  static String _getDomainPersonaName(String domain) {
    switch (domain) {
      case 'gamer': return 'Gamer';
      case 'daily_planner': return 'Daily Planner';
      case 'content_creator': return 'Content Creator';
      case 'lawyer': return 'Lawyer';
      case 'artist': return 'Artist';
      default: return 'Unknown';
    }
  }
}

class ValidationResult {
  final bool isValid;
  final String? violatingDomain;
  final String? suggestedPersona;

  ValidationResult({
    required this.isValid,
    this.violatingDomain,
    this.suggestedPersona,
  });
}