# LAN FPS (Godot 4)

Petit prototype FPS LAN avec 3 bots (sans arme) qui respawn, une seule arme (fusil d'assaut), et une map simple. Le serveur est autoritaire pour les degats. Les tirs sont hitscan avec dispersion gaussienne, recul, et damage falloff.

## Prerequis
- Godot 4.x installe et accessible en ligne de commande (`godot` dans le PATH), ou definir `GODOT_EXE`.
- Sous Windows, `run.bat` utilisera automatiquement `tools\\godot\\Godot_v4.2.2-stable_win64.exe` si present.

## Lancer
### Windows
```
run.bat host
run.bat join 192.168.0.10
```

### Linux
```
chmod +x run.sh
./run.sh host
./run.sh join 192.168.0.10
```

## Notes reseau
- Pour vos amis sur le LAN, partagez votre IP locale (ex: `192.168.x.x`), pas `localhost`.
- Port par defaut: `7777` (modifiable via `--port=7777` si besoin).

## Controles
- ZQSD / WASD: deplacement
- Shift: sprint
- Space: saut
- Souris: viser
- Click gauche: tirer
- Esc: libere/capture la souris

## Structure
- `scenes/Main.tscn`: gestion reseau + spawns
- `scripts/Player.gd`: mouvement FPS + tir realiste (recul, dispersion, falloff)
- `scripts/Bot.gd`: bots simples (errance)
- `scenes/Map.tscn`: petite map statique

## ToDo (Enlever le texte quand elle sont implémentées) :

Gameplay :
- Pouvoir viser avec le clic droit
- Mort instantané quand la balle touche la tête

Design :
- Voir pour trouver des skin de perso et d'armes, avec des décors 