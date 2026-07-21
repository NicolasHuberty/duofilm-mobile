import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(DuofilmApp(seenOnboarding: prefs.getBool('onboarded') ?? false));
}

class DuofilmApp extends StatelessWidget {
  final bool seenOnboarding;
  const DuofilmApp({super.key, required this.seenOnboarding});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Duomovie',
        debugShowCheckedModeBanner: false,
        theme: DF.theme(),
        home: seenOnboarding ? const Gate() : const Onboarding(),
      );
}

// ---------------------------------------------------------------------------
// Onboarding : 3 écrans d'explication
// ---------------------------------------------------------------------------
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _pc = PageController();
  int _i = 0;
  static const _pages = [
    ('🎬', 'Le film du soir, sans se disputer',
        'Swipez des films comme sur une appli de rencontre. À droite ce qui vous tente, à gauche ce que vous zappez.'),
    ('❤️', 'À deux ou à plusieurs',
        'Créez un groupe avec un code. Quand vous aimez tous le même film, c\'est un match : il rejoint votre liste commune.'),
    ('✨', 'Vraiment à votre goût',
        'Importez votre historique Netflix et l\'algo apprend ce que vous aimez — avec un curseur « découvrir plus » pour sortir de vos habitudes.'),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate()));
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              onPageChanged: (i) => setState(() => _i = i),
              itemCount: _pages.length,
              itemBuilder: (_, i) {
                final (emoji, title, body) = _pages[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(emoji, style: const TextStyle(fontSize: 88)),
                    const SizedBox(height: 32),
                    Text(title, textAlign: TextAlign.center, style: DF.serif(30)),
                    const SizedBox(height: 16),
                    Text(body, textAlign: TextAlign.center, style: DF.sans(16, c: DF.inkBody)),
                  ]),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  width: i == _i ? 22 : 8, height: 8,
                  decoration: BoxDecoration(
                      color: i == _i ? DF.accent : DF.muted, borderRadius: BorderRadius.circular(8)),
                )),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryButton(
              label: last ? 'C\'est parti' : 'Suivant',
              onTap: () => last
                  ? _finish()
                  : _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gate : oriente vers auth / plateformes / accueil
// ---------------------------------------------------------------------------
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  @override
  Widget build(BuildContext context) {
    if (Api.user == null) return const AuthScreen();
    return FutureBuilder<List<String>>(
      future: Api.providers(),
      builder: (_, snap) {
        if (!snap.hasData) return const Loading();
        if (snap.data!.isEmpty) return const ProvidersScreen();
        return const HomeScreen();
      },
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator(color: DF.accent)));
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(), _pwd = TextEditingController();
  bool _signup = false, _busy = false, _busyGuest = false;
  String? _err;

  Future<void> _go() async {
    setState(() { _busy = true; _err = null; });
    try {
      final r = _signup
          ? await Api.signUp(_email.text.trim(), _pwd.text)
          : await Api.signIn(_email.text.trim(), _pwd.text);
      if (_signup && r.session == null) {
        setState(() => _err = 'Compte créé — vérifiez vos emails puis connectez-vous.');
      } else if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate()));
      }
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() async {
    setState(() { _busyGuest = true; _err = null; });
    try {
      await Api.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate()));
      }
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busyGuest = false);
    }
  }

  Widget _bullet(String emoji, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: DF.sans(13.5, c: DF.inkBody))),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 24),
              const BrandRow(),
              const SizedBox(height: 24),
              Text(_signup ? 'Créer un compte' : 'Le film du soir,\nensemble.', style: DF.serif(30)),
              const SizedBox(height: 12),
              Text('Swipez, matchez, regardez. Vos recommandations à l\'intersection de vos goûts.',
                  style: DF.sans(15, c: DF.inkBody)),
              const SizedBox(height: 24),
              Field(controller: _email, label: 'Email', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              Field(controller: _pwd, label: 'Mot de passe', obscure: true),
              const SizedBox(height: 8),
              if (_err != null) Text(_err!, style: DF.sans(13, c: DF.accent)),
              const SizedBox(height: 16),
              PrimaryButton(label: _signup ? 'Créer mon compte' : 'Se connecter', busy: _busy, onTap: _go),
              TextButton(
                onPressed: () => setState(() => _signup = !_signup),
                child: Text(_signup ? 'J\'ai déjà un compte' : 'Créer un compte (ou compte Duonom)',
                    style: DF.sans(14, c: DF.secondary, w: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Row(children: [
                const Expanded(child: Divider(color: DF.muted, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou', style: DF.sans(13, c: DF.inkSoft, w: FontWeight.w600)),
                ),
                const Expanded(child: Divider(color: DF.muted, thickness: 1)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: DF.ink,
                      side: const BorderSide(color: DF.muted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: _busyGuest ? null : _guest,
                  child: _busyGuest
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: DF.ink))
                      : Text('Continuer sans compte', style: DF.sans(15, w: FontWeight.w700, c: DF.ink)),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: DF.surface, borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pourquoi créer un compte ?', style: DF.sans(15, w: FontWeight.w800, c: DF.secondary)),
                  const SizedBox(height: 12),
                  _bullet('📌', 'Votre liste et vos goûts sauvegardés à vie'),
                  _bullet('📱', 'Synchronisés entre votre téléphone et le web'),
                  _bullet('❤️', 'Le mode couple / groupe pour matcher à deux'),
                  const SizedBox(height: 4),
                  Text('Sans compte, vos données restent sur cet appareil et peuvent être perdues.',
                      style: DF.sans(12.5, c: DF.inkSoft)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Sélection des plateformes
// ---------------------------------------------------------------------------
const kProviders = [
  ('netflix', 'Netflix'), ('prime', 'Prime Video'), ('disney', 'Disney+'),
  ('canal', 'Canal+'), ('hbo', 'Max'), ('apple', 'Apple TV+'), ('arte', 'Arte'), ('orange', 'Orange'),
];

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final Set<String> _sel = {};
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    await Api.setProviders(_sel.toList());
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 12),
              Text('Vos plateformes', style: DF.serif(30)),
              const SizedBox(height: 8),
              Text('On ne vous proposera que des films que vous pouvez vraiment regarder ce soir.',
                  style: DF.sans(15, c: DF.inkBody)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2, childAspectRatio: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
                  children: kProviders.map((p) {
                    final on = _sel.contains(p.$1);
                    return GestureDetector(
                      onTap: () => setState(() => on ? _sel.remove(p.$1) : _sel.add(p.$1)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: on ? const Color(0xFF39222E) : DF.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: on ? DF.accent : Colors.transparent, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(p.$2, style: DF.sans(15, w: FontWeight.w700)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              PrimaryButton(label: 'Continuer', busy: _busy, onTap: _save),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Accueil : solo / groupe / import
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _openDeck({Map<String, dynamic>? group}) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => MainShell(group: group)));

  Future<void> _createGroup() async {
    final g = await Api.createGroup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Groupe créé — code ${g['invite_code']}')));
    _openDeck(group: g);
  }

  Future<void> _joinGroup() async {
    final code = await _prompt('Code d\'invitation');
    if (code == null || code.isEmpty) return;
    try {
      final g = await Api.joinGroup(code.trim());
      _openDeck(group: g);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code invalide')));
    }
  }

  Future<String?> _prompt(String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DF.surface,
        title: Text(title, style: DF.sans(16, w: FontWeight.w700)),
        content: TextField(controller: c, autofocus: true, style: DF.sans(16)),
        actions: [TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _openUpgrade() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const BrandRow(),
              if (Api.isGuest) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _openUpgrade,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DF.secondary.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DF.secondary.withValues(alpha: .55), width: 1.5),
                    ),
                    child: Row(children: [
                      const Text('✨', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            'Mode invité — créez un compte pour garder votre liste à vie et l\'utiliser à deux',
                            style: DF.sans(13, c: DF.ink, w: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text('→', style: DF.sans(18, c: DF.secondary, w: FontWeight.w800)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text('Ce soir, on regarde…', style: DF.serif(28)),
              const SizedBox(height: 20),
              ModeTile(emoji: '🎬', title: 'Tout seul', subtitle: 'Découvrir des films pour moi', onTap: _openDeck),
              ModeTile(emoji: '👥', title: 'Créer un groupe', subtitle: 'Inviter ma moitié / mes amis', onTap: _createGroup),
              ModeTile(emoji: '🔑', title: 'Rejoindre un groupe', subtitle: 'J\'ai un code d\'invitation', onTap: _joinGroup),
              const Spacer(),
              TextButton(
                onPressed: () async { await Api.signOut(); if (mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Gate()), (_) => false);
                }},
                child: Text('Se déconnecter', style: DF.sans(14, c: DF.inkSoft)),
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Upgrade : transformer un compte invité en compte permanent
// ---------------------------------------------------------------------------
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});
  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final _email = TextEditingController(), _pwd = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _save() async {
    setState(() { _busy = true; _err = null; });
    try {
      await Api.upgradeAccount(_email.text.trim(), _pwd.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Compte créé — vos données sont conservées ✨')));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: DF.bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: DF.ink),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Sauvegarder mon compte', style: DF.serif(30)),
              const SizedBox(height: 12),
              Text(
                  'Votre liste et vos goûts actuels sont conservés — on ajoute juste un email et un mot de passe.',
                  style: DF.sans(15, c: DF.inkBody)),
              const SizedBox(height: 24),
              Field(controller: _email, label: 'Email', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 14),
              Field(controller: _pwd, label: 'Mot de passe', obscure: true),
              const SizedBox(height: 8),
              if (_err != null) Text(_err!, style: DF.sans(13, c: DF.accent)),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Créer mon compte', busy: _busy, onTap: _save),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text('Plus tard', style: DF.sans(14, c: DF.inkSoft, w: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Shell avec onglets : Découvrir (deck) + Pour vous
// ---------------------------------------------------------------------------
class MainShell extends StatefulWidget {
  final Map<String, dynamic>? group;
  const MainShell({super.key, this.group});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      DeckScreen(group: widget.group),
      ForYouScreen(group: widget.group),
      const LikedScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: DF.surface,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Text('🎬', style: TextStyle(fontSize: 20)), label: 'Découvrir'),
          NavigationDestination(icon: Text('⭐', style: TextStyle(fontSize: 20)), label: 'Pour vous'),
          NavigationDestination(icon: Text('🍿', style: TextStyle(fontSize: 20)), label: 'Ma liste'),
          NavigationDestination(icon: Text('⚙️', style: TextStyle(fontSize: 20)), label: 'Réglages'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deck de swipe
// ---------------------------------------------------------------------------
class DeckScreen extends StatefulWidget {
  final Map<String, dynamic>? group;
  const DeckScreen({super.key, this.group});
  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  final List<Movie> _deck = [];
  final Set<String> _seen = {}; // ids déjà en deck ou déjà swipés cette session
  bool _loading = true;
  bool _fetching = false;
  bool _onlyProviders = false;
  Offset _drag = Offset.zero;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    _onlyProviders = await Api.onlyProviders();
    await _load();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final m = await Api.deck(group: widget.group?['id'] as String?, onlyProviders: _onlyProviders);
      // Déduplication : n'ajouter que les films jamais vus/en deck cette session.
      final fresh = m.where((f) => _seen.add(f.id)).toList();
      if (mounted) setState(() { _deck.addAll(fresh); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    } finally {
      _fetching = false;
    }
  }

  Future<void> _swipe(String action) async {
    if (_deck.isEmpty) return;
    final m = _deck.removeAt(0);
    _seen.add(m.id);
    setState(() => _drag = Offset.zero);
    if (_deck.length < 4) _load();
    final matched = await Api.swipe(m.id, action, group: widget.group?['id'] as String?);
    if (matched && mounted) _showMatch(m);
  }

  void _showMatch(Movie m) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: DF.surface,
          title: Text('Match ✨', style: DF.serif(26, c: DF.secondary)),
          content: Text('${m.display} rejoint votre liste commune !', style: DF.sans(15, c: DF.inkBody)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Génial'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const BrandRow(small: true),
          Text(widget.group != null ? 'Groupe · ${widget.group!['invite_code']}' : 'Solo',
              style: DF.sans(12, c: DF.inkSoft, w: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: DF.accent))
            : _deck.isEmpty
                ? Center(child: Text('On cherche des films pour vous…', style: DF.sans(14, c: DF.inkSoft)))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() => _drag += d.delta),
                      onPanEnd: (_) {
                        if (_drag.dx > 110) _swipe('like');
                        else if (_drag.dx < -110) _swipe('nope');
                        else setState(() => _drag = Offset.zero);
                      },
                      child: Transform.translate(
                        offset: _drag,
                        child: Transform.rotate(angle: _drag.dx / 900, child: MovieCard(m: _deck.first)),
                      ),
                    ),
                  ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          RoundBtn(icon: '✕', bg: DF.surface, onTap: () => _swipe('nope')),
          const SizedBox(width: 20),
          RoundBtn(icon: '★', bg: DF.secondary, big: true, onTap: () => _swipe('super')),
          const SizedBox(width: 20),
          RoundBtn(icon: '♥', bg: DF.accent, onTap: () => _swipe('like')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text('✕ Passer      ★ Ma liste      ♥ J\'aime',
            textAlign: TextAlign.center, style: DF.sans(11.5, c: DF.inkSoft, w: FontWeight.w600)),
      ),
    ]);
  }
}

class MovieCard extends StatelessWidget {
  final Movie m;
  const MovieCard({super.key, required this.m});

  (String, Color) get _badge {
    if (m.exploratory) return ('🎲 Autre style à tester', DF.secondary);
    if (m.affinity >= 0.68) return ('❤ Vous allez adorer', DF.teal);
    if (m.affinity >= 0.58) return ('🤔 Peut-être', DF.secondary);
    return ('🎲 Pari audacieux', DF.secondary);
  }

  @override
  Widget build(BuildContext context) {
    final (btxt, bcol) = _badge;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(fit: StackFit.expand, children: [
        if (m.poster != null)
          Image.network(m.poster!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: DF.muted))
        else
          Container(color: DF.muted, child: const Center(child: Text('🎬', style: TextStyle(fontSize: 64)))),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.center,
                colors: [Color(0xE60B0812), Colors.transparent]),
          ),
        ),
        Positioned(
          top: 16, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(color: DF.surface.withValues(alpha: .82), borderRadius: BorderRadius.circular(99)),
            child: Text(btxt, style: DF.sans(12, c: bcol, w: FontWeight.w800)),
          ),
        ),
        Positioned(
          top: 12, right: 12,
          child: GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: DF.surface.withValues(alpha: .82), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('ⓘ', style: DF.sans(20, c: DF.ink, w: FontWeight.w700)),
            ),
          ),
        ),
        Positioned(
          left: 20, right: 20, bottom: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.display, style: DF.serif(26, c: Colors.white)),
            const SizedBox(height: 6),
            Text([
              if (m.year != null) '${m.year}',
              if (m.runtime != null) '${m.runtime} min',
              if (m.rating > 0) '★ ${m.rating}',
              ...m.genres.take(3),
            ].join('  ·  '), style: DF.sans(13, c: const Color(0xFFE7DCFF), w: FontWeight.w600)),
            if (m.overview != null) ...[
              const SizedBox(height: 8),
              Text(m.overview!, maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: DF.sans(13.5, c: const Color(0xFFD9CDF0))),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Pour vous : grille + curseur découverte
// ---------------------------------------------------------------------------
class ForYouScreen extends StatefulWidget {
  final Map<String, dynamic>? group;
  const ForYouScreen({super.key, this.group});
  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  double _discovery = 0.0;
  Future<List<Movie>>? _future;
  int _swipes = 0;
  bool _ready = false;
  bool _onlyProviders = false;

  static const _levels = [('Mes goûts', 0.0), ('Équilibré', 0.25), ('Découvrir +', 0.5)];

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    _onlyProviders = await Api.onlyProviders();
    final n = await Api.swipeCount();
    if (!mounted) return;
    setState(() {
      _swipes = n;
      _ready = n >= 15;
      if (_ready) _future = Api.forYou(discovery: _discovery, onlyProviders: _onlyProviders);
    });
  }

  void _reload() =>
      setState(() => _future = Api.forYou(discovery: _discovery, onlyProviders: _onlyProviders));

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      final pct = (_swipes / 15 * 100).clamp(0, 100).round();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🍿✨', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text('Votre sélection se prépare', style: DF.sans(17, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Swipez encore ${15 - _swipes} film(s) pour débloquer les films faits pour vous.',
                textAlign: TextAlign.center, style: DF.sans(14, c: DF.inkSoft)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: pct / 100, minHeight: 8, backgroundColor: DF.muted, color: DF.secondary),
            ),
          ]),
        ),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RIEN QUE POUR VOUS', style: DF.sans(11, c: DF.secondary, w: FontWeight.w800)),
          const SizedBox(height: 10),
          SegmentedControl(
            labels: _levels.map((e) => e.$1).toList(),
            index: _levels.indexWhere((e) => e.$2 == _discovery),
            onChanged: (i) { _discovery = _levels[i].$2; _reload(); },
          ),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Movie>>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: DF.accent));
            final films = snap.data!;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 2 / 3, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: films.length,
              itemBuilder: (_, i) => PosterTile(m: films[i], rank: i + 1),
            );
          },
        ),
      ),
    ]);
  }
}

