/* This module sets the IP destination address field. */

/* Copyright (C) 2011, 2012, 2014 Yahoo! Inc.
 *    Written by: Quentin Barnes <qbarnes@yahoo-inc.com>
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

MODULE_AUTHOR("Yahoo! Inc.  <linux-kernel-team@yahoo-inc.com>");
MODULE_DESCRIPTION("Xtables: destination address modification");
MODULE_LICENSE("GPL");
MODULE_ALIAS("ipt_DADDR");
#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
MODULE_ALIAS("ip6t_DADDR");
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(2,6,35)
#define xt_action_param xt_target_param
#endif

static unsigned int
daddr_tg4(struct sk_buff *skb, const struct xt_action_param *par)
{
	const struct xt_daddr_tginfo *daddrinfo = par->targinfo;
	__be32 new_daddr = daddrinfo->daddr.in.s_addr;
	struct iphdr *iph = ip_hdr(skb);

	if (iph->daddr != new_daddr) {
		__u8	proto;

		if (!skb_make_writable(skb, skb->len))
			return NF_DROP;

		iph = ip_hdr(skb);
		csum_replace4(&iph->check, iph->daddr, new_daddr);

		proto = iph->protocol;

		if ((proto == IPPROTO_TCP) || (proto == IPPROTO_UDP)) {
			int	hdroff = (int)ip_hdrlen(skb);
			int	len = skb->len - hdroff;
			__sum16	*checkp;

			if (proto == IPPROTO_TCP) {
				struct tcphdr *tcph;

				if (len < (int)sizeof(struct tcphdr))
					return NF_DROP;

				tcph = (struct tcphdr *)
					(skb_network_header(skb) + hdroff);
				checkp = &tcph->check;
			} else {
				struct udphdr *udph;

				if (len < (int)sizeof(struct udphdr))
					return NF_DROP;

				udph = (struct udphdr *)
					(skb_network_header(skb) + hdroff);
				checkp = &udph->check;
			}

			csum_replace4(checkp, iph->daddr, new_daddr);
		}

		iph->daddr = new_daddr;
	}

	return XT_CONTINUE;
}


#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
static unsigned int
daddr_tg6(struct sk_buff *skb, const struct xt_action_param *par)
{
	const struct xt_daddr_tginfo *daddrinfo = par->targinfo;
	const struct in6_addr *new_daddr6 = &daddrinfo->daddr.in6;
	struct ipv6hdr *ip6h = ipv6_hdr(skb);

	if (!ipv6_addr_equal(&ip6h->daddr, new_daddr6)) {
		__u8	proto;
		int	hdroff;

		if (!skb_make_writable(skb, skb->len))
			return NF_DROP;

		ip6h = ipv6_hdr(skb);

		proto = ip6h->nexthdr;

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

		if ((proto == IPPROTO_TCP) || (proto == IPPROTO_UDP)) {
			int	len = skb->len - hdroff;
			__u16	*checkp;
			int	i;

			if (proto == IPPROTO_TCP) {
				struct tcphdr	*tcph;

				if (len < (int)sizeof(struct tcphdr))
					return NF_DROP;

				tcph = (struct tcphdr *)
					(skb_network_header(skb) + hdroff);
				checkp = &tcph->check;
			} else {
				struct udphdr	*udph;

				if (len < (int)sizeof(struct udphdr))
					return NF_DROP;

				udph = (struct udphdr *)
					(skb_network_header(skb) + hdroff);
				checkp = &udph->check;
			}

			for (i = 0; i < ARRAY_SIZE(new_daddr6->s6_addr32); i++)
				csum_replace4(checkp,
					      ip6h->daddr.s6_addr32[i],
					      new_daddr6->s6_addr32[i]);
		}

		ip6h->daddr = *new_daddr6;
	}

	return XT_CONTINUE;
}
#endif


static struct xt_target daddr_tg_reg[] __read_mostly = {
	{
		.name		= "DADDR",
		.family		= NFPROTO_IPV4,
		.table		= "mangle",
		.target		= daddr_tg4,
		.targetsize	= sizeof(struct xt_daddr_tginfo),
		.me		= THIS_MODULE,
	},
#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
	{
		.name		= "DADDR",
		.family		= NFPROTO_IPV6,
		.table		= "mangle",
		.target		= daddr_tg6,
		.targetsize	= sizeof(struct xt_daddr_tginfo),
		.me		= THIS_MODULE,
	},
#endif
};

static int __init daddr_tg_init(void)
{
	return xt_register_targets(daddr_tg_reg, ARRAY_SIZE(daddr_tg_reg));
}

static void __exit daddr_tg_exit(void)
{
	xt_unregister_targets(daddr_tg_reg, ARRAY_SIZE(daddr_tg_reg));
}

module_init(daddr_tg_init);
module_exit(daddr_tg_exit);
