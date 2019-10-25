#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

# Run tests.
typeset rv=0

(( rv != 0 )) || docmd status ""   n:20  1 || rv=1
(( rv != 0 )) || docmd status ""   n:21  2 || rv=1
(( rv != 0 )) || docmd status ""   n:22  3 || rv=1
(( rv != 0 )) || docmd status ""   n:23  4 || rv=1
(( rv != 0 )) || docmd status ""   n:24  5 || rv=1

dsrcleanup

exit $rv
