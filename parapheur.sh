#!/usr/bin/env bash
# bricolage du dimanche qui signe numériquement le texte d'un fichier pdf
# on obtient une "signature numérique simple"
# /!\ ne pas utiliser sur des pdf d'images (scans etc.) /!\
#
# usage : parapheur.sh fichier.pdf
# Résultat: fichier_signe.pdf
#
#### Prérequis
# apt-get install openssl imagemagick latex <-- Huge
# une paire de clés, on peut la générer ainsi :
# cd ~/.ssh/ ; ssh-keygen -f parapheur.rsa
#
### Fonctionnement
# 1. extrait le texte du pdf avec pdftotext
# 2. hash et signe le texte avec une clé privée
# 3. crée une image avec le hash et un grigri graphique
# 4. appose l'image sur la seconde page du pdf en utilisant latex


### Configuration
# page ou placer la signature
page=2
# clé privée
key=~/.ssh/parapheur.rsa
# scan d'une signature manuscripte (ou logo etc.)
grigri=~/Documents/img/signature_example.jpg # ADAPTER
grigri=img/paris13_aile_960.png # EFFACER
# largeur en pixels de la signature (peut être inférieure à la largeur
# du grigri, à adapter.
largeur=960

# Répertoire courant (chemin absolu)
unsigneddir="$( cd "$(dirname "$1")" ; pwd -P )"
# noms des fichiers pdf
unsigned="$(basename $1)"
signed="${unsigned%.pdf}_signed.pdf"
# nombre de pages
last=$(pdfinfo ${unsigneddir}/${unsigned}|grep Pages:|cut -f 2 -d:)

echo Traitement de ${unsigneddir}/${unsigned}

# Calcul de la signature
hash=$(pdftotext ${unsigneddir}/${unsigned} - | openssl dgst -sha256 -c -hex \
             -sign  ${key} | \
              sed -e 's/(stdin)= //' | sed -e 's/:/ /g')
# echo $hash

# Fabrication de l'image de signature (alternative une signature GPG
# armored en texte)
tmpdir=$(mktemp -d -t sign)
cp ${unsigneddir}/${unsigned} $tmpdir
pushd $tmpdir > /dev/null
convert -background none \
        -font Monaco -fill lightblue -pointsize 30 \
        -gravity center \
        -size ${largeur}x \
        caption:"${hash}" \
        ${grigri} \
        +swap \
        -composite \
        sign.png

cat > sign.tex <<EOF
\documentclass[a4paper]{article}

\usepackage{pdfpages}
\usepackage{tikz}

\begin{document}
EOF

if (($page > 1))
then
    echo "\includepdf[pages=1-$(($page - 1))]{$unsigned}" >> sign.tex
fi

cat >> sign.tex <<EOF
\begin{tikzpicture}[remember picture, overlay]
    \node[inner sep=0pt] at (current page.center) {%
      \includegraphics[page=${page}]{$unsigned}
    };%
\end{tikzpicture}
\thispagestyle{empty}
\begin{tikzpicture}[remember picture, overlay]
\node[inner sep=0pt,xshift=100,yshift=-200] at (current page.center) {%
\includegraphics[scale=0.2]{sign.png}%
};%
\end{tikzpicture}
EOF

if (($page < $last))
then
    echo "\includepdf[pages=$(($page + 1))-last]{$unsigned}" >> sign.tex
fi

echo "\end{document}" >> sign.tex
pdflatex sign.tex > /dev/null
pdflatex sign.tex > /dev/null
popd > /dev/null
mv ${tmpdir}/sign.pdf ${signed}
rm -rf ${tmpdir}


### Vérification
newhash=$(pdftotext ${signed} - | openssl dgst -sha256 -c -hex \
             -sign  ${key} | \
                 sed -e 's/(stdin)= //' | sed -e 's/:/ /g')
#echo '** empreinte apposée **'
#echo $hash
#echo '** nouvelle empreinte (doit être identique) **'
#echo $newhash
if [ "$hash" = "$newhash" ]
then
    echo "OK les empreintes coincident"
    echo "Fichier signé : ${unsigneddir}/${signed}"
    echo "Empreinte de la signature :"
    echo $hash
    exit 0
else
    echo "/!\ ERREUR, les empreintes ne coincident pas"
    echo "Essayez de relancer $0 ${unsigneddir}/${signed}"
    exit 1
fi
