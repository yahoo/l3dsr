#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

Tmplts=( expected.status.2
       )

expand_templates Tmplts "$Table"


#
# This test is placed in the ip4 set of tests because it needs to run
# whether IPv6 is enabled or disabled.  The test is intended to test
# when IPv6 is disabled that dsrctl prints appropriate output even
# though it is never calling ip6tables.
#

# Run tests.
typeset rv=0

(( rv && ! ErrIgnore )) || docmd status ""    n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd start  ""    n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""    n:20  2 || rv=1
(( rv && ! ErrIgnore )) || docmd stop   ""    n:20  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status ""    n:20  1 || rv=1

dsrcleanup

exit $rv
