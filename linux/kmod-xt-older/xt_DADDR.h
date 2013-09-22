#ifndef _LINUX_NETFILTER_XT_DADDR_H
#define _LINUX_NETFILTER_XT_DADDR_H

#ifdef __KERNEL__
#include <linux/in.h>
#else
#include <netinet/in.h>
#endif

struct xt_daddr_tginfo {
	union {
		struct in_addr	daddr;
		struct in6_addr	daddr6;
	} u;
};

#endif /* _LINUX_NETFILTER_XT_DADDR_H */
