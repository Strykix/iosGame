# STARSHIP: DON'T POP

> Tiens jusqu’à l’orbite.

Jeu iOS one-touch : tu es le booster. Doigt posé = plein gaz, doigt levé = chute.
Trop chaud = RUD. Trop bas = belly flop. Passe la ligne de Kármán (100 km) pour l’orbite.
Un run dure 20 à 40 s et la relance est instantanée.

- SwiftUI + SpriteKit, iOS 17+, iPhone, portrait, 60 fps
- Aucune dépendance payante (seul le SDK AdMob gratuit), aucun asset externe : tout est dessiné en code
- MVVM, zéro force unwrap, sauvegarde JSON locale
- UI en français et en anglais
- StoreKit 2 (2 packs cosmétiques), pubs récompensées AdMob (consentement RGPD + ATT) derrière le protocole `AdService`
- Son 100 % procédural (AVAudioEngine) et haptics

---

## 1. Ouvrir dans Xcode

Le projet `.xcodeproj` est généré par [XcodeGen](https://github.com/yonaskolb/XcodeGen) à partir de `project.yml`.
Il est versionné, donc tu peux l’ouvrir directement :

```bash
open StarshipDontPop.xcodeproj
```

Si tu modifies `project.yml` ou si tu ajoutes des fichiers :

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

Ensuite :

1. Sélectionne la cible **StarshipDontPop** > *Signing & Capabilities*, choisis ta **Team**.
   Le bundle ID est `com.indie.starshipdontpop`.
2. Ajoute la capability **In-App Purchase**.
3. Choisis un simulateur iPhone, puis ⌘R.

Tests unitaires de la simulation (physique, winnability, staging, codes défi) : ⌘U, ou :

```bash
xcodebuild test -scheme StarshipDontPop -destination 'platform=iOS Simulator,name=iPhone 17'
```

## 2. Tester les achats in-app

### En local (sans compte, recommandé pour dev)

Le schéma `StarshipDontPop` pointe déjà sur `StoreKit/Products.storekit` (vitrine FRA, prix en €) :

| Product ID | Type | Prix |
|---|---|---|
| `com.starship.pack.chrome` | Non-consumable | 2,99 € |
| `com.starship.pack.fleet` | Non-consumable | 6,99 € |

Lance l’app, va dans **Hangar > Boutique** et achète : aucun paiement réel.
Dans Xcode : **Debug > StoreKit > Manage Transactions** pour rembourser ou supprimer une transaction.
Le skin Chrome se re-verrouille alors automatiquement.

### Sandbox (App Store Connect)

1. Dans App Store Connect, crée l’app avec le bundle ID `com.indie.starshipdontpop`.
2. Dans *Monetization > In-App Purchases*, crée les deux **Non-Consumable** avec les product IDs ci-dessus,
   en prix Tier 2,99 € et 6,99 €, avec une capture d’écran de review (le Hangar).
3. Dans *Users and Access > Sandbox*, crée un testeur sandbox.
4. Dans Xcode, *Edit Scheme > Run > Options > StoreKit Configuration* : mets **None** pour taper le vrai sandbox.
5. Sur un iPhone réel, va dans *Réglages > App Store > Compte sandbox* et connecte le testeur.
6. Teste l’achat, puis « Restaurer les achats » après réinstallation.

## 3. Pubs récompensées (AdMob)

Google AdMob est intégré via Swift Package Manager (`GoogleMobileAds` et `GoogleUserMessagingPlatform`, déclarés dans `project.yml`).
Tout passe par le protocole `AdService` : le jeu ne parle jamais directement au SDK.

| Fichier | Rôle |
|---|---|
| `Services/AdService.swift` | Protocole + `AdServiceFactory` + `NoAdService` + `MockAdService` |
| `Services/AdMobService.swift` | Rewarded AdMob (préchargement, retry exponentiel) + `ConsentFlow` (RGPD puis ATT) |

**Au lancement :** formulaire RGPD Google (UMP, obligatoire dans l'EEE), puis popup ATT d'Apple, puis démarrage du SDK et préchargement d'une rewarded.
Si l'utilisateur refuse, des pubs non personnalisées sont quand même servies (sauf s'il refuse le stockage sur l'appareil).
Le bouton **Hangar > Réglages > Confidentialité des pubs** apparaît quand le RGPD l'exige ; il permet de modifier son choix.

**Règles du jeu :** 100 % opt-in, jamais d'interstitielle, une seule seconde chance par run (continuer **ou** reprendre depuis le staging).
Les boutons n'apparaissent que si une pub est chargée.

### Mettre tes vrais IDs

1. Sur [admob.google.com](https://admob.google.com), crée l'app iOS puis un bloc d'annonces **Avec récompense**.
2. Dans *Confidentialité et messages*, crée et **publie** un message RGPD (et optionnellement le message IDFA).
3. Dans `project.yml`, section `configs > Release`, remplace les deux IDs de test :

```yaml
Release:
  ADMOB_APP_ID: ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
  ADMOB_REWARDED_UNIT_ID: ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
```

```bash
xcodegen generate
```

Le Debug garde les IDs de test Google : clique autant que tu veux, aucun risque pour ton compte.
**Ne clique jamais sur tes vraies pubs** (suspension du compte AdMob).

4. Publie un fichier `app-ads.txt` à la racine du site web déclaré comme « site du développeur » sur l'App Store.
5. Pour la médiation ou les acheteurs tiers, complète `SKAdNetworkItems` dans `project.yml` avec la liste officielle de Google.

### Tester

- **Simulateur/Debug :** le formulaire RGPD est forcé en mode « EEE » (`DebugSettings`), et une pub vidéo de test « Test mode » s'affiche.
- **Revoir le formulaire RGPD :** supprime l'app du simulateur et réinstalle-la.
- **Hors ligne / sans SDK :** *Edit Scheme > Run > Arguments > Environment Variables*, ajoute `MOCK_ADS` = `1` (alerte factice).
- Les logs `AdMob:` dans la console Xcode indiquent : statut du consentement, SDK démarré, pub prête, erreurs de chargement.

### App Store Connect

- *App Privacy* : déclare les données collectées par le SDK (identifiant publicitaire, données d'usage, diagnostics…)
  en suivant le guide Google *« Prepare for Apple's App Store data disclosure requirements »* (doc AdMob iOS).
  Le SDK embarque son propre `PrivacyInfo.xcprivacy`.
- *Informations de l'app* : coche « contient des publicités ».

## 4. Captures App Store

Tailles requises : 6,9" (1320 × 2868) obligatoire. La 6,5" (1284 × 2778) est facultative.

```bash
xcrun simctl boot "iPhone 17 Pro Max"
```

```bash
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4
```

Lance l’app sur ce simulateur, puis capture chaque écran :

```bash
xcrun simctl io booted screenshot capture-01-launch.png
```

Les 5 captures conseillées :

1. **Écran titre** : « TAPE POUR DÉCOLLER » avec la fusée sur le pas de tir
2. **En vol** : phase HOT STAGING avec le texte « CLEAN STAGING ! »
3. **Obstacles** : bande de vent + débris
4. **Game over** : « Encore un RUD » avec le bouton PARTAGER
5. **Hangar** : les 5 skins et la boutique

Astuce : pour une capture en vol propre, maintiens le doigt (clic maintenu) puis prends la capture avec ⌘S dans Simulator.

## 5. Viralité

- **Game over** : phrase meme, replay en slow-motion des 3 dernières secondes, bouton PARTAGER
  (image 9:16 + texte prérempli), bouton 𝕏 (intent prérempli) et bouton Stories.
- **Défi** : chaque partage contient un code (`K3F9Q-12450`) et un lien
  `starshipdontpop://challenge?seed=…&score=…`. Le même seed donne la même trajectoire,
  et ton ami doit battre ton score.
- À configurer dans `Services/ShareService.swift` (`ShareConfig`) :
  - `webChallengeBase` : un domaine en universal link (sinon les liens ne sont pas cliquables dans X ou Instagram).
    Il faut alors ajouter l’entitlement *Associated Domains* et héberger `apple-app-site-association`.
  - `facebookAppID` : requis par Instagram pour le partage direct en Story. Sans lui, on bascule sur la feuille de partage système.

## 6. Game design

| | |
|---|---|
| Contrôle | Maintenir = poussée ; relâcher = chute (gravité + traînée) |
| Jauges | Chaleur (monte en poussée, surtout à haute vitesse) ; carburant (booster, puis ship après staging) |
| Phases | **BOOST** 0–36 km → **HOT STAGING** 36–44 km (relâche puis re-tape en moins de 0,55 s = *clean staging*) → **ORBIT BURN** → 100 km |
| Paliers | Troposphère (0–12), Stratosphère (12–50), Mésosphère (50–100), avec des turbulences à chaque palier |
| Obstacles | Cisaillement de vent (couche la fusée si tu relâches), débris, caméra Elon (drone), turbulences |
| Fails | RUD (surchauffe/débris), Belly flop (chute), Mode tortue (inclinaison), Livestream terminé (caméra), Panne sèche |
| Score | altitude × 100 + style (clean staging +1000, frôlé +150, « ça chauffe » +50/s, orbite +5000) |
| Skins | Prototype (offert), Flight 11 (atteindre le staging), Banane (10 échecs), Booster recovered (orbite), Chrome (IAP) |

Tous les réglages sont dans `Game/GameConfig.swift`. La simulation (`Game/GameSimulation.swift`) est pure et
déterministe : les tests unitaires font jouer un bot pour vérifier qu’une trajectoire reste gagnable en 20–40 s.

## 7. Architecture

```
StarshipDontPop/
  App/          point d’entrée
  Game/         GameSimulation (logique pure), GameScene (rendu SpriteKit), Artwork (dessin procédural), GameConfig
  Models/       SaveData, RunResult, Skin, FailReason / GameEvent
  Services/     ProfileStore (JSON), StoreService (StoreKit 2), AdService, SoundEngine, HapticsService, ShareService
  ViewModels/   GameViewModel, HangarViewModel
  Views/        Launch, HUD, GameOver, Hangar, ShareCard
  Resources/    Localizable FR/EN, Assets
StoreKit/       Products.storekit (tests IAP locaux)
scripts/        generate_icon.swift (icône 1024 générée en code)
```

## 8. ⚠️ Avant de soumettre à l’App Store

- **Marque « Starship »** : c’est une marque déposée de SpaceX. Un titre qui la contient risque un rejet
  (guidelines 4.1 / 5.2.1) ou une plainte. Le jeu utilise déjà des noms parodiques (StarBarge, X-Boost),
  mais je conseille un nom de store du type **« DON'T POP: Rocket Staging »**, avec le sous-titre
  *« Tiens jusqu’à l’orbite »*.
- **Personne réelle** : « caméra Elon » et « Elon a tweeté » citent une personne réelle (guideline 5.2.1).
  Ces textes sont isolés dans `Localizable.strings` (`obstacle.camera`, `meme.generic.tweet`) :
  remplace-les par exemple par « CAMÉRA DU PATRON » / « Le patron a tweeté » si la review bloque.
- **Âge** : pas de violence réaliste (explosions cartoon), pas d’achats aléatoires, donc 4+.
- **AdMob** : remplace les IDs de test par les tiens en Release (section 3), sinon tu ne gagnes rien.
- **Confidentialité** : remplis le *Privacy Nutrition Label* pour AdMob (section 3).
