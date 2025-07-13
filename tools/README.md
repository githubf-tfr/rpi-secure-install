# git‑update
## Usage : 
git‑update [-y] [commit‑message]
## Options :
- "-y" : active le mode automatique, sans aucune confirmation
- commit‑message : message à utiliser si un commit est nécessaire (sinon un message par défaut est utilisé)
## Fonctionnement :
- Vérifie les modifications locales (modifications non indexées, indexées ou fichiers non suivis)
- Si des changements sont détectés, effectue : git add -A, git commit (avec le message donné ou par défaut), puis git push
- Récupère les mises à jour distantes via git fetch --prune
- Si la branche locale est en retard, effectue automatiquement un pull avec rebase
- Si la branche locale est en avance, effectue automatiquement un push
- Si la branche a divergé (modifications locales ET distantes), affiche un avertissement et arrête
- Nettoie les branches distantes supprimées avec git remote prune origin
## Exemples d’utilisation :
- git‑update : mode interactif avec questions à chaque étape
- git‑update -y : exécution automatique avec message de commit par défaut
- git‑update -y Mon message perso : exécution automatique avec message personnalisé

