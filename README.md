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

- Map plus grande avec des structure plus nombreuses et plus complexes, rajoute une mini map en haut le point du joueurs et des autres joueurs uniquemment quand ils tirent. La mini map est ronde et bouge en fonction des deplacement du joueurs et de la camera.

- Reduire degats arme principale

- Avoir une option pour lancer en mode debug avec les 3 bots sans arme et celui avec arme, ou en mode normal où il n'y a pas de bot, et où les joueurs peuvent s'affronter

- Détailler les conditions dans le readme pour se connecter en join (meme wifi ? meme version godot ? possible avec le meme ordi ?)

- Regler le viseur, mettre l'arme un peu plus en bas et à gauche. Arreter de la faire bouger quand on est en mode viseur.

- Ajouter une 2eme arme, le sniper avec le skin blaster f, on peut changer d'arme en appuyant sur la touche E. Le sniper one-shot, a beaucoup de dispertion sans viser et une precision parfaite en viser. Il y a du temps entre 2 tirs

- Rajouter les munitions en bas à gauche, on peut racharger en appuyant sur R. On commencer avec 1000 munitions. L'arme principale tire 30 balles avant de recharger, le sniper 5.

- Ameliorer le menu avec une preview total de tout les skin et on choisis en cliquand sur celui qui parrait le mieux

Design :
- Voir le nouveau dossier building et voir si on peut créer quelque chose de simple à la bonne echelle avec.