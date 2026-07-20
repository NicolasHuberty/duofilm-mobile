# Duonom mobile — iOS + Android (Flutter)

**Une seule base de code** Flutter pour les deux apps, sur le **même backend Supabase** que le web. Port fidèle de l'app web (`app/`) : design « Argile Organique », recommandeur « TikTok », swipe, couple + match temps réel, fiche prénom.

## Structure
```
mobile/
  pubspec.yaml            deps (supabase_flutter, google_fonts)
  assets/names.json       catalogue embarqué (client épais)
  lib/
    main.dart             app : onboarding · swipe · couple · liste · fiche
    theme.dart            tokens « Argile Organique » (miroir design/tokens.css)
    models.dart           NameRec + chargement du catalogue
    recommender.dart      algo « TikTok » (port de app/app.js)
    duonom_api.dart       client Supabase partagé (auth, swipes, couple, matchsStream)
```

## Lancer (iOS + Android)
Le dossier contient déjà `lib/`, `pubspec.yaml` et `assets/`. Il manque seulement les dossiers de plateforme, générés par Flutter :
```bash
cd mobile
flutter create . --project-name duonom --org com.duonom   # génère android/ + ios/ (garde lib/ et pubspec)
flutter pub get
flutter run                                                # les clés Supabase publiques sont par défaut dans main.dart
```
Pour surcharger la config :
```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Backend
Même projet Supabase que le web (déjà provisionné). Le catalogue en base doit contenir les colonnes riches (`z`, `spark`, `meaning`) pour que le mobile fonctionne pleinement s'il **fetch** depuis la DB — mais ici le catalogue est **embarqué** (`assets/names.json`), donc l'app tourne sans dépendre de la DB pour les prénoms ; Supabase ne sert que swipes/couple/match.

## Reste à faire / à vérifier
- ⚠️ **Non compilé ici** (pas de SDK Flutter dans l'environnement de dev) : lance `flutter analyze` puis `flutter run`, quelques ajustements mineurs possibles.
- Écrans à compléter (mirroir web) : paywall Premium, écran de décision « LE prénom », deep link `duonom://couple?code=` (auto-join comme sur le web).
- Offline-first (V1.1) : outbox locale (Hive/Isar) dans `recordSwipe`.
- Icône/splash : `flutter_launcher_icons` avec `app/icon.svg`.
