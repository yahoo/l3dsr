/* Shared library add-on to iptables to add DADDR target support. */

/* (C) 2008, 2009, 2011 Yahoo! Inc.
 *    Written by: Quentin Barnes <qbarnes@yahoo-inc.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <getopt.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/in.h>
#include <iptables.h>
#include "xt_DADDR.h"

/* Function which prints out usage message. */
static void
help(void)
{
	printf(
	"DADDR target options:\n"
	"  --set-daddr <ipaddr>          "
	"Address to set for the IPv4 destination field\n"
	);
}

static struct option opts[] = {
	{ "set-daddr", 1, 0, '1' },
	{ .name = NULL }
};

/* Initialize the target. */
static void
init(struct ipt_entry_target *t, unsigned int *nfcache)
{
}

static void
parse_daddr(const char *s, struct xt_daddr_tginfo *info)
{
	struct in_addr ip;

	if (inet_pton(AF_INET, s, &ip) <= 0)
		exit_error(PARAMETER_PROBLEM, "Bad IPv4 address `%s'\n", s);

	info->u.daddr = ip;
}

/* Function which parses command options; returns true if it
   ate an option */
static int
parse(int c, char **argv, int invert, unsigned int *flags,
      const struct ipt_entry *entry,
      struct ipt_entry_target **target)
{
	struct xt_daddr_tginfo *daddrinfo
		= (struct xt_daddr_tginfo *)(*target)->data;

	switch (c) {
	case '1':
		if (*flags)
			exit_error(PARAMETER_PROBLEM,
			           "DADDR target: Cant specify --set-daddr twice");
		parse_daddr(optarg, daddrinfo);
		*flags = 1;
		break;

	default:
		return 0;
	}

	return 1;
}

static void
final_check(unsigned int flags)
{
	if (!flags)
		exit_error(PARAMETER_PROBLEM,
		           "DADDR target: Parameter --set-daddr is required");
}

static void
print_daddr(const struct in_addr *daddr)
{
	char		p[INET_ADDRSTRLEN];
	const char	*n2pr;

	n2pr = inet_ntop(AF_INET, daddr, p, INET_ADDRSTRLEN);

	printf("%s ", n2pr ? p : "[bad addr]");
}

/* Prints out the targinfo. */
static void
print(const struct ipt_ip *ip,
      const struct ipt_entry_target *target,
      int numeric)
{
	const struct xt_daddr_tginfo *daddrinfo =
		(const struct xt_daddr_tginfo *)target->data;

	printf("DADDR set ");
	print_daddr(&daddrinfo->u.daddr);
}

/* Saves the union ipt_targinfo in parsable form to stdout. */
static void
save(const struct ipt_ip *ip, const struct ipt_entry_target *target)
{
	const struct xt_daddr_tginfo *daddrinfo =
		(const struct xt_daddr_tginfo *)target->data;

	printf("--set-daddr ");
	print_daddr(&daddrinfo->u.daddr);
}

static struct iptables_target daddr = {
	.next		= NULL,
	.name		= "DADDR",
	.version	= IPTABLES_VERSION,
	.size		= IPT_ALIGN(sizeof(struct xt_daddr_tginfo)),
	.userspacesize	= IPT_ALIGN(sizeof(struct xt_daddr_tginfo)),
	.help		= &help,
	.init	 	= &init,
	.parse		= &parse,
	.final_check	= &final_check,
	.print		= &print,
	.save		= &save,
	.extra_opts	= opts
};

void constructor(void) __attribute__ ((constructor));

void constructor(void)
{
	register_target(&daddr);
}
