#!/usr/bin/env bash
# bricolage du dimanche qui signe numériquement le texte d'un fichier pdf
# on obtient une "signature numérique simple"
# /!\ ne pas utiliser sur des pdf d'images (scans etc.) /!\
#
# usage : parapheur.sh fichier.pdf
# Résultat: fichier_signed.pdf
# Résultat auxilliaire la signature numérique: fichier_signature.txt
# On devrait publier la signature numérique sur un site pour la non répudiation
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

## un peu de couleur
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
function print_err() {
    printf "${RED}FAILURE${NC} $1\n"
}
function print_ok() {
    printf "${GREEN}OK${NC} $1\n"
}
DEBUG=1
function debug() {
    if (( DEBUG == 1 ))
    then
        printf "${RED}DEBUG${NC} $1\n"
    fi
}

### Configuration et paramètres
# page ou placer la signature
page=1
xshift=4cm
yshift=-12cm
# attention la date ne fait pas partie de la signature
# ce serait inutile du fait de l'absence d'un serveur d'horodatage
ladate=$(date +'le %A %d %b %Y')
# clé privée
key=~/.ssh/parapheur_rsa
# scan d'une signature manuscripte (ou logo etc.)
grigri=/home/pierre/Documents/Administratif/scans/signaturePierreBoudes.jpg  # EFFACER
# largeur en pixels de la signature (peut être inférieure à la largeur
# du grigri, à adapter.
largeur=1280
# faut-il forcer le montage sans calculer de checksum ?
force=0
# faut-il applatir les annotations et transparences du document pdf pour ne pas les perdre ?
flatten=0

function usage() {
    cat <<EOF
usage: $0 file.pdf

Create a copy of file.pdf with a digital signature of its text content
superimposed as an image

-h        shows this help
-p n      the page where to place the signature default to ${page}
-k key    the private key file default to ${key}
-x xshift the horizontal shift of the signature from center default ${xshift}
-y yshift the vertical shift of the signature from center default ${yshift}
-w width  width of the signature in pixels default ${largeur}
-l width  the same as -w
-g image  the background image on which the digital signature will be printed
          default to ${grigri}
-t        also produce a text file containing the digital signature
-d        the date of the day, default ${ladate}
-f        flatten transparent layers and annotations from the original pdf
-F        force signature without a checksum
EOF
    exit 0
}

if (( $# < 1 ))
then
    usage
fi

while getopts "p:x:y:g:k:l:w:d:htfF" opt; do
    case $opt in
        k)  key="$OPTARG"
            ;;
        g)  grigri="$OPTARG"
            ;;
        p)  page="$OPTARG"
            ;;
        x)  xshift="$OPTARG"
            ;;
        y)  yshift="$OPTARG"
            ;;
        l)  largeur="$OPTARG"
            ;;
        w)  largeur="$OPTARG"
            ;;
        d)  ladate="$OPTARG"
            ;;
        t)  text=1
            ;;
        f)  flatten=1
            ;;
        F)  force=1
            ;;
        h)  usage
            ;;
    esac
done


shift $((OPTIND-1))
file="$1"
debug "$file"

if [ ! -f "$file" ]
then
    print_err "no file $file"
    exit 1
fi

pdfinfo "${file}" > /dev/null
if [ ! $? -eq 0 ]
then
    print_err "not the good kind of pdf file"
    exit 1
fi

words="nothing"
if (( $force == 0 ))
then
    words=$(pdftotext "${file}" - |wc -w)
    debug "nombre de mots : $words"
    if (( $words < 10 ))
    then
        print_err "the text of ${file} contains less than 10 words (${words})!"
        exit 1
    fi
fi

# Répertoire courant (chemin absolu)
unsigneddir="$( cd "$(dirname "$file")" ; pwd -P )"
debug "unsigneddir: ${unsigneddir}"
# noms des fichiers
unsigned="$(basename "$file")"
signed="${unsigned%.pdf}_signed.pdf"
sgnaturetext="${unsigned%.pdf}_signature.txt"
# nombre de pages
last=0
last=$(pdfinfo "${unsigneddir}/${unsigned}"|grep Pages:|cut -f 2 -d:)

