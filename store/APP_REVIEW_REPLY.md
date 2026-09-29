# Réponse à App Review – Guideline 2.1 (Information Needed)

Demande standard pour un nouveau compte développeur. À faire :
1. Enregistrer la vidéo sur l'iPhone (scénario ci-dessous).
2. Répondre dans App Store Connect avec la vidéo + le texte « Réponse » (en anglais).
3. Coller aussi ce texte dans **App Review Information › Notes** de la version 1.0 (demandé par Apple).

## Scénario de la vidéo (2 à 3 minutes, iPhone réel, iOS à jour)

Avant : supprimer l'app de l'iPhone, puis la réinstaller depuis TestFlight (pour montrer le premier lancement).
Dans AdMob › Paramètres › Appareils de test, ajouter l'iPhone pour afficher des pubs de test.

1. Écran d'accueil de l'iPhone → toucher l'icône **Don't Pop** (la vidéo doit commencer au lancement).
2. Formulaire de consentement Google (RGPD) → choisir une option. Puis popup de suivi Apple (ATT) → choisir.
3. Écran titre → toucher. Maintenir le doigt pour décoller, relâcher et reprendre pour gérer la chaleur.
4. Monter jusqu'à la zone HOT STAGING : relâcher puis re-toucher (« CLEAN STAGING ! »).
5. Laisser la fusée échouer (surchauffe ou chute) → écran de fin avec replay et phrase.
6. Toucher **Continuer (pub)** → regarder la pub récompensée jusqu'au bout → la fusée repart.
7. Échouer à nouveau → toucher **PARTAGER** pour montrer la feuille de partage, puis fermer.
8. Toucher l'icône palette → **Hangar** : skins, puis **Boutique** › acheter le **Pack Chrome**
   (TestFlight = sandbox, rien n'est débité) → le skin Chrome se débloque → l'équiper.
9. Toucher **Restaurer les achats**. Descendre jusqu'à **Confidentialité des pubs** et **Politique de confidentialité**.
10. Fermer le Hangar, relancer un vol avec le skin Chrome, puis arrêter l'enregistrement.

Enregistrement : Centre de contrôle › Enregistrement de l'écran (l'ajouter dans Réglages › Centre de contrôle si absent).

## Réponse (à coller en anglais)

```
Hello App Review team,

Thank you for reviewing StarBarge: Don't Pop. Please find the requested information below.

1. SCREEN RECORDING
Attached: a screen recording captured on a physical iPhone running the latest iOS. It starts at app launch and shows the consent prompts, a full flight, a failed flight with the optional rewarded ad, sharing, and the purchase and restore of a cosmetic pack in the Hangar.

2. PURPOSE AND TARGET AUDIENCE
StarBarge: Don't Pop is a casual one-touch arcade game for a general audience (teens and adults). The player controls a rocket booster: holding a finger on the screen throttles up, releasing it makes the rocket fall. The goal is to reach orbit (100 km) by managing heat and fuel, performing a timed stage separation, and avoiding obstacles. A run lasts 20 to 40 seconds. The value is a quick, skill-based game session with instant restarts and friendly score challenges: each flight produces a challenge code that friends can use to fly the exact same trajectory.

3. SETUP AND ACCESS INSTRUCTIONS
No account, login or sample files are needed.
- Launch the app. On first launch, Google's consent form (GDPR) and the App Tracking Transparency prompt may appear; any choice works.
- Tap the title screen, then hold anywhere to throttle up and release to fall. The left gauge is heat, the right gauge is fuel.
- In the green HOT STAGING zone (36 to 44 km), release then tap again quickly for a "clean staging" bonus.
- After a failed flight, the game-over screen offers Relaunch, Share, and an optional "Continue (ad)" rewarded ad.
- The Hangar (palette button on the title screen) contains the skins, the shop with two cosmetic non-consumable In-App Purchases (Chrome Pack, Fleet Pack), "Restore purchases", the ad privacy settings and the privacy policy link.
The In-App Purchases only unlock visual rocket skins and give no gameplay advantage.

4. EXTERNAL SERVICES
- Apple StoreKit: In-App Purchases (payment processing is handled entirely by Apple).
- Google Mobile Ads SDK (AdMob): optional rewarded video ads, shown only when the player chooses "Continue (ad)".
- Google User Messaging Platform: GDPR consent form for ads.
- GitHub Pages: hosts the static privacy policy and support pages.
The app has no backend server, no user accounts, no analytics service and no AI service. Game progress is saved locally on the device. Sharing uses the standard iOS share sheet.

5. REGIONAL DIFFERENCES
The app functions consistently across all regions. The only differences are: the GDPR consent form is shown only where required (EEA, UK and regulated regions, as determined by Google's consent SDK), prices follow each App Store storefront, and the interface is localized in English and French.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
The app does not operate in a regulated industry and does not include protected third-party material. All graphics are drawn by the app's own code and all sounds are generated procedurally; there is no licensed content. StarBarge is an original parody name and is not affiliated with any real company, product or person.

Best regards,
Loïc Berger
```
