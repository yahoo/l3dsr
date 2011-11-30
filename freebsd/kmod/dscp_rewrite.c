/*
 * Copyright (c) 2008,2009,2010,2011  Yahoo! Inc.  All rights reserved.
 *
 * Redistribution and use of this software in source and binary forms,
 * with or without modification, are permitted provided that the following
 * conditions are met:
 *
 * * Redistributions of source code must retain the above
 *   copyright notice, this list of conditions and the
 *   following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above
 *   copyright notice, this list of conditions and the
 *   following disclaimer in the documentation and/or other
 *   materials provided with the distribution.
 *
 * * Neither the name of Yahoo! Inc. nor the names of its
 *   contributors may be used to endorse or promote products
 *   derived from this software without specific prior
 *   written permission of Yahoo! Inc.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include <sys/cdefs.h>
__RCSID("$Id: dscp_rewrite.c 22 2011-11-30 21:27:24Z jans $");

#include <sys/param.h>
#include <sys/kernel.h>
#include <sys/mbuf.h>
#include <sys/module.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#include <net/if.h>
#include <net/pfil.h>

#include <netinet/in_systm.h>
#include <netinet/in.h>
#include <netinet/in_var.h>
#include <netinet/ip.h>

SYSCTL_NODE(_net_inet_ip, OID_AUTO, dscp_rewrite, CTLFLAG_RD, NULL,
    "DSCP rewrite source IP addresses");

static int dscp_rewrite_enabled = 1;
SYSCTL_INT(_net_inet_ip_dscp_rewrite, OID_AUTO, enabled, CTLFLAG_RW,
    &dscp_rewrite_enabled, 0, "DSCP rewrite enabled");

static struct in_addr rewrite_addresses[64];

static int
dscp_rewrite_inet_aton(const char *cp, struct in_addr *addr)
{
	u_long octets[4];
	const char *c;
	char *end;
	int i;

	i = 0;
	c = cp;
	for (;;) {
		octets[i] = strtoul(c, &end, 10);
		if (c == end)
			/* Unable to parse an octet. */
			return (EINVAL);

		/* Parsed the whole string? */
		if (*end == '\0')
			break;

		/* Next octet? */
		if (*end == '.') {
			if (i == 3)
				/* Too many octets. */
				return (EINVAL);
			c = end + 1;
			i++;
		} else
			/* Invalid character. */
			return (EINVAL);
	}

	if (i != 3)
		/* Not enough octets. */
		return (EINVAL);

	/* Range-check all the octets. */
	for (i = 0; i < 4; i++)
		if (octets[i] > 0xff)
			return (EINVAL);

	addr->s_addr = htonl(octets[0] << 24 | octets[1] << 16 |
	    octets[2] << 8 | octets[3]);
	return (0);
}

static int
rewrite_sysctl_handler(SYSCTL_HANDLER_ARGS)
{
	char buf[24];
	int error;

	inet_ntoa_r(rewrite_addresses[arg2], buf);
	error = sysctl_handle_string(oidp, buf, sizeof(buf), req);
	if (error)
		return (error);
	error = dscp_rewrite_inet_aton(buf, &rewrite_addresses[arg2]);
	return (error);
}

