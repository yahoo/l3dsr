/* Shared library add-on to iptables to add DADDR target support. */

/* (C) 2008 Yahoo! Inc.
 *    Written by: Quentin Barnes <qbarnes@yahoo-inc.com>
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <getopt.h>
#include <limits.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if.h>
#include <linux/netfilter_ipv4/ip_tables.h>

#include <iptables.h>
#include "ipt_DADDR.h"

/* Function which prints out usage message. */
static void
help(void)
{
	printf(
	"DADDR target v%s options:\n"
	"  --set-daddr <ipaddr>\n"
	"                               Address to set for destination.\n",
	IPTABLES_VERSION);
}

static struct option opts[] = {
	{ "set-daddr", 1, 0, '1' },
	{ 0 }
};

/* Initialize the target. */
static void
init(struct ipt_entry_target *t, unsigned int *nfcache)
{
}

static void
parse_daddr(const unsigned char *s, struct ipt_daddr_target_info *info)
{
	struct in_addr *ip;

	/* dotted_to_addr() is not multi-thread safe, but no need to free. */
	ip = dotted_to_addr(s);
	if (!ip)
		exit_error(PARAMETER_PROBLEM, "Bad IP address `%s'\n", s);

	info->daddr = ip->s_addr;
}

/* Function which parses command options; returns true if it
   ate an option */
static int
parse(int c, char **argv, int invert, unsigned int *flags,
      const struct ipt_entry *entry,
      struct ipt_entry_target **target)
{
	struct ipt_daddr_target_info *daddrinfo
		= (struct ipt_daddr_target_info *)(*target)->data;

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
print_daddr(u_int32_t daddr)
{
	int i;
	unsigned char *p = (unsigned char *)&daddr;

	for (i = 0 ; i < sizeof(daddr) ; ++i)
		printf("%d%s", p[i], (i<3)?".":" ");
}

/* Prints out the targinfo. */
static void
print(const struct ipt_ip *ip,
      const struct ipt_entry_target *target,
      int numeric)
{
	const struct ipt_daddr_target_info *daddrinfo =
		(const struct ipt_daddr_target_info *)target->data;
	printf("DADDR set ");
	print_daddr(daddrinfo->daddr);
}

/* Saves the union ipt_targinfo in parsable form to stdout. */
static void
save(const struct ipt_ip *ip, const struct ipt_entry_target *target)
{
	const struct ipt_daddr_target_info *daddrinfo =
		(const struct ipt_daddr_target_info *)target->data;

	printf("--set-daddr ");
	print_daddr(daddrinfo->daddr);
}

static
struct iptables_target daddr = {
	NULL,
	"DADDR",
	IPTABLES_VERSION,
	IPT_ALIGN(sizeof(struct ipt_daddr_target_info)),
	IPT_ALIGN(sizeof(struct ipt_daddr_target_info)),
	&help,
	&init,
	&parse,
	&final_check,
	&print,
	&save,
	opts
};

void constructor(void) __attribute__ ((constructor));

void constructor(void)
{
	register_target(&daddr);
}
