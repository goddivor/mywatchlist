/// Build variant for config selection.
enum BuildVariant {
  github;

  static BuildVariant fromString(dynamic value) {
    return BuildVariant.values.firstWhere(
      (e) => e.name == value?.toString().toLowerCase(),
      orElse: () => BuildVariant.github,
    );
  }
}

/// Supported platform types for maintenance flags.
enum PlatformType {
  myanimelist,
  anilist,
  kitsu,
  simkl,
}

/// Feature flags that can be toggled remotely.
enum FeatureFlag {
  aireviews,
}

/// Remote server configuration model.
///
/// Loaded from `{APP_CONFIG_URL}/{BUILD_VARIANT}/serverConfigV1.json`.
class Servers {
  String? strategy;
  int? maxLoad;
  bool? errorLogging;
  List<PreferredServers>? preferredServers;
  String? mwlAPIUrl;
  String? discordLink;
  String? storeUrl;
  Map<String, bool>? featureFlags;
  List<PlatformMaintenances>? platformMaintenances;

  Servers({
    this.strategy,
    this.maxLoad,
    this.errorLogging,
    this.preferredServers,
    this.mwlAPIUrl,
    this.discordLink,
    this.storeUrl,
    this.featureFlags,
    this.platformMaintenances,
  });

  Servers.fromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    strategy = json['strategy'];
    maxLoad = json['maxLoad'];
    errorLogging = json['errorLogging'];
    mwlAPIUrl = json['mwlAPIUrl'];
    discordLink = json['discordLink'];
    storeUrl = json['storeUrl'];
    if (json['platformMaintenances'] != null) {
      platformMaintenances = <PlatformMaintenances>[];
      for (final v in (json['platformMaintenances'] as List)) {
        platformMaintenances!.add(PlatformMaintenances.fromJson(v));
      }
    }
    if (json['featureFlags'] != null) {
      featureFlags = <String, bool>{};
      (json['featureFlags'] as Map).forEach((k, v) {
        featureFlags![k.toString()] = v as bool;
      });
    }
    if (json['preferredServers'] != null) {
      preferredServers = <PreferredServers>[];
      for (final v in (json['preferredServers'] as List)) {
        preferredServers!.add(PreferredServers.fromJson(v));
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'strategy': strategy,
        'maxLoad': maxLoad,
        'errorLogging': errorLogging,
        'mwlAPIUrl': mwlAPIUrl,
        'discordLink': discordLink,
        'storeUrl': storeUrl,
        'featureFlags': featureFlags,
        'preferredServers': preferredServers?.map((v) => v.toJson()).toList(),
        'platformMaintenances':
            platformMaintenances?.map((v) => v.toJson()).toList(),
      };
}

/// A preferred backend server with its current load.
class PreferredServers {
  String? url;
  int? load;

  PreferredServers({this.url, this.load});

  PreferredServers.fromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    url = json['url'];
    load = json['load'];
  }

  Map<String, dynamic> toJson() => {'url': url, 'load': load};
}

/// Platform maintenance status.
class PlatformMaintenances {
  PlatformType? platform;
  bool? maintenance;

  PlatformMaintenances({this.platform, this.maintenance});

  PlatformMaintenances.fromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    platform = PlatformType.values.firstWhere(
      (e) => e.name == json['platform'],
      orElse: () => PlatformType.myanimelist,
    );
    maintenance = json['maintenance'];
  }

  Map<String, dynamic> toJson() => {
        'platform': platform?.name,
        'maintenance': maintenance,
      };
}
