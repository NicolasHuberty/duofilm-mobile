import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _signup = false, _busy = false;
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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const BrandRow(),
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
    final pages = [DeckScreen(group: widget.group), ForYouScreen(group: widget.group)];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: DF.surface,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Text('🎬', style: TextStyle(fontSize: 20)), label: 'Découvrir'),
          NavigationDestination(icon: Text('⭐', style: TextStyle(fontSize: 20)), label: 'Pour vous'),
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
  bool _loading = true;
  Offset _drag = Offset.zero;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final m = await Api.deck(group: widget.group?['id'] as String?);
      setState(() { _deck.addAll(m); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _swipe(String action) async {
    if (_deck.isEmpty) return;
    final m = _deck.removeAt(0);
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          RoundBtn(icon: '✕', bg: DF.surface, onTap: () => _swipe('nope')),
          const SizedBox(width: 20),
          RoundBtn(icon: '★', bg: DF.secondary, big: true, onTap: () => _swipe('super')),
          const SizedBox(width: 20),
          RoundBtn(icon: '♥', bg: DF.accent, onTap: () => _swipe('like')),
        ]),
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

  static const _levels = [('Mes goûts', 0.0), ('Équilibré', 0.25), ('Découvrir +', 0.5)];

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    final n = await Api.swipeCount();
    setState(() { _swipes = n; _ready = n >= 15; if (_ready) _future = Api.forYou(discovery: _discovery); });
  }

  void _reload() => setState(() => _future = Api.forYou(discovery: _discovery));

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
  Widget build(BuildContext context) => ClipRRect(
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
      );
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
