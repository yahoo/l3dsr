#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

# Run tests.
typeset rv=0

(( $rv != 0 )) || docmd start  "" d:.  1 || rv=1
(( $rv != 0 )) || docmd status "" d:.  1 || rv=1
(( $rv != 0 )) || docmd stop   "" d:.  1 || rv=1

dsrcleanup

exit $rv
