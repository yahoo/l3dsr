.TH DSR.CONF "5" "October 2016" "dsr.conf __VERSION__" "System Management Commands"
.SH NAME
dsr.conf \- configuration file for DSRs

.SH DESCRIPTION

The \fBdsrctl\fP command parses all files that end with \fI.conf\fP in
\fB/etc/dsr.d\fP as DSR configuration files (unless specific configuration files
are specified on the command line).  The \fI.conf\fP files are parsed
in a sorted order that is defined by the locale specified in the environment.

\fBdsrctl\fP validates the input line looking for a VIP address and optionally
a DSCP value for L3DSR VIPs.

The basic format for an L3DSR line in a \fI.conf\fP file is
.nf
	<vip>=<dscp>
.fi
The basic format for an L2DSR line in a \fI.conf\fP file is
.nf
	<vip>
.fi

This is an example L3DSR configuration.
.nf
	# VIP=DSCP
	98.139.235.245=28    # this is the best L3DSR ever
	201F::0080:1d0:f8=29 # this is a good one, too
.fi

This is an example L2DSR configuration.
.nf
	# VIP
	98.139.235.245       # this is the best L2DSR ever
	201F::0080:1d0:f8    # this is a good one, too
.fi

IPv4 VIPs may be entered in dotted decimal format (\fIe.g.\fP, 98.139.235.245) or
as a FQDN (Fully Qualified Domain Name) (\fIe.g.\fP, host.colo.domain.com).
Spaces are not allowed within the dotted decimal or FQDN VIP addresses.

IPv6 VIPs are restricted to the standard hex groups, with colons separating
the groups.  Double colons are allowed once in the address.  Upper and lower
case hex letters are supported.  Mixed IPv6/IPv4 addressing is not supported
(\fIe.g.\fP, ::ffff:10.0.0.128).  Similar to IPv4 addresses, spaces are not
allowed within the colon-separated groups of the IPv6 address.

The maximum DSCP value is 63.  The DSCP value may be specified as a decimal
(\fIe.g.\fP 33), octal (\fIe.g.\fP 041), or hex (\fIe.g.\fP 0x21) value.
\fBdsrctl\fP does not stop you from using a DSCP value of 0, but since this is
the likely default value for the DSCP in most packets, it is a poor choice.

Spaces/tabs are allowed anywhere (except within the VIP and DSCP values), but
the VIP and DSCP must reside on the same line.  Only one DSR configuration is
allowed per line.

Lines that begin with an octothorp (#) are considered comments and are
ignored.  Empty lines and lines containing only spaces and tabs are ignored.
Comments are allowed after the VIP=DSCP on the VIP lines in the \fI.conf\fP
file -- everything after the octothorp is ignored.


.SH FILES
.TP
/etc/dsr.d
This directory is the location where DSR configuration files are stored.  Only
files that end with \fI.conf\fP are considered configuration files and all
others are ignored.

.SH AUTHOR
Wayne Badger, Yahoo, Inc.
.SH "REPORTING BUGS"
Report bugs to <linux\-kernel@yahoo\-inc.com>.
.SH "SEE ALSO"
.BR dsrctl (8)
