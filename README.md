<div align="center">

# 🏹 ARCH3RO 3DS

### *Un Roguelite d'Action Intense taillé sur mesure pour la Nintendo 3DS & PC*

[![Platform](https://img.shields.io/badge/Platform-Nintendo%203DS%20%7C%202DS%20%7C%20PC-E60012?style=for-the-badge&logo=nintendo-3ds&logoColor=white)](https://github.com/tonydetony1/arch3ro3ds)
[![Engine](https://img.shields.io/badge/Engine-L%C3%96VE--Potion%203.x-D83A56?style=for-the-badge&logo=lua&logoColor=white)](https://lovebrew.org/)
[![Framerate](https://img.shields.io/badge/Target-60%20FPS%20Constant-2ea44f?style=for-the-badge)](https://github.com/tonydetony1/arch3ro3ds)
[![3D Stereoscopy](https://img.shields.io/badge/3D%20Relief-Autost%C3%A9r%C3%A9oscopique%20Native-0969da?style=for-the-badge)](https://github.com/tonydetony1/arch3ro3ds)
[![Format](https://img.shields.io/badge/Releases-.CIA%20%7C%20.3DSX-ff9900?style=for-the-badge)](https://github.com/tonydetony1/arch3ro3ds/releases)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

<br/>

<img src="assets/banner.png" alt="Arch3ro 3DS Banner" width="800"/>

<p align="center">
  <b>Arch3ro 3DS</b> est un jeu d'action-roguelite nerveux inspiré d'<i>Archero</i>, entièrement recréé et optimisé pour le matériel <b>Nintendo 3DS</b> (Old 3DS, 2DS, New 3DS, New 2DS XL) ainsi que pour <b>PC Desktop</b> (Linux, Windows, macOS via LÖVE 11.x).
</p>

[Fonctionnalités](#-fonctionnalités-majeures) •
[Rôdeurs & Armes](#-héros--arsenal) •
[Optimisations 3DS](#-prouesses-techniques--optimisations-3ds) •
[Contrôles](#-contrôles--jouabilité) •
[Installation](#-guide-dinstallation) •
[Compilation](#-compilation--outils-développeurs)

</div>

---

## 🌟 Aperçu du Jeu

Plongez au cœur d'expéditions périlleuses où le positionnement et le timing font la différence entre la victoire et la mort :
- **Mécanique "Hit & Run" culte** : Déplacez-vous librement pour esquiver les tirs ennemis, puis arrêtez-vous pour décocher automatiquement vos flèches et sorts dévastateurs.
- **Exploitation Totale du Double Écran 3DS** :
  - **Écran Supérieur (400×240 à 60 FPS)** : Arène d'action intégrale, dioramas avec éclairages dynamiques, ombres projetées, retour de dégâts flottant (FCT) et **3D autostéréoscopique native** liée au curseur physique de la console.
  - **Écran Inférieur Tactile (320×240)** : Interface "Gummy UI" fluide, gestion d'inventaire avec glisser-déposer, forge d'équipements, arbre de talents, bestiaire interactif et joystick virtuel au stylet.

<div align="center">
  <img src="crop_top_with_content.png" alt="Écran Haut de Combat" width="45%" />
  &nbsp;&nbsp;
  <img src="crop_bot_with_content.png" alt="Écran Bas Tactile" width="37%" />
  <br/>
  <i>Écran Supérieur (Combat & Boss) &nbsp;&nbsp;•&nbsp;&nbsp; Écran Inférieur (HUD, Capacités & Menus Tactiles)</i>
</div>

---

## ⚔️ Fonctionnalités Majeures

### 🏰 Progression Roguelite & Chapitres Procéduraux
- **6 Mondes thématiques (50 étages chacun)** aux biomes variés :
  1. 🌲 **Forêt Verdoyante** (*Boss : Golem de Granit*)
  2. 🏜️ **Désert Aride** (*Boss : Roi Squelette*)
  3. 💎 **Cavernes de Cristal** (*Boss : Sorcière de Cristal*)
  4. 🌋 **Enfer Volcanique** (*Boss : Titan de Lave*)
  5. ☁️ **Îles Célestes** (*Boss : Drake des Tempêtes*)
  6. 🌌 **Cité du Vide** (*Boss : Œil du Vide*)
- **Multiples Modes de Jeu** :
  - **Ascension** : L'épopée classique chapitre par chapitre.
  - **Le Gouffre (Infini)** : Une descente sans fin avec vagues infinies et boss successifs.
  - **Boss Rush** : Affrontez les boss majeurs à la chaîne.
  - **Arène de Survie** : Résistez face à des marées ininterrompues de monstres.

### 🎲 Salles Événements & Choix Cruciaux
- 👼 **Sanctuaire de l'Ange** (salles 5, 15, 25...) : Choisissez entre un soin salvateur et des bénédictions temporaires ou permanentes.
- 🎡 **Roue de la Fortune (Lucky Wheel)** : Faites tourner la roue pour remporter de l'or, des gemmes, des cœurs ou des compétences inédites.
- 😈 **Pacte du Démon** : Vaincre un Boss sans subir le moindre coup invoque le Démon. Sacrifiez vos PV Max permanents en échange de pouvoirs interdits (*Marcher sur l'eau, Traverser les murs, Flèches décuplées, Résurrection*).
- 🧙‍♂️ **Marchand Mystérieux** : Achetez des parchemins d'amélioration, des équipements rares ou des potions.

### 🔮 80+ Compétences en Combat (Skills)
À chaque montée de niveau, choisissez parmi 3 compétences aléatoires :
- **Tirs Multiples** : Flèche Frontale +1, Flèches Diagonales, Flèches Latérales, Flèche Arrière.
- **Balistique & Trajectoire** : Ricochet, Tirs Transperçants, Rebond sur les Murs (Bouncy Wall), Tirs Téléguidés.
- **Affinités Élémentaires** : Poison persistant, Brûlure incendiaire, Foudre en chaîne, Congélation boréale.
- **Orbes & Épées Orbitaux** : Épées tournantes protectrices et orbes élémentaires autour du héros.
- **Frappes Célestes** : Météores volcaniques et étoiles filantes pleuvant sur les ennemis.
- **Familiers & Invocations** : Invocation de chauves-souris spectrales, d'esprits frappeurs et de clones d'ombre.

---

## 🏹 Héros & Arsenal

### 🛡️ Le Roster des Rôdeurs
Chaque héros possède une signature visuelle, des statistiques de départ et un pouvoir ultime activable :

| Héros | Titre | Passif Unique | Compétence Ultime |
| :--- | :--- | :--- | :--- |
| **Atreus** | *Archer Rôdeur* | **Courage** : +10% Vitesse d'attaque, +5% Esquive permanente | **Barrage Céleste** (Pluie de flèches ciblées) |
| **Urasil** | *Maître des Poisons* | **Venin Mortel** : Flèches empoisonnées (35 dégâts/s) | **Miasme Mortel** (Nuage d'acide couvrant l'arène) |
| **Phoren** | *Seigneur des Flammes* | **Fureur Pyrotechnique** : Flèches enflammées (brûlure rapide) | **Météore Volcanique** (Impact météoritique dévastateur) |
| **Helix** | *Guerrier Berserker* | **Rage Primale** : Dégâts accrus jusqu'à +120% selon les PV perdus | **Fureur Berserker** (Invulnérabilité 3s + Vitesse ×2) |
| **Rolla** | *Reine Polaire* | **Gel Boréal** : Toutes les flèches gèlent les monstres 1.5s | **Zéro Absolu** (Gèle instantanément toute la salle 3s) |

### 🗡️ Les 8 Archétypes d'Armes
1. **Arc de Brave (Starter Bow)** : L'équilibre parfait, cadence constante et stabilité idéale pour tous les styles.
2. **Dagues de Vent (Rapid Daggers)** : Cadence supersonique pour cribler les ennemis et pratiquer le *kiting* continu.
3. **Carreau Lourd (Heavy Ballista)** : Projectiles lents mais dévastateurs avec recul massif.
4. **Lame Circulaire (Saw Blade)** : Disques métalliques rapides avec bonus d'agilité à l'entrée de salle.
5. **Faux de la Mort (Death Scythe)** : Très lourds dégâts et **exécution instantanée** des monstres sous 30% de PV !
6. **Bâton de Rôdeur (Stalker Staff)** : Orbes arcaniques à poursuite angulaire téléguidée vers les monstres.
7. **Tornade Boomerang** : Traverse l'ensemble des monstres à l'aller et inflige des dégâts supplémentaires au retour.
8. **Lance Brillante (Brightspear)** : Tir instantané quasi-*hitscan* (laser) impossible à esquiver pour l'ennemi.

---

## 🔨 Système de Forge & Rareté

Équipez votre héros sur **6 emplacements stratégiques** : Arme, Armure, 2 Anneaux et 2 Familiers (Chauve-souris laser, Spectre givrant, Dragonnet explosif).

```
   [COMMUN] ───(Fusion 3x)───> [ATYPIQUE] ───(Fusion 3x)───> [RARE]
                                                               │
   [LÉGENDAIRE] <───(Fusion 3x)─── [ÉPIQUE] <──────────────────┘
```

- **5 Niveaux de Rareté** : *Commun* ➔ *Atypique* (+25% stats) ➔ *Rare* (Passif 1) ➔ *Épique* (Passif de gameplay majeur) ➔ *Légendaire* (Pouvoir Ultime).
- **La Forge 3-en-1** : Fusionnez 3 exemplaires identiques d'un équipement pour obtenir le rang supérieur et déverrouiller ses passifs cachés !
- **Paliers de Maîtrise du Bestiaire** : Éliminez 50, 200, puis 500 exemplaires d'un même monstre pour obtenir des bonus de dégâts permanents contre cette espèce.

---

## 🚀 Prouesses Techniques & Optimisations 3DS

Le jeu a été conçu avec une attention chirurgicale accordée aux contraintes matérielles de la Nintendo 3DS (processeur ARM11 et GPU PICA200) :

```
┌────────────────────────────────────────────────────────────────────────┐
│                      PIPELINE GRAPHIQUE ARCH3RO                        │
├────────────────────────────────────────────────────────────────────────┤
│  Atlas Binaire Natif (atlas.t3x) ──> Boot Instantané (< 0.10s)         │
│  Garde-fou GPU PICA200           ──> Budget Max 24,576 sommets/frame   │
│  Zéro-Allocation GC (Pools)      ──> 200 Proj, 30 Mobs, 100 FX         │
│  Rafraîchissement Tactile Éco    ──> 1 frame sur 3 = 60 FPS constant   │
│  Stéréoscopie 8 Couches          ──> Relief physique natif via Slider  │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Garde-fou Matériel PICA200 (`src/core/gpu.lua`)** :
   - Le GPU PICA200 de la 3DS possède un tampon mémoire de sommets de $6 \times 0x1000 = 24\,576$ sommets par image (les deux écrans cumulés, l'écran du haut comptant double en 3D stéréoscopique).
   - Un débordement de ce tampon provoque un crash avec écran noir ou corruption de la mémoire vidéo. Arch3ro implémente un système d'estimation dynamique qui rejette gracieusement les détails superflus pour préserver la stabilité absolue du jeu.
2. **Texture Binaire Native PICA200 (`assets/atlas.t3x`)** :
   - Utilisation de l'outil `png2t3x.py` pour convertir l'atlas graphique directement au format GPU 3DS.
   - Temps de chargement au démarrage réduit à **moins de 100 millisecondes**, sans aucune pause de décompression PNG au lancement.
3. **Zéro Allocation Garbage Collector (Zero-GC Loop)** :
   - Tous les projectiles (200), ennemis (30), particules (100), textes de combat FCT (40) et butins (120) proviennent de pools d'objets pré-alloués en mémoire.
   - Aucune création de table Lua pendant les phases de combat : **zéro micro-saccade** causée par le ramasse-miettes.
4. **Rafraîchissement Intelligent de l'Écran Inférieur (`src/core/runloop.lua`)** :
   - L'écran tactile n'est redessiné qu'une image sur 3 (`RunLoop.BOTTOM_EVERY = 3`) ou dès qu'une interaction stylet/bouton est détectée.
   - Cela libère le CPU et le GPU pour garantir un **60 FPS inébranlable** sur l'écran supérieur où se déroule l'action.
5. **Véritable Relief Stéréoscopique 3D (`src/render/depth.lua`)** :
   - Décalage horizontal par couche selon l'œil (gauche / droite) connecté au curseur physique 3D de la console :
     - `SKY` (-10 px) : Creusé profondément derrière l'écran
     - `GROUND` (0 px) : Plan neutre de l'écran
     - `ACTORS` (+2 px) : Héros et monstres détachés du sol
     - `FX & HUD` (+4 px) : Dégâts et effets jaillissant hors de la console !

---

## 🎮 Contrôles & Jouabilité

| Action | Console Nintendo 3DS | PC Desktop (Clavier / Souris) |
| :--- | :--- | :--- |
| **Déplacement du Héros** | **Circle Pad** (analogique) ou **D-Pad** | **Flèches directionnelles** ou **Z, Q, S, D** |
| **Attaque** | *Automatique à l'arrêt* | *Automatique à l'arrêt* |
| **Compétence Ultime** | Bouton **X** | Touche **E** ou **Espace** |
| **Interaction / Valider** | Bouton **A** | Touche **Entrée** ou Clic gauche |
| **Retour / Annuler** | Bouton **B** | Touche **Échap** ou Clic droit |
| **Navigation Menus** | **Écran Tactile (Stylet)** ou D-Pad | **Souris (Clic & Glisser)** |
| **Overlay Performances GPU/FPS** | Bouton **SELECT** | Touche **F3** |
| **Pause** | Bouton **START** | Touche **P** ou **Échap** |

---

## 📦 Guide d'Installation

### 1. Sur Console Nintendo 3DS (CFW Luma3DS)

#### Option A : Format `.CIA` (Recommandé - Installation Menu HOME)
1. Téléchargez la dernière version de `Arch3ro.cia` depuis la section [Releases](https://github.com/tonydetony1/arch3ro3ds/releases).
2. Copiez `Arch3ro.cia` sur votre carte SD (par exemple dans le dossier `cias/`).
3. Lancez **FBI** sur votre console, naviguez jusqu'à `Arch3ro.cia` et choisissez **Install and delete CIA**.
4. Revenez au Menu HOME : une nouvelle boîte cadeau contenant **Arch3ro** apparaît avec sa bannière et ses jingles personnalisés !

#### Option B : Format `.3DSX` (Homebrew Launcher)
1. Téléchargez `Arch3ro.3dsx` et `Arch3ro.smdh`.
2. Créez un dossier `3ds/Arch3ro/` à la racine de votre carte SD.
3. Copiez-y `Arch3ro.3dsx` et `Arch3ro.smdh`.
4. Lancez le **Homebrew Launcher** et démarrez le jeu.

---

### 2. Sur Émulateur (Citra / Azahar)
- Téléchargez et installez l'émulateur [Citra](https://citra-emu.org/) ou [Azahar](https://github.com/azahar-emu/azahar).
- **Fichier CIA** : Allez dans `File` ➔ `Install CIA...` et sélectionnez `Arch3ro.cia`.
- **Fichier 3DSX** : Glissez-déposez directement le fichier `Arch3ro.3dsx` dans la fenêtre de l'émulateur.

---

### 3. Sur PC Desktop (Linux / macOS / Windows)

Vous pouvez lancer le jeu nativement sans émulateur grâce au runtime officiel **LÖVE 2D (11.x)** :
1. Installez [LÖVE 11.4+](https://love2d.org/).
2. Clonez le dépôt GitHub :
   ```bash
   git clone https://github.com/tonydetony1/arch3ro3ds.git
   cd arch3ro3ds
   ```
3. Lancez le jeu :
   ```bash
   love .
   ```
4. *Options avancées pour développeurs :*
   ```bash
   love . --sim3ds       # Simule le budget de sommets et les limites GPU 3DS
   love . --gpustats     # Affiche l'overlay FPS, appels de rendu et sommets
   love . --bench        # Démarre le banc de test automatisé
   ```

---

## 🛠️ Compilation & Outils Développeurs

Le projet intègre un pipeline de build automatisé en Python permettant de générer les exécutables 3DS à partir des sources.

### Prérequis
- **Python 3.8+** avec `Pillow` (`pip install Pillow`)
- **makerom** (inclus dans le dossier `tools/`)
- Runtime **LÖVE-Potion** (templates ELF et 3DSX inclus dans `tools/.templates/`)

### Lancer la compilation complète
Exécutez simplement à la racine du projet :
```bash
python3 tools/build_all.py
```

Le script effectue automatiquement les opérations suivantes :
1. **Compilation de l'atlas graphique** et conversion en texture GPU native 3DS (`assets/atlas.t3x` via `png2t3x.py`).
2. **Empaquetage du code du jeu** dans une archive compressée `game.love`.
3. **Application des patches binaires** universels sur le runtime LÖVE-Potion (NOP `mcuHwcInit` pour compatibilité émulateurs/consoles, NOP `__PHYSFS_platformCalcBaseDir` et ajustement `boot.lua`).
4. **Assemblage d'`Arch3ro.3dsx`** avec métadonnées SMDH intégrées.
5. **Génération d'`Arch3ro.cia`** via `makerom` avec bannière officielle, icônes CTR et configuration RSF.

---

## 📂 Structure du Répertoire

```text
arch3ro3ds/
├── Arch3ro.cia               # Package installable Menu HOME 3DS
├── Arch3ro.3dsx              # Binaire exécutable Homebrew Launcher
├── Arch3ro.smdh              # Métadonnées, titre, auteur et icône CTR
├── conf.lua                  # Configuration LÖVE / dimensions écrans 3DS
├── main.lua                  # Point d'entrée, boucle de rendu et entrées
├── assets/                   # Atlas visuels, textures t3x, logos et audio
│   ├── atlas.png / atlas.t3x # Spritesheet universel précompilé
│   ├── banner.png / icon.png # Bannières et icônes officielles
│   └── audio/                # Effets sonores et thèmes musicaux
├── src/
│   ├── audio/                # Gestionnaire de musique et SFX adaptatifs
│   ├── core/                 # Boucle d'événements, GPU, caméra, physique, pools
│   │   ├── gpu.lua           # Garde-fous mémoire sommets PICA200
│   │   ├── runloop.lua       # Boucle optimisée 60 FPS (redessin tactile éco)
│   │   ├── screen.lua        # Abstraction dual-screen & coordonnées
│   │   └── world_manager.lua # Génération des 6 chapitres et biomes
│   ├── data/                 # Catalogues data-driven (armes, héros, stats, loot)
│   │   ├── heroes.lua        # Fiches des 5 rôdeurs et compétences ultimes
│   │   ├── items.lua         # Équipements, raretés et système de fusion
│   │   ├── skills.lua        # 80+ compétences en combat et hooks
│   │   └── bestiary.lua      # Fiches monstres, boss et maîtrise des éliminations
│   ├── entities/             # Joueur, monstres, familiers, projectiles, butins
│   ├── render/               # Moteurs de rendu, dioramas 3D, profondeur stéréoscopique
│   │   └── depth.lua         # Décalage stéréoscopique natif (Slider 3D)
│   ├── states/               # États de jeu (Menu, Jeu, Pause, GameOver, Forge)
│   └── ui/                   # Système d'interface tactile "Gummy UI", polices pixel
└── tools/                    # Scripts de build, conversion t3x, makerom
```

---

## 🤝 Contribution & Remerciements

Les contributions, signalements de bugs et suggestions sont les bienvenus ! N'hésitez pas à ouvrir une *Issue* ou à soumettre une *Pull Request*.

### Remerciements chaleureux à :
- **[TurtleP](https://github.com/TurtleP)** et l'équipe de **[LÖVE-Potion](https://lovebrew.org/)** pour le portage de LÖVE sur Nintendo 3DS.
- La communauté homebrew Nintendo 3DS (**devkitPro**, **libctru**, **citro3d**).
- **Habby** pour l'inspiration originale du gameplay d'*Archero*.

---

<div align="center">
  <sub>Développé avec passion par <a href="https://github.com/tonydetony1">tonydetony1</a> pour la communauté Nintendo 3DS.</sub>
  <br/>
  <sub>Nintendo 3DS™ est une marque déposée de Nintendo Co., Ltd. Ce projet homebrew indépendant n'est ni affilié ni approuvé par Nintendo.</sub>
</div>
