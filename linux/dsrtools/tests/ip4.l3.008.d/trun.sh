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

(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables PREROUTING 188.125.66.1 20 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables PREROUTING 188.125.66.2 21 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables OUTPUT     188.125.66.1 20 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables OUTPUT     188.125.66.2 21 || rv=1

# These are the same IP as in 20-vip.conf.
# The OUTPUT chain rules should not conflict with the VIP rules.
# Note that I'm choosing to use the OUTPUT chain because it exists for both
# the raw and mangle tables.
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables OUTPUT     188.125.67.1 10 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables OUTPUT     188.125.67.2 11 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables OUTPUT     188.125.67.3 12 || rv=1


(( rv && ! ErrIgnore )) || docmd status "-a" n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd start  ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-a" n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  4 || rv=1

(( rv && ! ErrIgnore )) || docmd stop   ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-a" n:20  5 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""   n:20  6 || rv=1

dsrcleanup

# dsrcleanup (dsrctl -a stop) only touches PREROUTING rules,
# so we need to clean up the OUTPUTrules we started here.
stop_one_iptables_rule iptables OUTPUT     188.125.66.1 20 || true
stop_one_iptables_rule iptables OUTPUT     188.125.66.2 21 || true
stop_one_iptables_rule iptables OUTPUT     188.125.67.1 10 || true
stop_one_iptables_rule iptables OUTPUT     188.125.67.2 11 || true
stop_one_iptables_rule iptables OUTPUT     188.125.67.3 12 || true

exit $rv
