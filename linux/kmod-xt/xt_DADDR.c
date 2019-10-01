/* This module sets the IP destination address field. */

/* Copyright (C) 2011, 2012, 2014 Yahoo! Inc.
 * Copyright (C) 2019 Verizon Media, Inc.
 *    Written by: Quentin Barnes <qbarnes@verizonmedia.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/module.h>
#include <linux/skbuff.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/tcp.h>
#include <linux/version.h>
#include <net/ip.h>
#include <net/ipv6.h>
#include <net/checksum.h>

#include <linux/netfilter/x_tables.h>
#include "xt_DADDR.h"

MODULE_AUTHOR("Oath Inc.  <linux-kernel-team@verizonmedia.com>");
MODULE_DESCRIPTION("Xtables: destination address modification");
MODULE_LICENSE("GPL");
MODULE_ALIAS("ipt_DADDR");
#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
MODULE_ALIAS("ip6t_DADDR");
#endif

static char *table = "raw";
module_param(table, charp, S_IRUGO);
MODULE_PARM_DESC(table, "type of table (default: raw)");

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,35)
#define xt_action_param xt_target_param
#endif

static unsigned int
daddr_tg4(struct sk_buff *skb, const struct xt_action_param *par)
{
	const struct xt_daddr_tginfo *daddrinfo = par->targinfo;
	__be32 new_daddr = daddrinfo->daddr.in.s_addr;
	__be32 old_daddr;
	struct iphdr *iph;
	int transport_len;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5,3,0)
	if (skb_ensure_writable(skb, skb->len))
#else
	if (!skb_make_writable(skb, skb->len))
#endif
		return NF_DROP;

	iph        = ip_hdr(skb);
	old_daddr  = iph->daddr;
	iph->daddr = new_daddr;
	csum_replace4(&iph->check, old_daddr, new_daddr);

	transport_len = skb->len - skb_transport_offset(skb);

	switch (iph->protocol) {
	case IPPROTO_UDP: {
		struct udphdr	*udph;
		__sum16		*checkp;

		if (unlikely(transport_len < (int)sizeof(struct udphdr)))
			return NF_DROP;

		udph = udp_hdr(skb);
		checkp = &udph->check;

		if (*checkp || skb->ip_summed == CHECKSUM_PARTIAL) {
			inet_proto_csum_replace4(checkp, skb,
						 old_daddr, new_daddr, 1);

			if (*checkp == 0)
				*checkp = CSUM_MANGLED_0;
		}
		break;
	}

	case IPPROTO_TCP:
		if (unlikely(transport_len < (int)sizeof(struct tcphdr)))
			return NF_DROP;

		inet_proto_csum_replace4(&tcp_hdr(skb)->check, skb,
					 old_daddr, new_daddr, 1);
		break;
	}

	return XT_CONTINUE;
}


#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
#if !((LINUX_VERSION_CODE >= KERNEL_VERSION(3,7,0)) || \
      (defined(RHEL_RELEASE_CODE) && defined(RHEL_RELEASE_VERSION) && \
       (RHEL_RELEASE_CODE >= RHEL_RELEASE_VERSION(6,5))))
static
void inet_proto_csum_replace16(__sum16 *sum, struct sk_buff *skb,
			       const __be32 *from, const __be32 *to,
			       bool pseudohdr)
{
	__be32 diff[] = {
		~from[0], ~from[1], ~from[2], ~from[3],
		to[0], to[1], to[2], to[3],
	};
	if (skb->ip_summed != CHECKSUM_PARTIAL) {
		*sum = csum_fold(csum_partial(diff, sizeof(diff),
				 ~csum_unfold(*sum)));
		if (skb->ip_summed == CHECKSUM_COMPLETE && pseudohdr)
			skb->csum = ~csum_partial(diff, sizeof(diff),
						  ~skb->csum);
	} else if (pseudohdr)
		*sum = ~csum_fold(csum_partial(diff, sizeof(diff),
				  csum_unfold(*sum)));
}
#endif

static unsigned int
daddr_tg6(struct sk_buff *skb, const struct xt_action_param *par)
{
	const struct xt_daddr_tginfo *daddrinfo = par->targinfo;
	const struct in6_addr *new_daddr6 = &daddrinfo->daddr.in6;
	struct in6_addr old_daddr6;
	struct ipv6hdr *ip6h;
	int transport_len;
	__u8	proto;
	int	hdroff;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5,3,0)
	if (skb_ensure_writable(skb, skb->len))
#else
	if (!skb_make_writable(skb, skb->len))
#endif
		return NF_DROP;

	ip6h        = ipv6_hdr(skb);
	old_daddr6  = ip6h->daddr;
	ip6h->daddr = *new_daddr6;
	proto       = ip6h->nexthdr;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(3,3,0)
	{
	__be16	frag_off;
	hdroff = ipv6_skip_exthdr(skb, (u8*)(ip6h+1) - skb->data,
				  &proto, &frag_off);
	}
#else
	hdroff = ipv6_skip_exthdr(skb, (u8*)(ip6h+1) - skb->data,
				  &proto);
#endif
	if (unlikely(hdroff < 0))
		return NF_DROP;

	if (unlikely(hdroff == 0))
		return XT_CONTINUE;

	transport_len = skb->len - skb_transport_offset(skb);

	switch (proto) {
	case IPPROTO_ICMPV6:
		if (unlikely(transport_len < (int)sizeof(struct icmp6hdr)))
			return NF_DROP;

		inet_proto_csum_replace16(&icmp6_hdr(skb)->icmp6_cksum, skb,
					  old_daddr6.s6_addr32,
					  new_daddr6->s6_addr32, 1);
		break;

	case IPPROTO_UDP: {
		struct udphdr	*udph;
		__u16		*checkp;

		if (unlikely(transport_len < (int)sizeof(struct udphdr)))
			return NF_DROP;

		udph = udp_hdr(skb);
		checkp = &udph->check;

		if (*checkp || skb->ip_summed == CHECKSUM_PARTIAL) {
			inet_proto_csum_replace16(checkp, skb,
						  old_daddr6.s6_addr32,
						  new_daddr6->s6_addr32, 1);

			if (*checkp == 0)
				*checkp = CSUM_MANGLED_0;
		}
		break;
	}

	case IPPROTO_TCP:
		if (unlikely(transport_len < (int)sizeof(struct tcphdr)))
			return NF_DROP;

		inet_proto_csum_replace16(&tcp_hdr(skb)->check, skb,
					  old_daddr6.s6_addr32,
					  new_daddr6->s6_addr32, 1);
		break;
	}

	return XT_CONTINUE;
}
#endif


static struct xt_target daddr_tg_reg[] __read_mostly = {
	{
		.name		= "DADDR",
		.family		= NFPROTO_IPV4,
		.table		= NULL,
		.target		= daddr_tg4,
		.targetsize	= sizeof(struct xt_daddr_tginfo),
		.me		= THIS_MODULE,
	},
#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
	{
		.name		= "DADDR",
		.family		= NFPROTO_IPV6,
		.table		= NULL,
		.target		= daddr_tg6,
		.targetsize	= sizeof(struct xt_daddr_tginfo),
		.me		= THIS_MODULE,
	},
#endif
};

static int __init daddr_tg_init(void)
{
	daddr_tg_reg[0].table = table;
#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
	daddr_tg_reg[1].table = table;
#endif
	return xt_register_targets(daddr_tg_reg, ARRAY_SIZE(daddr_tg_reg));
}

static void __exit daddr_tg_exit(void)
{
	xt_unregister_targets(daddr_tg_reg, ARRAY_SIZE(daddr_tg_reg));
}

module_init(daddr_tg_init);
module_exit(daddr_tg_exit);
