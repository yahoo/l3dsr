#!/bin/bash
#
# dsr:               dsr starts up the DSR configuration for this machine.
#
# chkconfig: 2345 99 01
#
# description:       dsr initializes this machine to support DSR (direct server
#                    return) based on the configuration files in /etc/dsr.d.
#

# Source function library.
. /etc/init.d/functions

RETVAL=0
case "$1" in
  restart)
	action "Restart DSR:" /usr/sbin/dsrctl restart
	;;

  start)
	action "Start DSR:" /usr/sbin/dsrctl start
	;;

  stop)
	action "Stop DSR:" /usr/sbin/dsrctl stop
	;;

  status)
	/usr/sbin/dsrctl check
	RETVAL=$?
	;;

  *)
	echo $"Usage: $0 {restart|start|stop|status}" >&2
	RETVAL=1
esac

exit $RETVAL
