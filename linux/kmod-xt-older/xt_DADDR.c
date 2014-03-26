/* This module sets the IP destination address field. */

/* (C) 2008, 2009, 2010, 2011, 2012, 2014 Yahoo! Inc.
 *    Written by: Quentin Barnes <qbarnes@yahoo-inc.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/module.h>
#include <linux/skbuff.h>
#include <linux/ip.h>
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


#define ip_hdr(skb) ((skb)->nh.iph)
#define ip_hdrlen(skb) (ip_hdr(skb)->ihl * 4)
#define network_header nh.raw
#define skb_network_header(skb) ((skb)->network_header)


/* Both csum functions copied back from a later version of <net/checksum.h> */

static inline u32
daddr_csum_unfold(u16 n)
{
	return n;
}

static inline void
daddr_csum_replace4(u16 *sum, u32 from, u32 to)
{
	u32 diff[] = { ~from, to };

	*sum = csum_fold(csum_partial((unsigned char *)diff, sizeof(diff),
				      ~daddr_csum_unfold(*sum)));
}


static unsigned int
daddr_tg4(struct sk_buff **pskb,
	  const struct net_device *in,
	  const struct net_device *out,
	  unsigned int hooknum,
	  const struct xt_target *target,
	  const void *targinfo,
	  void *userinfo)
{
	const struct xt_daddr_tginfo *daddrinfo = targinfo;
	__be32 new_daddr = daddrinfo->u.daddr.s_addr;
	struct iphdr *iph = ip_hdr(*pskb);

	if (iph->daddr != new_daddr) {
		struct sk_buff	*skb;
		__u8		proto;

		if (!skb_make_writable(pskb, (*pskb)->len))
			return NF_DROP;

		skb = *pskb;
		iph = ip_hdr(skb);
		daddr_csum_replace4(&iph->check, iph->daddr, new_daddr);

		proto = iph->protocol;

		if ((proto == IPPROTO_TCP) || (proto == IPPROTO_UDP)) {
			int	hdroff = (int)ip_hdrlen(skb);
			int	len = skb->len - hdroff;
			__u16	*checkp;

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

			daddr_csum_replace4(checkp, iph->daddr, new_daddr);
		}

		iph->daddr = new_daddr;
	}

	return XT_CONTINUE;
}


#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
static unsigned int
daddr_tg6(struct sk_buff **pskb,
	  const struct net_device *in,
	  const struct net_device *out,
	  unsigned int hooknum,
	  const struct xt_target *target,
	  const void *targinfo,
	  void *userinfo)
{
	const struct xt_daddr_tginfo *daddrinfo = targinfo;
	const struct in6_addr *new_daddr6 = &daddrinfo->u.daddr6;
	struct ipv6hdr *ip6h = (*pskb)->nh.ipv6h;

	if (!ipv6_addr_equal(&ip6h->daddr, new_daddr6)) {
		struct sk_buff	*skb;
		__u8		proto;
		int		hdroff;

		if (!skb_make_writable(pskb, (*pskb)->len))
			return NF_DROP;

		skb = *pskb;
		ip6h = skb->nh.ipv6h;

		proto = ip6h->nexthdr;
		hdroff = ipv6_skip_exthdr(skb, (u8*)(ip6h+1) - skb->data,
					  &proto);

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
				daddr_csum_replace4(checkp,
						    ip6h->daddr.s6_addr32[i],
						    new_daddr6->s6_addr32[i]);
		}

		ip6h->daddr = *new_daddr6;
	}

	return XT_CONTINUE;
}
#endif


static struct xt_target daddr_tg4_reg __read_mostly = {
	.name		= "DADDR",
	.family         = AF_INET,
	.table		= "mangle",
	.target		= daddr_tg4,
	.targetsize	= sizeof(struct xt_daddr_tginfo),
	.me		= THIS_MODULE,
};

#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
static struct xt_target daddr_tg6_reg __read_mostly = {
	.name		= "DADDR",
	.family         = AF_INET6,
	.table		= "mangle",
	.target		= daddr_tg6,
	.targetsize	= sizeof(struct xt_daddr_tginfo),
	.me		= THIS_MODULE,
};
#endif

static int __init daddr_tg_init(void)
{
	int ret;

	ret = xt_register_target(&daddr_tg4_reg);

#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
	if (ret == 0) {
		ret = xt_register_target(&daddr_tg6_reg);
		if (ret != 0)
			xt_unregister_target(&daddr_tg4_reg);
	}
#endif

	return ret;
}

static void __exit daddr_tg_exit(void)
{
#if defined(CONFIG_IP6_NF_IPTABLES) || defined(CONFIG_IP6_NF_IPTABLES_MODULE)
	xt_unregister_target(&daddr_tg6_reg);
#endif
	xt_unregister_target(&daddr_tg4_reg);
}

module_init(daddr_tg_init);
module_exit(daddr_tg_exit);
