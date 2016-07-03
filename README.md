# Parapheur

Un script pour générer une signature numérique simple du texte d'un fichier pdf et l'appposer comme une image sur le document pdf à une page choisie dans la configuration du script (todo: on peut en faire un paramètre).

_Ne pas utiliser sur des pdf scannés_ et autres pdf dont le texte extrait par ~pdftotext~ ne décrit pas le contenu, on ne signe que le texte du pdf.

## Prérequis
~apt-get install openssl imagemagick latex~

une paire de clés, on peut la générer ainsi :
cd ~/.ssh/ ; ssh-keygen -f parapheur.rsa

## Usage
~parapheur.sh fichier.pdf~
Résultat: ~fichier_signe.pdf~
vérifier la sortie du script un petit espace se glisse parfois dans le nouveau texte (relancer et vérifier le résultat obtenu…)

## Fonctionnement
1. extrait le texte du pdf avec pdftotext
2. hash et signe le texte avec une clé privée
3. crée une image avec le hash et un grigri graphique
4. appose l'image sur la seconde page du pdf en utilisant latex