class PosterTile extends StatelessWidget {
  final Movie m;
  final int rank;
  const PosterTile({super.key, required this.m, required this.rank});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          if (m.poster != null)
            Image.network(m.poster!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: DF.muted))
          else
            Container(color: DF.muted, child: const Center(child: Text('🎬', style: TextStyle(fontSize: 36)))),
          Positioned(
            top: 8, left: 8,
            child: CircleAvatar(
              radius: 12, backgroundColor: DF.secondary,
              child: Text('$rank', style: DF.sans(12, c: DF.secondaryInk, w: FontWeight.w800)),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 22, 10, 9),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Color(0xF20B0812), Colors.transparent]),
              ),
              child: Text('${m.display}${m.year != null ? ' · ${m.year}' : ''}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: DF.sans(12.5, c: Colors.white, w: FontWeight.w700)),
            ),
          ),
        ]),
      ));
}

// ---------------------------------------------------------------------------
// Fiche film détaillée + bande-annonce
// ---------------------------------------------------------------------------
class DetailScreen extends StatefulWidget {
  final Movie m;
  const DetailScreen({super.key, required this.m});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    final id = widget.m.tmdbId;
    if (id != null) _fetch(id);
  }

  Future<void> _fetch(int id) async {
    final d = await Api.detail(id);
    if (d != null && mounted) setState(() => _detail = d);
  }

  Movie get m => widget.m;

  String? get _tagline {
    final t = _detail?['tagline'];
    return (t is String && t.trim().isNotEmpty) ? t.trim() : null;
  }

  int? get _runtime => (_detail?['runtime'] as num?)?.toInt() ?? m.runtime;

  String? get _overview {
    final o = _detail?['overview'];
    if (o is String && o.trim().isNotEmpty) return o.trim();
    return (m.overview != null && m.overview!.isNotEmpty) ? m.overview : null;
  }

  String? get _backdrop {
    final b = _detail?['backdrop'];
    if (b is String && b.isNotEmpty) return b;
    return (m.backdrop != null && m.backdrop!.isNotEmpty) ? m.backdrop : m.poster;
  }

  List<String> get _genres {
    final g = _detail?['genres'];
    if (g is List && g.isNotEmpty) return g.map((e) => e.toString()).toList();
    return m.genres;
  }

  List<String> get _directors {
    final d = _detail?['directors'];
    if (d is List && d.isNotEmpty) return d.map((e) => e.toString()).toList();
    return m.directors;
  }

  List<(String, String?)> get _cast {
    final c = _detail?['cast'];
    if (c is List && c.isNotEmpty) {
      return c
          .map<(String, String?)>((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final name = (map['name'] ?? '').toString();
            final ch = map['character']?.toString();
            return (name, (ch != null && ch.isNotEmpty) ? ch : null);
          })
          .where((e) => e.$1.isNotEmpty)
          .toList();
    }
    return m.actors.map<(String, String?)>((a) => (a, null)).toList();
  }

  String? get _trailerKey {
    final k = _detail?['trailer_youtube_key'];
    return (k is String && k.isNotEmpty) ? k : null;
  }

  Future<void> _openTrailer() async {
    final key = _trailerKey;
    if (key == null) return;
    final url = Uri.parse('https://www.youtube.com/watch?v=$key');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _votesFmt(int v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k' : '$v';

  String _providerLabel(String code) {
    for (final p in kProviders) {
      if (p.$1 == code) return p.$2;
    }
    return code;
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: DF.sans(12, c: DF.secondary, w: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: DF.surface, borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: DF.sans(12.5, c: DF.inkBody, w: FontWeight.w600)),
      );

  Widget _castChip((String, String?) c) => Container(
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: DF.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.$1, style: DF.sans(12.5, w: FontWeight.w700)),
          if (c.$2 != null)
            Text(c.$2!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DF.sans(11, c: DF.inkSoft)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (m.year != null) '${m.year}',
      if (_runtime != null) '$_runtime min',
      if (m.rating > 0) '★ ${m.rating}${m.votes != null && m.votes! > 0 ? ' (${_votesFmt(m.votes!)})' : ''}',
    ];
    final cast = _cast;
    final directors = _directors;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Stack(children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: _backdrop != null
                  ? Image.network(_backdrop!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: DF.muted))
                  : Container(color: DF.muted, child: const Center(child: Text('🎬', style: TextStyle(fontSize: 72)))),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [DF.bg, Colors.transparent], stops: [0.0, 0.72]),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: DF.surface.withValues(alpha: .82), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back, color: DF.ink, size: 22),
                  ),
                ),
              ),
            ),
          ]),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.display, style: DF.serif(30)),
              if (_tagline != null) ...[
                const SizedBox(height: 8),
                Text(_tagline!,
                    style: DF.sans(14, c: DF.secondary, w: FontWeight.w500).copyWith(fontStyle: FontStyle.italic)),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(meta.join('   ·   '), style: DF.sans(14, c: DF.inkBody, w: FontWeight.w600)),
              ],
              if (_genres.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: _genres.map(_chip).toList()),
              ],
              if (_trailerKey != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: DF.accent,
                        foregroundColor: DF.accentInk,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    onPressed: _openTrailer,
                    child: Text('▶   Bande-annonce', style: DF.sans(15, w: FontWeight.w700, c: DF.accentInk)),
                  ),
                ),
              ],
              if (directors.isNotEmpty)
                _section(directors.length > 1 ? 'Réalisateurs' : 'Réalisation',
                    Text(directors.join(', '), style: DF.sans(14.5, c: DF.ink, w: FontWeight.w600))),
              if (cast.isNotEmpty)
                _section('Casting',
                    Wrap(spacing: 8, runSpacing: 8, children: cast.map(_castChip).toList())),
              if (_overview != null)
                _section('Synopsis',
                    Text(_overview!, style: DF.sans(14.5, c: DF.inkBody).copyWith(height: 1.5))),
              if (m.providers.isNotEmpty)
                _section('Disponible sur',
                    Wrap(spacing: 8, runSpacing: 8, children: m.providers.map((p) => _chip(_providerLabel(p))).toList())),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Ma liste : films aimés + recherche
