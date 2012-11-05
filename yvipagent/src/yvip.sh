#! /bin/sh
#
# Copyright (c) 2009,2010,2011,2012 Yahoo! Inc.
#
# Originally written by Jan Schaumann <jschauma@yahoo-inc.com> in September
# 2009.
#
# This is an old-fashioned rc-style startup script to configure a host for
# participation in any VIPs.
#
# Since this script may be used on various platforms, we can't take
# advantage of all the neat rc(8) goodness that FreeBSD 6.x (and higher)
# comes with, so we cobble the required functionality together ourselves.
#
#
# Redistribution and use of this software in source and binary forms, with
# or without modification, are permitted provided that the following
# conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# * Neither the name of Yahoo! Inc. nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission of Yahoo! Inc.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

NAME="yvip"
AGENT="/usr/local/libexec/yvipagent"
CONFDIR="/usr/local/etc/yvip/vips"

runOrDie() {
	local arg=${1}

	${AGENT} -d ${CONFDIR} ${arg}
	if [ $? -gt 0 ]; then
		echo "failed!" >&2
		exit 1;
	fi
	echo "done."
}

check() {
	echo -n "Checking ${NAME} configurations... "
	runOrDie check
}

start() {
	echo -n "Starting ${NAME}... "

	if [ ! -x "${AGENT}" ]; then
		echo "Unable to execute ${AGENT}." >&2
		exit 1;
	fi

	if [ ! -d "${CONFDIR}" ]; then
		echo "Configuration file directory '${CONFDIR}' not found."
		return
	fi

	runOrDie start
}

stop() {
	echo -n "Stopping ${NAME}... "
	runOrDie stop
}

usage() {
	echo "Usage: $0 (check|start|stop|restart)"
}

case $1 in
	check)
		check
	;;
	start)
		start
	;;
	stop)
		stop
	;;
	restart)
		stop && start
	;;
	*)
		usage
		exit 1
	;;
esac
