#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

TmpFiles+=( 20-vip.conf )
sed -e "s/NODE/$Node/" \
    20-vip.conf.template > 20-vip.conf

Tmplts=( expected.status.1 )

expand_templates Tmplts "$Table"

# Run tests.
typeset rv=0

(( rv != 0 )) || docmd start  ""   n:20  1 || rv=1

(( rv != 0 )) || docmd status ""   n:20  1 || rv=1

(( rv != 0 )) || docmd stop   ""   n:20  1 || rv=1

# Stop
dsrcleanup

exit $rv
