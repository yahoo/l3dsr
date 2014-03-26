/* This module sets the IP destination address field. */

/* (C) 2008, 2014 Yahoo! Inc.
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
#include <net/checksum.h>
#include <linux/netfilter_ipv4/ip_tables.h>
#include "ipt_DADDR.h"

MODULE_AUTHOR("Yahoo! Inc.  <linux-kernel-team@yahoo-inc.com>");
MODULE_DESCRIPTION("iptables DADDR modification module");
MODULE_LICENSE("GPL");


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
ipt_daddr_target(struct sk_buff **pskb,
		 const struct net_device *in,
		 const struct net_device *out,
		 unsigned int hooknum,
		 const void *targinfo,
		 void *userinfo)
{
	const struct ipt_daddr_target_info *daddrinfo = targinfo;
	__be32 new_daddr = daddrinfo->daddr;
	struct iphdr *iph = ip_hdr(*pskb);

	if (iph->daddr != new_daddr) {
		struct sk_buff	*skb;
		__u8		proto;

		if (!skb_ip_make_writable(pskb, (*pskb)->len))
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

		skb->nfcache |= NFC_ALTERED;
	}

	return IPT_CONTINUE;
}

static int
ipt_daddr_checkentry(const char *tablename,
		     const struct ipt_entry *e,
		     void *targinfo,
		     unsigned int targinfosize,
		     unsigned int hook_mask)
{
	if (targinfosize != IPT_ALIGN(sizeof(struct ipt_daddr_target_info))) {
		printk(KERN_WARNING "DADDR: targinfosize %u != %Zu\n",
		       targinfosize,
		       IPT_ALIGN(sizeof(struct ipt_daddr_target_info)));
		return 0;
	}

	if (strcmp(tablename, "mangle") != 0) {
		printk(KERN_WARNING "DADDR: can only be called from \"mangle\" table, not \"%s\"\n", tablename);
		return 0;
	}

	return 1;
}

static struct ipt_target ipt_daddr_reg = {
	.name		= "DADDR",
	.target		= ipt_daddr_target,
	.checkentry	= ipt_daddr_checkentry,
	.me		= THIS_MODULE,
};

static int __init ipt_daddr_init(void)
{
	return ipt_register_target(&ipt_daddr_reg);
}

static void __exit ipt_daddr_fini(void)
{
	ipt_unregister_target(&ipt_daddr_reg);
}

module_init(ipt_daddr_init);
module_exit(ipt_daddr_fini);
