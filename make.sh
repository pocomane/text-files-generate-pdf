#!/bin/sh
set -e
SCRDIR="$(readlink -f "$(dirname "$0")")"
# #############################################################################
RUNARG="aksldkfjawllkrfjdsalkehgvalsddvh"
TMPFIL="tmp.tmp"
DOWNURL="https://github.com/pocomane/text-files-generate-pdf/archive/refs/heads/main.zip"
DOWNCONTENTDIR="text-files-generate-pdf-main"
GUTENURL="https://github.com/pocomane/guten/archive/refs/heads/master.zip"
GUTENCONTENTDIR="guten-master"
BUILDSUBDIR="build"
# #############################################################################

make_all(){
  mkdir -p "$BUILDSUBDIR"
  apk add lua5.4 font-roboto weasyprint
  if [ ! -e "$BUILDSUBDIR/$GUTENCONTENTDIR" ] ; then
    wget -O "$TMPFIL" "$GUTENURL"
    cd "$BUILDSUBDIR"
    unzip ../"$TMPFIL"
    cd -
    rm "$TMPFIL"
  fi
  set -x
  for FILE in $(ls *.md) ; do
    lua5.4 "$BUILDSUBDIR"/"$GUTENCONTENTDIR"/guten.lua --content="$FILE" --out=./"$BUILDSUBDIR"/"${FILE%.*}"-book.html book.tmpl
    weasyprint ./"$BUILDSUBDIR"/"${FILE%.*}"-book.html ./"$BUILDSUBDIR"/"${FILE%.*}"-book.pdf
  done
}

# #############################################################################
if [ "$1" = "$RUNARG" ] ; then
  make_all
else
  if [ -e "$SCRDIR/runalp.sh" ] ; then
    "$SCRDIR/runalp.sh" ./make.sh "$RUNARG"
  else
    wget -O "$TMPFIL" "$DOWNURL"
    unzip "$TMPFIL"
    rm "$TMPFIL"
    cd "$DOWNCONTENTDIR"
    ./make.sh
  fi
fi

