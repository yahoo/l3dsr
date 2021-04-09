#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

Tmplts=( expected.start.1
         expected.status.1
         expected.stop.1
         expected.start.2
         expected.status.2
         expected.stop.2
         expected.start.3
         expected.status.3
         expected.stop.3
         expected.status.4
         expected.status.5
         expected.start.6
       )

expand_templates Tmplts "$Table"

# Run tests.
typeset rv=0

# Test for single -v.
(( rv && ! ErrIgnore )) || docmd start  "-v"                n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-v"                n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd stop   "-v -s1:0.25"       n:20  1 || rv=1

# Test the -i option by verifying that the -I iptables option is
# used when adding iptables rules.
(( rv && ! ErrIgnore )) || docmd start  "-vi"               n:20  6 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-vi"               n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd stop   "-vi -s1:0.25"      n:20  1 || rv=1

# Test for double -vv.
(( rv && ! ErrIgnore )) || docmd start  "-vv"               n:20  2 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-vv"               n:20  2 || rv=1
(( rv && ! ErrIgnore )) || docmd stop   "-vv -s1:0.25"      n:20  2 || rv=1

# Test for triple -vvv.
(( rv && ! ErrIgnore )) || docmd start  "-vvv"              n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-vvv"              n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd stop   "-vvv -s1:0.25"     n:20  3 || rv=1

# Test for triple -vvv.
(( rv && ! ErrIgnore )) || docmd start  "-vvv"              n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-vvv"              n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd stop   "-vvv -s1:0.25"     n:20  3 || rv=1

# Initialize loopbacks and iptables rules.
(( rv && ! ErrIgnore )) || start_one_loopback 188.125.66.2 1 || rv=1
(( rv && ! ErrIgnore )) || start_one_loopback 188.125.66.3 2 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables PREROUTING 188.125.66.2 20 || rv=1
(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables PREROUTING 188.125.66.3 21 || rv=1

(( rv && ! ErrIgnore )) || docmd status "-avvv"             n:30  4 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-vvv"              n:30  5 || rv=1

dsrcleanup

exit $rv