#define	DSCP_SYSCTL(index)						\
	SYSCTL_PROC(_net_inet_ip_dscp_rewrite, (index), index,		\
	    CTLTYPE_STRING | CTLFLAG_RW, NULL, (index),			\
	    rewrite_sysctl_handler, "A", "DSCP " #index " source IP")

DSCP_SYSCTL(1);
DSCP_SYSCTL(2);
DSCP_SYSCTL(3);
DSCP_SYSCTL(4);
DSCP_SYSCTL(5);
DSCP_SYSCTL(6);
DSCP_SYSCTL(7);
DSCP_SYSCTL(8);
DSCP_SYSCTL(9);
DSCP_SYSCTL(10);
DSCP_SYSCTL(11);
DSCP_SYSCTL(12);
DSCP_SYSCTL(13);
DSCP_SYSCTL(14);
DSCP_SYSCTL(15);
DSCP_SYSCTL(16);
DSCP_SYSCTL(17);
DSCP_SYSCTL(18);
DSCP_SYSCTL(19);
DSCP_SYSCTL(20);
DSCP_SYSCTL(21);
DSCP_SYSCTL(22);
DSCP_SYSCTL(23);
DSCP_SYSCTL(24);
DSCP_SYSCTL(25);
DSCP_SYSCTL(26);
DSCP_SYSCTL(27);
DSCP_SYSCTL(28);
DSCP_SYSCTL(29);
DSCP_SYSCTL(30);
DSCP_SYSCTL(31);
DSCP_SYSCTL(32);
DSCP_SYSCTL(33);
DSCP_SYSCTL(34);
DSCP_SYSCTL(35);
DSCP_SYSCTL(36);
DSCP_SYSCTL(37);
DSCP_SYSCTL(38);
DSCP_SYSCTL(39);
DSCP_SYSCTL(40);
DSCP_SYSCTL(41);
DSCP_SYSCTL(42);
DSCP_SYSCTL(43);
DSCP_SYSCTL(44);
DSCP_SYSCTL(45);
DSCP_SYSCTL(46);
DSCP_SYSCTL(47);
DSCP_SYSCTL(48);
DSCP_SYSCTL(49);
DSCP_SYSCTL(50);
DSCP_SYSCTL(51);
DSCP_SYSCTL(52);
DSCP_SYSCTL(53);
DSCP_SYSCTL(54);
DSCP_SYSCTL(55);
DSCP_SYSCTL(56);
DSCP_SYSCTL(57);
DSCP_SYSCTL(58);
DSCP_SYSCTL(59);
DSCP_SYSCTL(60);
DSCP_SYSCTL(61);
DSCP_SYSCTL(62);
DSCP_SYSCTL(63);

static int
dscp_rewrite_in(void *arg, struct mbuf **m0, struct ifnet *ifp, int dir,
    struct inpcb *inp)
{
	struct mbuf *m;
	struct ip *ip;
	int i;

	KASSERT(dir == PFIL_IN, ("dscp_rewrite_in wrong direction!"));

	if (!dscp_rewrite_enabled)
		return (0);

	m = *m0;

	/*
	 * Find the IP header.  Note that we assume that the full
	 * header is in the first mbuf since ip_input() would have
	 * already done an m_pullup() to that effect.
	 */
	ip = mtod(m, struct ip *);

	/* Extract DSCP field to get index into table;
	 * DSCP is the first 6 bits of the 8 bit TOS field. */
	i = ip->ip_tos >> 2;

	/* DSCP 0 is always passed through untouched. */
	if (i == 0)
		return (0);

	/* If the destination IP for this index is 0, then bail. */
	if (rewrite_addresses[i].s_addr == 0)
		return (0);

	ip->ip_dst = rewrite_addresses[i];

	/* XXX: Clear DSCP? */

	/*
	 * This intentionally does not update the checksum.
	 * ip_input() has already checked the checksum by the time the
	 * pfil hooks are run, and we are not sending this packet back
	 * down the stack, but up.
	 */
	return (0);
}

static int
dscp_rewrite_modevent(module_t mod, int type, void *arg)
{
	int i;
	struct pfil_head *pfh_inet;

	switch (type) {
	case MOD_LOAD:
		pfh_inet = pfil_head_get(PFIL_TYPE_AF, AF_INET);
		if (pfh_inet == NULL)
			return (ENOENT);
		pfil_add_hook(dscp_rewrite_in, NULL, PFIL_IN | PFIL_WAITOK,
		    pfh_inet);
		break;
	case MOD_UNLOAD:
		pfh_inet = pfil_head_get(PFIL_TYPE_AF, AF_INET);
		if (pfh_inet == NULL)
			return (ENOENT);
		for (i=0;i<64;i++) {
			if (rewrite_addresses[i].s_addr != 0)
				return (EBUSY);
		}
		pfil_remove_hook(dscp_rewrite_in, NULL, PFIL_IN | PFIL_WAITOK,
		    pfh_inet);
		break;
	case MOD_QUIESCE:
		break;
	default:
		return (EOPNOTSUPP);
	}
	return (0);
}

static moduledata_t dscp_rewrite_mod = {
	"dscp_rewrite",
	dscp_rewrite_modevent,
	0,
};

DECLARE_MODULE(dscp_rewrite, dscp_rewrite_mod, SI_SUB_PROTO_IFATTACHDOMAIN,
    SI_ORDER_ANY);
MODULE_VERSION(dscp_rewrite, 1);
