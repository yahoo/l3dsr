#!/bin/ksh

. ../testfunctions.sh

rv=0
RunTest "$@" || rv=$?
(( ErrIgnore == 0 )) || rv=0

exit $rv
