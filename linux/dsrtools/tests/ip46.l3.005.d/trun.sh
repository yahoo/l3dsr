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



# These are the same IPs as in 20-vip.conf.
# The OUTPUT chain rules should not conflict with the VIP rules.
# Note that I'm choosing to use the OUTPUT chain because it exists for both
# the raw and mangle tables.
(( rv != 0 )) || start_one_iptables_rule iptables  OUTPUT     188.125.67.1             10 || rv=1
(( rv != 0 )) || start_one_iptables_rule iptables  OUTPUT     188.125.67.2             11 || rv=1
(( rv != 0 )) || start_one_iptables_rule iptables  OUTPUT     188.125.67.3             12 || rv=1
(( rv != 0 )) || start_one_iptables_rule ip6tables OUTPUT     2a00:1288:110:021b::4002 32 || rv=1
(( rv != 0 )) || start_one_iptables_rule ip6tables OUTPUT     2a00:1288:110:021b::4002 35 || rv=1


(( rv != 0 )) || docmd status "-a"  n:20  1 || rv=1
(( rv != 0 )) || docmd status ""    n:20  2 || rv=1

(( rv != 0 )) || docmd start  ""    n:20  1 || rv=1

(( rv != 0 )) || docmd status "-a"  n:20  3 || rv=1
(( rv != 0 )) || docmd status ""    n:20  4 || rv=1

(( rv != 0 )) || docmd stop   ""    n:20  1 || rv=1

(( rv != 0 )) || docmd status "-a"  n:20  1 || rv=1
(( rv != 0 )) || docmd status ""    n:20  2 || rv=1

# Run the same tests, but use the -i option.  The output
# should remain the same.
(( rv != 0 )) || docmd status "-ai" n:20  1 || rv=1
(( rv != 0 )) || docmd status "-i"  n:20  2 || rv=1

(( rv != 0 )) || docmd start  "-i"  n:20  1 || rv=1

(( rv != 0 )) || docmd status "-ai" n:20  3 || rv=1
(( rv != 0 )) || docmd status "-i"  n:20  4 || rv=1

(( rv != 0 )) || docmd stop   "-i"  n:20  1 || rv=1

(( rv != 0 )) || docmd status "-ai" n:20  1 || rv=1
(( rv != 0 )) || docmd status "-i"  n:20  2 || rv=1

dsrcleanup

# dsrcleanup (dsrctl -a stop) only touches PREROUTING rules,
# so we need to clean up the OUTPUT rules we started here.
stop_one_iptables_rule iptables  OUTPUT     188.125.67.1             10 || true
stop_one_iptables_rule iptables  OUTPUT     188.125.67.2             11 || true
stop_one_iptables_rule iptables  OUTPUT     188.125.67.3             12 || true
stop_one_iptables_rule ip6tables OUTPUT     2a00:1288:110:021b::4002 32 || true
stop_one_iptables_rule ip6tables OUTPUT     2a00:1288:110:021b::4002 35 || true

exit $rv
