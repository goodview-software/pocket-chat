# Pocket Chat

Chat et échange de fichiers sur le réseau local (même Wi-Fi/LAN), sans serveur ni internet. Un seul projet Godot 4.7 pour PC Linux et Android.

- **Découverte** : beacon UDP en broadcast (port 5206), liaison TCP pair-à-pair (port 5205), trames `[type u8][len u16 LE][données]`.
- **Conversations** : 1-à-1 et salon commun « Tous », horodatage, historique local persistant, pastilles de messages non lus.
- **Fichiers** : sélecteur natif, blocs de 32 Ko avec barre de progression, accepter/refuser (ou acceptation auto dans les réglages), vérification sha256. Reçus dans `Téléchargements/PocketChat` (repli sur `user://received`).
- **Identité** : PC = `~/.config/goodview/profile.json` (`pseudo`, `mascot` 0-7, relu toutes les 2 s) ; Android = nom de l'appareil (modifiable dans les réglages), mascotte au choix.
- Lancer : `flatpak run org.godotengine.Godot --path ~/pocket-chat`
- Test headless (2 instances, message + fichier 5 Mo) : `sh tests/run_test.sh` (variables `CHAT_TEST`, `CHAT_NAME`, `CHAT_DATA`, `CHAT_DL`, `CHAT_TCP`, `CHAT_UDP`, `CHAT_PEERS`).
- Publier : `./release.sh 0.2.0 "Notes"` (zip Linux + APK).

Note : pas de chiffrement ni d'authentification, à n'utiliser que sur un réseau de confiance.
