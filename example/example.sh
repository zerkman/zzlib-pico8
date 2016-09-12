#!/bin/sh
# build cart with a compressed image, and code to display it

tmplua=`mktemp /tmp/exampleXXXX.lua`

cat ../zzlib.lua >> $tmplua
echo "zzlib.gunzip(0x6000,0x0)" >> $tmplua

lua ../tools/makecart.lua example.p8 -lua $tmplua -gfx troll2.data.gz

rm $tmplua
