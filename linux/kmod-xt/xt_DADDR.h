#ifndef _LINUX_NETFILTER_XT_DADDR_H
#define _LINUX_NETFILTER_XT_DADDR_H

#include <linux/netfilter.h>

struct xt_daddr_tginfo {
	union nf_inet_addr	daddr;
};

#endif /* _LINUX_NETFILTER_XT_DADDR_H */
