/* This module is used for setting the destination IP field of a packet. */

/*
 * Copyright (c) 2011 Yahoo! Inc. All rights reserved.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License (GPL), version 2 only.
 * This software s distributed WITHOUT ANY WARRANTY, whether express or
 * implied. See the GNU GPL for more details:
 * (http://www.gnu.org/licenses/gpl.html)
 *
 * Originally written by Quentin Barnes <qbarnes@yahoo-inc.com
 *
 */

#include <linux/module.h>
#include <linux/skbuff.h>
#include <linux/ip.h>
#include <net/checksum.h>

#include <linux/netfilter_ipv4/ip_tables.h>
#include "ipt_DADDR.h"

MODULE_LICENSE("GPLv2");
MODULE_AUTHOR("Yahoo! Inc.  <linux-kernel@yahoo-inc.com>");
MODULE_DESCRIPTION("iptables DADDR mangling module");

static unsigned int
target(struct sk_buff **pskb,
       const struct net_device *in,
       const struct net_device *out,
       unsigned int hooknum,
       const struct xt_target *target,
       const void *targinfo,
       void *userinfo)
{
	const struct ipt_daddr_target_info *daddrinfo = targinfo;

	if (((*pskb)->nh.iph->daddr) != daddrinfo->daddr) {
		u_int32_t diffs[2];

		if (!skb_make_writable(pskb, sizeof(struct iphdr)))
			return NF_DROP;

		diffs[0] = ~htonl((*pskb)->nh.iph->daddr);
		(*pskb)->nh.iph->daddr = daddrinfo->daddr;
		diffs[1] = htonl((*pskb)->nh.iph->daddr);
		(*pskb)->nh.iph->check
			= csum_fold(csum_partial((char *)diffs,
						 sizeof(diffs),
						 (*pskb)->nh.iph->check
						 ^0xFFFF));
	}
	return IPT_CONTINUE;
}

static struct ipt_target ipt_daddr_reg = {
	.name		= "DADDR",
	.target		= target,
	.targetsize	= sizeof(struct ipt_daddr_target_info),
	.table		= "mangle",
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
