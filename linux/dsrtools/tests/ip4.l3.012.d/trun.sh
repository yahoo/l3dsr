#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

Tmplts=( expected.status.1 )

expand_templates Tmplts "$Table"

# Run tests.
typeset rv=0

(( rv && ! ErrIgnore )) || start_one_loopback 188.125.67.68 1 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables PREROUTING 188.125.82.38 19 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-a" n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd stop   ""   n:20  1 || rv=1

dsrcleanup

exit $rv
