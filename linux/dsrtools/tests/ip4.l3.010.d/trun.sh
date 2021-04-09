#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

# Run tests.
typeset rv=0

(( rv && ! ErrIgnore )) || docmd status  ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd start   ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status  ""   n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd restart ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status  ""   n:20  2 || rv=1

(( rv && ! ErrIgnore )) || docmd stop    ""   n:20  1 || rv=1

(( rv && ! ErrIgnore )) || docmd status  ""   n:20  3 || rv=1

dsrcleanup

exit $rv
