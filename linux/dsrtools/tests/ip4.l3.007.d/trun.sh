#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

Tmplts=( expected.status.1
         expected.status.3
       )
expand_templates Tmplts "$Table"

# Run tests.
typeset rv=0

(( rv && ! ErrIgnore )) || start_one_loopback 188.125.67.68 1 || rv=1
(( rv && ! ErrIgnore )) || start_one_loopback 188.125.67.69 2 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-a" n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd start  ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-a" n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  4 || rv=1

(( rv && ! ErrIgnore )) || docmd stop   ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-a" n:20  5 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  6 || rv=1

dsrcleanup

exit $rv
