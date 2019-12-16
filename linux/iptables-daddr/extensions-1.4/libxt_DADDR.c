/* Shared library add-on to iptables to add DADDR target support. */

/* Copyright (C) 2011 Yahoo! Inc.
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
#include <netinet/in.h>
#include <arpa/inet.h>
#include <xtables.h>
#include "xt_DADDR.h"


#ifndef ARRAY_SIZE
#define ARRAY_SIZE(a) (sizeof (a) / sizeof ((a)[0]))
#endif


typedef void (*parse_daddr_fn)(const char *, struct xt_daddr_tginfo *);

static struct option daddr_tg_opts[] = {
	{ "set-daddr", 1, 0, '1' },
	{ .name = NULL }
};


static void
daddr_tg_help(int is6)
{
	printf(
	"DADDR target options:\n"
	"  --set-daddr <ip%saddr>%s         "
	"Address to set for the IPv%s destination field\n",
	is6 ? "6" : "", is6 ? "" : " ", is6 ? "6" : "4"
	);
}


static void
daddr_tg4_help(void)
{
	daddr_tg_help(0);
}


static void
daddr_tg6_help(void)
{
	daddr_tg_help(1);
}


static void
parse_daddr4(const char *s, struct xt_daddr_tginfo *info)
{
	struct in_addr ip;

	if (inet_pton(AF_INET, s, &ip) <= 0)
		xtables_error(PARAMETER_PROBLEM, "Bad IPv4 address `%s'\n", s);

	info->daddr.in = ip;
}


static void
parse_daddr6(const char *s, struct xt_daddr_tginfo *info)
{
	struct in6_addr ip;

	if (inet_pton(AF_INET6, s, &ip) <= 0)
		xtables_error(PARAMETER_PROBLEM, "Bad IPv6 address `%s'\n", s);

	info->daddr.in6 = ip;
}


/* Function which parses command options; returns true if it
   ate an option */
static int
daddr_tg_parse(int c, char **argv, int invert, unsigned int *flags,
	       const void *entry, struct xt_entry_target **target,
	       parse_daddr_fn da_fn)
{
	struct xt_daddr_tginfo *daddrinfo
		= (struct xt_daddr_tginfo *)(*target)->data;

	switch (c) {
	case '1':
		if (*flags)
			xtables_error(PARAMETER_PROBLEM,
			           "DADDR target: Cant specify --set-daddr twice");
		(da_fn)(optarg, daddrinfo);
		*flags = 1;
		break;

	default:
		return 0;
	}

	return 1;
}


static int
daddr_tg4_parse(int c, char **argv, int invert, unsigned int *flags,
	        const void *entry, struct xt_entry_target **target)
{
	return daddr_tg_parse(c, argv, invert, flags, entry, target,
				parse_daddr4);
}


static int
daddr_tg6_parse(int c, char **argv, int invert, unsigned int *flags,
	        const void *entry, struct xt_entry_target **target)
{
	return daddr_tg_parse(c, argv, invert, flags, entry, target,
				parse_daddr6);
}


static void
daddr_tg_check(unsigned int flags)
{
	if (!flags)
		xtables_error(PARAMETER_PROBLEM,
		           "DADDR target: Parameter --set-daddr is required");
}


static void
print_daddr4(const struct in_addr *daddr)
{
	char		p[INET_ADDRSTRLEN];
	const char	*n2pr;

	n2pr = inet_ntop(AF_INET, daddr, p, INET_ADDRSTRLEN);

#if XTABLES_VERSION_CODE > 5
	printf("%s", n2pr ? p : "[bad addr]");
#else
	printf("%s ", n2pr ? p : "[bad addr]");
#endif
}


static void
daddr_tg4_print(const void *entry,
	        const struct xt_entry_target *target,
	        int numeric)
{
	const struct xt_daddr_tginfo *daddrinfo =
		(const struct xt_daddr_tginfo *)target->data;

#if XTABLES_VERSION_CODE > 5
	printf(" DADDR set ");
#else
	printf("DADDR set ");
#endif
	print_daddr4(&daddrinfo->daddr.in);
}


static void
print_daddr6(const struct in6_addr *daddr)
{
	char		p[INET6_ADDRSTRLEN];
	const char	*n2pr;

	n2pr = inet_ntop(AF_INET6, daddr, p, INET6_ADDRSTRLEN);

#if XTABLES_VERSION_CODE > 5
	printf("%s", n2pr ? p : "[bad addr]");
#else
	printf("%s ", n2pr ? p : "[bad addr]");
#endif
}


static void
daddr_tg6_print(const void *entry,
	        const struct xt_entry_target *target,
	        int numeric)
{
	const struct xt_daddr_tginfo *daddrinfo =
		(const struct xt_daddr_tginfo *)target->data;

#if XTABLES_VERSION_CODE > 5
	printf(" DADDR set ");
#else
	printf("DADDR set ");
#endif
	print_daddr6(&daddrinfo->daddr.in6);
}


static void
daddr_tg4_save(const void *entry, const struct xt_entry_target *target)
{
	const struct xt_daddr_tginfo *daddrinfo =
		(const struct xt_daddr_tginfo *)target->data;

#if XTABLES_VERSION_CODE > 5
	printf(" --set-daddr ");
#else
	printf("--set-daddr ");
#endif
	print_daddr4(&daddrinfo->daddr.in);
}


static void
daddr_tg6_save(const void *entry, const struct xt_entry_target *target)
{
	const struct xt_daddr_tginfo *daddrinfo =
		(const struct xt_daddr_tginfo *)target->data;

#if XTABLES_VERSION_CODE > 5
	printf(" --set-daddr ");
#else
	printf("--set-daddr ");
#endif
	print_daddr6(&daddrinfo->daddr.in6);
}


static struct xtables_target daddr_tg_reg[] = {
	{
	.name		= "DADDR",
	.version	= XTABLES_VERSION,
	.family		= NFPROTO_IPV4,
	.size		= XT_ALIGN(sizeof(struct xt_daddr_tginfo)),
	.userspacesize	= XT_ALIGN(sizeof(struct xt_daddr_tginfo)),
	.help		= &daddr_tg4_help,
	.parse		= &daddr_tg4_parse,
	.final_check	= &daddr_tg_check,
	.print		= &daddr_tg4_print,
	.save		= &daddr_tg4_save,
	.extra_opts	= daddr_tg_opts
	},
	{
	.name		= "DADDR",
	.version	= XTABLES_VERSION,
	.family		= NFPROTO_IPV6,
	.size		= XT_ALIGN(sizeof(struct xt_daddr_tginfo)),
	.userspacesize	= XT_ALIGN(sizeof(struct xt_daddr_tginfo)),
	.help		= &daddr_tg6_help,
	.parse		= &daddr_tg6_parse,
	.final_check	= &daddr_tg_check,
	.print		= &daddr_tg6_print,
	.save		= &daddr_tg6_save,
	.extra_opts	= daddr_tg_opts
	},
};

void _init(void)
{
	xtables_register_targets(daddr_tg_reg, ARRAY_SIZE(daddr_tg_reg));
}