// ---------------------------------------------------------------------------
class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});
  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  Future<List<Movie>>? _future;
  final _search = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _future = Api.likedMovies();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ma liste', style: DF.serif(28)),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            style: DF.sans(15),
            decoration: InputDecoration(
              hintText: 'Rechercher un film…',
              hintStyle: DF.sans(14, c: DF.inkSoft),
              prefixIcon: const Icon(Icons.search, color: DF.inkSoft, size: 20),
              filled: true,
              fillColor: DF.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DF.muted)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DF.accent, width: 2)),
            ),
          ),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Movie>>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: DF.accent));
            final all = snap.data!;
            if (all.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('Aucun film dans votre liste. Swipez pour en ajouter !',
                      textAlign: TextAlign.center, style: DF.sans(15, c: DF.inkSoft)),
                ),
              );
            }
            final films = _q.isEmpty
                ? all
                : all.where((m) => m.display.toLowerCase().contains(_q)).toList();
            if (films.isEmpty) {
              return Center(
                child: Text('Aucun résultat pour « $_q ».', style: DF.sans(14, c: DF.inkSoft)),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
              itemCount: films.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _LikedRow(m: films[i]),
            );
          },
        ),
      ),
    ]);
  }
}

class _LikedRow extends StatelessWidget {
  final Movie m;
  const _LikedRow({required this.m});
  @override
  Widget build(BuildContext context) {
    final sub = [
      if (m.year != null) '${m.year}',
      ...m.genres.take(2),
    ].join(' · ');
    return Material(
      color: DF.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(m: m))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 54, height: 80,
                child: m.poster != null
                    ? Image.network(m.poster!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: DF.muted))
                    : Container(color: DF.muted, child: const Center(child: Text('🎬', style: TextStyle(fontSize: 24)))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(m.display, maxLines: 2, overflow: TextOverflow.ellipsis, style: DF.sans(15.5, w: FontWeight.w700)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: DF.sans(13, c: DF.inkSoft)),
                ],
              ]),
            ),
            const Icon(Icons.chevron_right, color: DF.inkSoft),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Réglages : compte, plateformes, filtre, groupes
// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Set<String> _sel = {};
  bool _onlyProviders = false;
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  bool _busyProviders = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final providers = await Api.providers();
    final only = await Api.onlyProviders();
    final groups = await Api.myGroups();
    if (!mounted) return;
    setState(() {
      _sel..clear()..addAll(providers);
      _onlyProviders = only;
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _saveProviders() async {
    setState(() => _busyProviders = true);
    await Api.setProviders(_sel.toList());
    if (mounted) setState(() => _busyProviders = false);
  }

  Future<void> _setOnly(bool v) async {
    setState(() => _onlyProviders = v);
    await Api.setOnlyProviders(v);
  }

  Future<void> _signOut() async {
    await Api.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const Gate()), (_) => false);
    }
  }

  Future<void> _openUpgrade() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _createGroup() async {
    final g = await Api.createGroup();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Groupe créé — code ${g['invite_code']}')));
    await _load();
  }

  Future<void> _joinGroup() async {
    final code = await _prompt('Code d\'invitation');
    if (code == null || code.trim().isEmpty) return;
    try {
      await Api.joinGroup(code.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Groupe rejoint !')));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Code invalide')));
      }
    }
  }

  Future<void> _leaveGroup(String id) async {
    await Api.leaveGroup(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Groupe quitté')));
    await _load();
  }

  Future<String?> _prompt(String title) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DF.surface,
        title: Text(title, style: DF.sans(16, w: FontWeight.w700)),
        content: TextField(controller: c, autofocus: true, style: DF.sans(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: DF.sans(14, c: DF.inkSoft))),
          TextButton(onPressed: () => Navigator.pop(context, c.text), child: Text('OK', style: DF.sans(14, c: DF.secondary, w: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: DF.sans(12, c: DF.secondary, w: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: DF.surface, borderRadius: BorderRadius.circular(18)),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: DF.accent));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        Text('Réglages', style: DF.serif(28)),

        // --- COMPTE ---
        _section('Compte', [
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Connecté en tant que', style: DF.sans(12, c: DF.inkSoft, w: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(Api.isGuest ? 'Invité' : (Api.user?.email ?? '—'), style: DF.sans(15.5, w: FontWeight.w700)),
            const SizedBox(height: 14),
            if (Api.isGuest) ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: DF.accent,
                      foregroundColor: DF.accentInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _openUpgrade,
                  child: Text('Créer un compte', style: DF.sans(14.5, w: FontWeight.w700, c: DF.accentInk)),
                ),
              ),
              const SizedBox(height: 10),
              Text('Sans compte, vos données restent sur cet appareil et peuvent être perdues.',
                  style: DF.sans(12.5, c: DF.inkSoft)),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: DF.accent,
                      foregroundColor: DF.accentInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _signOut,
                  child: Text('Se déconnecter', style: DF.sans(14.5, w: FontWeight.w700, c: DF.accentInk)),
                ),
              ),
              const SizedBox(height: 10),
              Text('Vos films et votre liste sont sauvegardés sur votre compte.',
                  style: DF.sans(12.5, c: DF.inkSoft)),
            ],
          ])),
        ]),

        // --- PLATEFORMES ---
        _section('Plateformes', [
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: kProviders.map((p) {
              final on = _sel.contains(p.$1);
              return GestureDetector(
                onTap: () => setState(() => on ? _sel.remove(p.$1) : _sel.add(p.$1)),
                child: Container(
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFF39222E) : DF.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: on ? DF.accent : Colors.transparent, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(p.$2, style: DF.sans(15, w: FontWeight.w700)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
                label: 'Enregistrer mes plateformes', busy: _busyProviders, onTap: _saveProviders),
          ),
          const SizedBox(height: 16),
          _card(Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Uniquement mes plateformes', style: DF.sans(15, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    _onlyProviders
                        ? 'Activé : ne montrer que les films disponibles sur vos plateformes.'
                        : 'Désactivé : tous les films.',
                    style: DF.sans(12.5, c: DF.inkSoft)),
              ]),
            ),
            const SizedBox(width: 10),
            Switch(
              value: _onlyProviders,
              onChanged: _setOnly,
              activeThumbColor: DF.accentInk,
              activeTrackColor: DF.accent,
              inactiveThumbColor: DF.inkSoft,
              inactiveTrackColor: DF.muted,
            ),
          ])),
        ]),

        // --- GROUPE ---
        _section('Groupe', [
          if (_groups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Vous ne faites partie d\'aucun groupe pour l\'instant.',
                  style: DF.sans(13.5, c: DF.inkSoft)),
            ),
          ..._groups.map((g) {
            final id = g['id']?.toString() ?? '';
            final name = (g['name'] as String?)?.trim();
            final code = g['invite_code']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((name != null && name.isNotEmpty) ? name : 'Mon groupe',
                    style: DF.sans(15.5, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Code d\'invitation : $code', style: DF.sans(13, c: DF.inkBody, w: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: DF.secondary,
                          side: const BorderSide(color: DF.secondary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => SharePlus.instance.share(
                          ShareParams(text: 'Rejoins mon groupe Duomovie avec le code : $code')),
                      child: Text('Partager le code', style: DF.sans(13, w: FontWeight.w700, c: DF.secondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: DF.inkSoft,
                          side: const BorderSide(color: DF.muted),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => _leaveGroup(id),
                      child: Text('Quitter', style: DF.sans(13, w: FontWeight.w700, c: DF.inkSoft)),
                    ),
                  ),
                ]),
              ])),
            );
          }),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: DF.accent,
                      foregroundColor: DF.accentInk,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _createGroup,
                  child: Text('Créer un groupe', style: DF.sans(13.5, w: FontWeight.w700, c: DF.accentInk)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: DF.ink,
                      side: const BorderSide(color: DF.muted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _joinGroup,
                  child: Text('Rejoindre un groupe', style: DF.sans(13.5, w: FontWeight.w700, c: DF.ink)),
                ),
              ),
            ),
          ]),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets réutilisables
