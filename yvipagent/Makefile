# $Id: Makefile 467 2011-03-08 17:20:08Z jans $
# $URL: svn+ssh://svn.corp.yahoo.com/yahoo/ops/yvip/agent/branches/l3dsr-open-source/Makefile $
#
# This Makefile is used to create a single tarball containig the various
# bits and pieces that make up the server side code of our L3DSR
# architecture.  As such, it reacher over into a few other repositories;
# the result is a tarball without any SVN information.

TARBALL=l3dsr.tar.gz
DOCDIR=${HOME}/dev/svn/yvip/doc
LINUXDIR=${HOME}/dev/svn/packages/iptables-daddr/branches/l3dsr-open-source/iptables-daddr.el5
FREEBSDDIR=${HOME}/dev/svn/dscp_rewrite/branches/l3dsr-open-source
YVIPAGENTDIR=${HOME}/dev/svn/yvip/agent/branches/l3dsr-open-source

all: ${TARBALL}

${TARBALL}: doc-up freebsd-up linux-up yvipagent-up
	( cd .build && tar zcf ../${TARBALL} l3dsr )

doc-up:
	( cd ${DOCDIR} && svn up )
	mkdir -p .build/l3dsr/docs
	cp ${DOCDIR}/README .build/l3dsr/README
	cp ${DOCDIR}/nanog51/nanog51.pdf .build/l3dsr/docs/nanog51.pdf

freebsd-up:
	( cd ${FREEBSDDIR} && svn up )
	mkdir -p .build/l3dsr/freebsd
	( cd ${FREEBSDDIR} && pax -rw -s '/.*\.svn.*//' . ${YVIPAGENTDIR}/.build/l3dsr/freebsd/. )

linux-up:
	( cd ${LINUXDIR} && svn up )
	mkdir -p .build/l3dsr/linux
	( cd ${LINUXDIR} && pax -rw -s '/.*\.svn.*//' . ${YVIPAGENTDIR}/.build/l3dsr/linux/. )

yvipagent-up:
	( cd ${YVIPAGENTDIR} && svn up )
	mkdir -p .build/l3dsr/yvipagent
	( cd ${YVIPAGENTDIR} && pax -rw -s '/.*\.svn.*//' -s '/.*\.build.*//' . ${YVIPAGENTDIR}/.build/l3dsr/yvipagent/. )

clean:
	rm -fr .build ${TARBALL}