if (( $last < $page ))
then
    print_err "there is no ${page} (document is ${last} pages long)"
    exit 1
fi

function hash_pdf() {
    pdftotext "$1" - | openssl dgst -sha256 -c -hex \
            -sign  ${key} | \
            sed -e 's/(stdin)= //' | sed -e 's/:/ /g'
}

### debut du traitement
echo "Processing ${unsigneddir}/${unsigned}..."

# Tout se fait dans un répertoire temporaire
tmpdir=$(mktemp -d)
debug "tmpdir = $tmpdir"
debug "${unsigneddir}/${unsigned}"
if (( $flatten == 1 ))
then
  debug "flattening"
  gs -dSAFER -dBATCH -dNOPAUSE -dNOCACHE -sDEVICE=pdfwrite \
  -dPreserveAnnots=false \
   -sOutputFile=$tmpdir"/unsigned_in.pdf" "${unsigneddir}/${unsigned}"
else
    cp "${unsigneddir}/${unsigned}" $tmpdir"/unsigned_in.pdf"
fi
cp ${grigri} $tmpdir
grigri=$(basename ${grigri})
pushd $tmpdir > /dev/null

# Calcul de la signature
# on passe une première fois par latex, pour "normaliser" le pdf
cat > unsigned.tex <<EOF
\documentclass[a4paper]{article}

\usepackage{pdfpages}
\usepackage{tikz}

\begin{document}
\includepdf[pages=-]{unsigned_in.pdf}
\end{document}
EOF
pdflatex unsigned.tex > /dev/null

hash=$(hash_pdf unsigned.pdf)

# Fabrication de l'image de signature (alternative une signature GPG
# armored en texte entre begin end à séparer du document pour vérif)
echo ${ladate}
convert -background none \
        -font Monaco -fill lightblue -pointsize 20 \
        -gravity center \
        -size ${largeur}x \
        caption:"${hash}" \
        ${grigri} \
        +swap \
        -composite \
        -fill black -font Courier \
        -pointsize 60 \
        -annotate +0+140 "${ladate}" \
        sign.png

cat > sign.tex <<EOF
\documentclass[a4paper]{article}

\usepackage{pdfpages}
\usepackage{tikz}

\begin{document}
EOF

if (($page > 1))
then
    echo "\includepdf[pages=1-$(($page - 1))]{unsigned.pdf}" >> sign.tex
fi

cat >> sign.tex <<EOF
\begin{tikzpicture}[remember picture, overlay]
    \node[inner sep=0pt] at (current page.center) {%
      \includegraphics[page=${page}]{unsigned.pdf}
    };%
\end{tikzpicture}
\thispagestyle{empty}
\begin{tikzpicture}[remember picture, overlay]
\node[inner sep=0pt,xshift=${xshift},yshift=${yshift}] at (current page.center) {%
\includegraphics[width=4.3cm]{sign.png}%
};%
\end{tikzpicture}
EOF

if (($page < $last))
then
    echo "\includepdf[pages=$(($page + 1))-last]{unsigned.pdf}" >> sign.tex
fi

echo "\end{document}" >> sign.tex
pdflatex sign.tex > /dev/null
pdflatex sign.tex > /dev/null
popd > /dev/null
mv ${tmpdir}/sign.pdf "${signed}"
debug ${tmpdir}
#rm -rf ${tmpdir}

### Vérification
if (( $force == 0 ))
then
    debug "vérification : $signed"
    newhash=$(hash_pdf "${signed}")
    if [ "$hash" = "$newhash" ]
    then
        echo "digital signature:"
        echo $hash
        if (( text = 1 ))
        then
            echo $hash|sed -e 's/ /:/g' > "${unsigned%.pdf}_signature.txt"
            print_ok "signature file: ${unsigned%.pdf}_signature.txt"
        fi
        echo "Signed file: ${unsigneddir}/${signed}"
        print_ok "Success "
        exit 0
    else
        print_err "/!\ digital signatures mismatch!"
        exit 1
    fi
fi
