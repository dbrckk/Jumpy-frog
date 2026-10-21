# JumpyFrog — validation sur Redmi Android 15

## Pourquoi ce contrôle est nécessaire

Les tests Godot et l'émulateur n'utilisent pas les pilotes GPU/audio du Redmi.
Un APK qui compile ne prouve donc ni une image correcte, ni 60 FPS stables,
ni la disparition du crash natif `libwilhelm.so` observé auparavant.

## Test depuis le téléphone (sans PC)

1. Ouvrir [Godot QA and Android APK](https://github.com/dbrckk/Jumpy-frog/actions) et sélectionner la **dernière exécution réussie** sur `main`.
2. Télécharger l'artifact **JumpyFrog-Android-debug**, décompresser son ZIP, puis installer l'APK ARM64 Android. Conserver l'application et ses données si elle est déjà installée (ne pas désinstaller la version précédente).
3. Lancer le jeu et jouer normalement au moins **5 minutes**, dans plusieurs biomes. Vérifier les commandes tactiles, le nénuphar mobile, le nénuphar fragile et les transitions.
4. Pendant une partie, toucher **Pause → Device Diagnostics**. Prendre une capture montrant **FPS moyen**, **95% frame time**, **slow frames** et **graphics**. Ces valeurs sont calculées sur les **240 dernières frames actives** (environ 4 s à 60 FPS) ; elles ne représentent pas toute la session.
5. Revenir à la pause, puis reprendre le jeu. Ouvrir d'autres applications et revenir au jeu plusieurs fois. Vérifier que le timer du nénuphar fragile et le saut en cours ne se dérèglent pas.
6. Jouer jusqu'à la défaite, consulter les records, relancer et vérifier que les feuilles, les missions et l'achat « sans publicité » sont conservés.
7. Effectuer ensuite une session prolongée de **30 minutes**, surveiller les fermetures forcées et vérifier à nouveau le diagnostic dans un biome complexe.

## Audio : attention

- Sur Android, Godot reste configuré avec **Dummy audio** pour éviter le précédent crash natif OpenSL ES.
- La musique et les sons PCM originaux fonctionnent toujours sur les plateformes hors Android, **pas encore sur Redmi**.
- Les **Android System Tones** proposés dans Pause sont une fonctionnalité distincte, **expérimentale et désactivée par défaut**. Ne pas les activer pour le premier essai de stabilité.
- En cas de crash, noter la minute, le biome, l'action en cours, le statut des tons système et la version du téléphone. Si possible, fournir ensuite un rapport de bug Android depuis les options développeur.

## Critères de réussite avant publication

- Une vraie scène de jeu s'affiche sans cadre noir ni erreur graphique.
- Aucun crash ou fermeture forcée en 30 minutes, même lors de la reprise de l'application.
- Commandes, collisions, niveaux et récompenses corrects.
- Sauvegardes intactes après redémarrage.
- Les données Device Diagnostics sont disponibles pour interpréter la fluidité.
- La monétisation réelle doit être testée séparément via le canal **Google Play Internal Testing**, avec UMP/AdMob et Play Billing configurés. Les tests GitHub ne simulent pas une transaction réelle.

Ne jamais qualifier le rendu, l'audio complet ou les achats de « validés sur Redmi » tant que ces contrôles physiques n'ont pas été réalisés.