// ---------------------------------------------------------------------------
class BrandRow extends StatelessWidget {
  final bool small;
  const BrandRow({super.key, this.small = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 26, height: 14,
          child: Stack(children: [
            const Positioned(left: 0, child: CircleAvatar(radius: 7, backgroundColor: DF.accent)),
            Positioned(left: 9, child: CircleAvatar(radius: 7, backgroundColor: DF.secondary)),
          ]),
        ),
        const SizedBox(width: 9),
        Text('Duomovie', style: DF.serif(small ? 18 : 20)),
      ]);
}

class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboard;
  const Field({super.key, required this.controller, required this.label, this.obscure = false, this.keyboard});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: DF.sans(12, c: DF.inkSoft, w: FontWeight.w700)),
        const SizedBox(height: 7),
        TextField(
          controller: controller, obscureText: obscure, keyboardType: keyboard, style: DF.sans(16),
          decoration: InputDecoration(
            filled: true, fillColor: DF.surface,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DF.muted)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DF.accent, width: 2)),
          ),
        ),
      ]);
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool busy;
  const PrimaryButton({super.key, required this.label, required this.onTap, this.busy = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: DF.accent, foregroundColor: DF.accentInk,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          onPressed: busy ? null : onTap,
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label, style: DF.sans(15, w: FontWeight.w700, c: DF.accentInk)),
        ),
      );
}

class ModeTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final VoidCallback onTap;
  const ModeTile({super.key, required this.emoji, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: DF.surface, borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: DF.sans(16, w: FontWeight.w700)),
                  Text(subtitle, style: DF.sans(13, c: DF.inkSoft)),
                ]),
              ]),
            ),
          ),
        ),
      );
}

class RoundBtn extends StatelessWidget {
  final String icon;
  final Color bg;
  final bool big;
  final VoidCallback onTap;
  const RoundBtn({super.key, required this.icon, required this.bg, required this.onTap, this.big = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: big ? 62 : 54, height: big ? 62 : 54,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: bg.withValues(alpha: .5), blurRadius: 20, offset: const Offset(0, 8)),
          ]),
          child: Center(child: Text(icon, style: TextStyle(fontSize: big ? 26 : 22, color: Colors.white))),
        ),
      );
}

class SegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegmentedControl({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: DF.muted, borderRadius: BorderRadius.circular(99)),
        child: Row(
          children: List.generate(labels.length, (i) {
            final on = i == index;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: on ? DF.accent : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                  child: Center(
                      child: Text(labels[i],
                          style: DF.sans(12.5, w: FontWeight.w700, c: on ? DF.accentInk : DF.inkSoft))),
                ),
              ),
            );
          }),
        ),
      );
}
