/* This module is used for setting the destination IP field of a packet. */

/* (C) 2008 Yahoo! Inc.
 *    Written by: Quentin Barnes <qbarnes@yahoo-inc.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/module.h>
#include <linux/skbuff.h>
#include <linux/ip.h>
#include <net/checksum.h>

#include <linux/netfilter_ipv4/ip_tables.h>
#include "ipt_DADDR.h"

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Yahoo! Inc.  <linux-kernel@yahoo-inc.com>");
MODULE_DESCRIPTION("iptables DADDR mangling module");

static unsigned int
target(struct sk_buff **pskb,
       const struct net_device *in,
       const struct net_device *out,
       unsigned int hooknum,
       const void *targinfo,
       void *userinfo)
{
	const struct ipt_daddr_target_info *daddrinfo = targinfo;

	if (((*pskb)->nh.iph->daddr) != daddrinfo->daddr) {
		u_int32_t diffs[2];

		if (!skb_ip_make_writable(pskb, sizeof(struct iphdr)))
			return NF_DROP;

		diffs[0] = ~htonl((*pskb)->nh.iph->daddr);
		(*pskb)->nh.iph->daddr = daddrinfo->daddr;
		diffs[1] = htonl((*pskb)->nh.iph->daddr);
		(*pskb)->nh.iph->check
			= csum_fold(csum_partial((char *)diffs,
						 sizeof(diffs),
						 (*pskb)->nh.iph->check
						 ^0xFFFF));
		(*pskb)->nfcache |= NFC_ALTERED;
	}
	return IPT_CONTINUE;
}

static int
checkentry(const char *tablename,
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
	.target		= target,
	.checkentry	= checkentry,
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
