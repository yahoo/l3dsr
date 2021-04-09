#!/bin/ksh

. ../testfunctions.sh

init "$@"

unload_kmod
load_kmod

# Run tests.
typeset rv=0

# Test for conf file with spaces in the name.
(( rv && ! ErrIgnore )) || docmd start   ""         "f:20-v i p.conf"  1 || rv=1
(( rv && ! ErrIgnore )) || docmd status  ""         "f:20-v i p.conf"  1 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    ""         "f:20-v i p.conf"  1 || rv=1

# Test for bad options.
(( rv && ! ErrIgnore )) || docmd start   "-z"       n:21               2 || rv=1
(( rv && ! ErrIgnore )) || docmd status  "-b abc"   n:21               3 || rv=1
(( rv && ! ErrIgnore )) || docmd boomer  ""         n:21               4 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    "-h"       n:21               5 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    "-sfoo"    n:21              10 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    "-s0:foo"  n:21              11 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    "-s.:."    n:21              12 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    "-sfoo:.4" n:21              13 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    "-s.4:bar" n:21              14 || rv=1

# Test for nonexistent FQDN.
(( rv && ! ErrIgnore )) || docmd status  ""         n:22               6 || rv=1

# Test for nonexistent config file.
(( rv && ! ErrIgnore )) || docmd status  ""         f:foo.conf         7 || rv=1

# Test for nonexistent config dir.
(( rv && ! ErrIgnore )) || docmd status  ""         d:baddir           8 || rv=1

# Test for conf file with no terminating newline.
(( rv && ! ErrIgnore )) || docmd start   ""         "f:23-vip.conf"    9 || rv=1
(( rv && ! ErrIgnore )) || docmd status  ""         "f:23-vip.conf"    9 || rv=1
(( rv && ! ErrIgnore )) || docmd stop    ""         "f:23-vip.conf"    9 || rv=1

dsrcleanup

exit $rv
