#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

Tmplts=( expected.status.1
         expected.status.3
         expected.status.5
       )

expand_templates Tmplts "$Table"

# Run tests.
typeset rv=0

# Initialize loopbacks and iptables rules.
(( rv != 0 )) || start_one_loopback 188.125.66.2 1 || rv=1
(( rv != 0 )) || start_one_loopback 188.125.66.3 2 || rv=1
(( rv != 0 )) || start_one_iptables_rule iptables PREROUTING 188.125.66.2 20 || rv=1
(( rv != 0 )) || start_one_iptables_rule iptables PREROUTING 188.125.66.3 21 || rv=1

(( rv != 0 )) || docmd status "-a" n:20  1 || rv=1
(( rv != 0 )) || docmd status ""   n:20  2 || rv=1

(( rv != 0 )) || docmd start  ""   n:20  1 || rv=1

(( rv != 0 )) || docmd status "-a" n:20  3 || rv=1
(( rv != 0 )) || docmd status ""   n:20  4 || rv=1

(( rv != 0 )) || docmd stop   ""   n:20  1 || rv=1

(( rv != 0 )) || docmd status "-a" n:20  5 || rv=1
(( rv != 0 )) || docmd status ""   n:20  6 || rv=1

dsrcleanup

exit $rv
