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

## Hyperparametres (a tester/modifier)
Ces valeurs sont exposees dans le script `scripts/Player.gd` et controlent le feeling du tir.

- `move_speed`, `sprint_speed`, `jump_velocity`: vitesse de base, sprint et saut
- `mouse_sensitivity`, `max_pitch`: sensibilite et limite verticale de la camera
- `fire_rate`: cadence de tir (balles/seconde)
- `spread_degrees`: dispersion (0.0 = precision maximale)
- `recoil_kick_pitch`, `recoil_kick_yaw`: recul instantane
- `recoil_return_speed`: vitesse de retour du recul
- `max_distance`: portee du hitscan
- `base_damage`, `min_damage`: degats min/max
- `falloff_start`, `falloff_end`: debut/fin du damage falloff
- `max_health`: points de vie
- `tracer_time`, `tracer_width`, `tracer_color`, `tracer_muzzle_offset`, `show_tracers`: visibilite/forme des traceurs

## ToDo (Enlever le texte quand elle sont implémentées) :

Gameplay :
- Pouvoir viser avec le clic droit
- Mort instantané quand la balle touche la tête
- Ajouter un peu de dispertion quand on tire sans viser et avoir une precision parfaite quand on vise
- Viser tous fait ralentir 
- Le viseur doit etre 
- Avoir du recul avec l'arme, comme dans CS-GO, on ne bouge pas, mais le viseur monte un peu et va legerement a gauche ou a droite aléatoirement
- Impact ball sur le mur qui disparaisse avec le temps

Design :
- En mode viseur, on a un viseur et la camera zoom un peu comme dans les jeux
- Trouver un skin d'une personne
- Trouver un skin d'une arme
