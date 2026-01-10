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

Au premier lancement, un import des assets est fait automatiquement pour eviter les erreurs de textures.

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
- `scripts/Bot.gd`: bots statiques (cibles)
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
- `tracer_time`, `tracer_speed`, `tracer_width`, `tracer_segment_length`, `tracer_every_n`, `tracer_color`, `tracer_muzzle_offset`, `show_tracers`: visibilite/forme des traceurs
- `impact_size`, `impact_lifetime`, `impact_fade_time`, `impact_color`, `impact_offset`, `show_impacts`: impacts de balles sur les murs
- `show_own_body`: afficher votre propre skin en vue FPS
- `character_skin_scale`, `weapon_skin_scale`: taille des skins perso/arme

## ToDo (Enlever le texte quand elle sont implémentées) :

Gameplay :


- Quand un joueur tue un autre, l'info s'affiche bien en haut à gauche mais on sais pas si le tir qui l'a tué a était fait dans la tete ou pas ?

- Fix problème tir la balle doit partir en ligne droite sur le curseur, elle ne doit pas partir de l'arme. 
Pour l'animation y'en a une qui vient de l'arme, mais c'est juste une animation. 

- Avoir du recul avec l'arme, comme dans CS-GO, le joueur ne bouge pas, mais la camera monte un peu et va legerement a gauche ou a droite aléatoirement. 

- Pouvoir viser avec le clic droit. En mode viseur, on a un viseur et la camera zoom un peu comme dans les jeux. On voit a travers le viseur de l'arme
  
- Ajouter un peu de dispertion quand on tire sans viser et avoir une precision parfaite quand on vise
- Viser fait ralentir le joueur dans ces déplacements
   
- Quand on fait option, un menu s'ouvre et on peut changer son skin.
- Ajouter 2 autres armes, on peut changer d'areme en appuyant sur la touche E

Design :
- Animation fluide quand on passe en mode viseur et quand on le quitte
- Arme qui bouge quand on avance
- Camera qui bouge quand on avance, elle doit mimer un mouvement de tete lorsque que l'on marche, fait quelque chose de simple mais réaliste
