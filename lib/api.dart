import 'package:supabase_flutter/supabase_flutter.dart';

/// Projet Supabase PARTAGÉ avec Duonom (clé publiable, protégée par la RLS).
const supabaseUrl = 'https://arxaouwzmqfvfmftlbio.supabase.co';
const supabaseAnonKey = 'sb_publishable_VwgG_Pvvhtb4dgC5eK52Og_gk2_D0pa';

class Movie {
  final String id, title;
  final String? titleFr, overview, poster, backdrop;
  final int? year, runtime, tmdbId, votes;
  final double affinity, rating;
  final bool exploratory;
  final List<String> genres, providers, directors, actors;

  Movie.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = (j['title'] ?? '') as String,
        titleFr = j['title_fr'] as String?,
        overview = j['overview'] as String?,
        poster = j['poster'] as String?,
        backdrop = j['backdrop'] as String?,
        year = j['year'] as int?,
        runtime = j['runtime'] as int?,
        tmdbId = (j['tmdb_id'] as num?)?.toInt(),
        votes = (j['votes'] as num?)?.toInt(),
        rating = ((j['rating'] ?? 0) as num).toDouble(),
        affinity = ((j['affinity'] ?? 0) as num).toDouble(),
        exploratory = (j['exploratory'] ?? false) as bool,
        genres = ((j['genres'] ?? []) as List).map((e) => e.toString()).toList(),
        providers = ((j['providers'] ?? []) as List).map((e) => e.toString()).toList(),
        directors = ((j['directors'] ?? []) as List).map((e) => e.toString()).toList(),
        actors = ((j['actors'] ?? []) as List).map((e) => e.toString()).toList();

  String get display => (titleFr != null && titleFr!.isNotEmpty) ? titleFr! : title;
}

class Api {
  static SupabaseClient get _c => Supabase.instance.client;
  static User? get user => _c.auth.currentUser;

  static Future<void> init() => Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  static Future<AuthResponse> signIn(String email, String pwd) =>
      _c.auth.signInWithPassword(email: email, password: pwd);
  static Future<AuthResponse> signUp(String email, String pwd) =>
      _c.auth.signUp(email: email, password: pwd);
  static Future<void> signOut() => _c.auth.signOut();

  /// Mode invité : connexion anonyme (aucun email requis).
  static Future<AuthResponse> signInAnonymously() => _c.auth.signInAnonymously();

  /// L'utilisateur courant est-il un compte invité (anonyme) ?
  static bool get isGuest => _c.auth.currentUser?.isAnonymous ?? false;

  /// Transforme un compte invité en compte permanent (garde les mêmes données).
  static Future<UserResponse> upgradeAccount(String email, String pwd) =>
      _c.auth.updateUser(UserAttributes(email: email, password: pwd));

  static Future<List<String>> providers() async {
    final r = await _c.from('df_prefs').select('providers').eq('user_id', user!.id).maybeSingle();
    if (r == null || r['providers'] == null) return [];
    return (r['providers'] as List).map((e) => e.toString()).toList();
  }

  static Future<void> setProviders(List<String> p) =>
      _c.from('df_prefs').upsert({'user_id': user!.id, 'providers': p}, onConflict: 'user_id');

  /// Réglage « uniquement mes plateformes » (défaut false = montrer tous les films).
  static Future<bool> onlyProviders() async {
    final r = await _c.from('df_prefs').select('only_providers').eq('user_id', user!.id).maybeSingle();
    if (r == null || r['only_providers'] == null) return false;
    return r['only_providers'] == true;
  }

  static Future<void> setOnlyProviders(bool value) =>
      _c.from('df_prefs').upsert({'user_id': user!.id, 'only_providers': value}, onConflict: 'user_id');

  static Future<int> swipeCount() async {
    final r = await _c.from('df_swipes').count(CountOption.exact).eq('user_id', user!.id);
    return r;
  }

  static List<Movie> _movies(dynamic data) =>
      (data as List).map((e) => Movie.fromJson(Map<String, dynamic>.from(e))).toList();

  static Future<List<Movie>> deck({String? group, double explore = 0.3, bool onlyProviders = false}) async {
    final r = await _c.rpc('df_deck', params: {
      'p_group': group,
      'p_limit': 12,
      'p_explore': explore,
      'p_only_providers': onlyProviders,
    });
    return _movies(r);
  }

  static Future<List<Movie>> forYou({double discovery = 0.0, bool onlyProviders = false}) async {
    final r = await _c.rpc('df_for_you', params: {
      'p_limit': 20,
      'p_discovery': discovery,
      'p_only_providers': onlyProviders,
    });
    return _movies(r);
  }

  static Future<bool> swipe(String movieId, String action, {String? group}) async {
    final r = await _c.rpc('df_swipe', params: {'p_movie': movieId, 'p_action': action, 'p_group': group});
    return r == true;
  }

  static Future<Map<String, dynamic>> createGroup() async =>
      Map<String, dynamic>.from(await _c.rpc('df_create_group', params: {'p_name': null}));
  static Future<Map<String, dynamic>> joinGroup(String code) async =>
      Map<String, dynamic>.from(await _c.rpc('df_join_group', params: {'p_code': code}));

  static Future<void> leaveGroup(String groupId) =>
      _c.from('df_group_members').delete().eq('group_id', groupId).eq('user_id', user!.id);

  static Future<int> importWatched(List<String> titles) async {
    int total = 0;
    for (var i = 0; i < titles.length; i += 300) {
      final batch = titles.sublist(i, i + 300 > titles.length ? titles.length : i + 300);
      final r = await _c.rpc('df_import_watched', params: {'p_titles': batch});
      if (r is int) total += r;
    }
    return total;
  }

  static Future<List<Map<String, dynamic>>> myGroups() async {
    final r = await _c.from('df_group_members').select('df_groups(*)');
    return (r as List)
        .map((e) => e['df_groups'])
        .where((e) => e != null)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> watchlist(String group) async {
    final r = await _c
        .from('df_watchlist')
        .select('watched, movie_id, df_movies(*)')
        .eq('group_id', group);
    return (r as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Infos riches via l'Edge Function 'tmdb-detail' (trailer, tagline, casting).
  /// Renvoie null si la fonction est absente / échoue — l'écran reste fonctionnel.
  static Future<Map<String, dynamic>?> detail(int tmdbId) async {
    try {
      final r = await _c.functions.invoke('tmdb-detail', body: {'tmdb_id': tmdbId});
      final data = r.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tous les films aimés (like / super) de l'utilisateur, plus récents d'abord.
  static Future<List<Movie>> likedMovies() async {
    final r = await _c
        .from('df_swipes')
        .select('created_at, action, df_movies(*)')
        .eq('user_id', user!.id)
        .inFilter('action', ['like', 'super'])
        .order('created_at', ascending: false);
    return (r as List)
        .map((e) => e['df_movies'])
        .where((e) => e != null)
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
