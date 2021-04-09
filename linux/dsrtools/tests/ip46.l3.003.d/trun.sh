#!/bin/ksh

. ../testfunctions.sh

function start_iptables_rules
{
	typeset rv=0

	# iptables rules for configured VIP
	(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables  PREROUTING 188.125.67.68 28 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables  PREROUTING 188.125.67.68 28 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables  PREROUTING 188.125.67.68 28 || rv=1

	# iptables rules for configured VIP
	(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables  PREROUTING 188.125.67.69 29 || rv=1

	# iptables rules for nonconfigured VIP
	(( rv && ! ErrIgnore )) || start_one_iptables_rule iptables  PREROUTING 188.125.67.70 30 || rv=1

	# ip6tables rules for configured VIP
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4002 19 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4002 19 || rv=1

	# ip6tables rules for configured VIP
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4003 20 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4003 20 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4003 20 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4003 20 || rv=1

	# ip6tables rules for configured VIP
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4004 21 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4004 21 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4004 21 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4004 21 || rv=1
	(( rv && ! ErrIgnore )) || start_one_iptables_rule ip6tables PREROUTING 2a00:1288:110:21b::4004 21 || rv=1

	return $rv
}

init "$@"

unload_kmod
load_kmod

Tmplts=( expected.status.2
         expected.status.4
       )

expand_templates Tmplts "$Table"

# Run tests.
typeset rv=0

(( rv && ! ErrIgnore )) || docmd start  ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || start_iptables_rules || rv=$?

(( rv && ! ErrIgnore )) || docmd status ""   n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-a" n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd stop   ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status ""   n:20  3 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-a" n:20  4 || rv=1

(( rv && ! ErrIgnore )) || docmd stop   "-a" n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd status ""   n:20  5 || rv=1
(( rv && ! ErrIgnore )) || docmd status "-a" n:20  6 || rv=1

dsrcleanup

exit $rv
