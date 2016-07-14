.TH DSRCTL "8" "July 2016" "dsrctl __VERSION__" "System Management Commands"
.SH NAME
dsrctl \- control L3DSR/L2DSR configurations
.SH SYNOPSIS
.B dsrctl
.RB [ \-ahnvx ]
.RB [ \-d
.IR dir ]
.RB [ \-f
.IR file ]
.B action
.br
.SH DESCRIPTION
.PP
The \fBdsrctl\fP command controls both L3DSR and L2DSR installations based
on configurations found in /etc/dsr.d.
.PP
L3DSR typically involves a load balancer (LB) or VIP that receives packets from the
client.  The LB sets the DSCP field in the TCP packet that corresponds to the
LB and changes the destination IP address in the packet to the real server
(real).  When the real receives the packet, an iptables rule matches the DSCP
and changes the destination IP address back to the LB and then processes the
packet normally.  Any response to the packet is sent to the client directly
without going through the LB.
.PP
L2DSR differs from L3DSR by not utilizing the DSCP field.  Instead, the iptables
rule matches on the destination IP address only and rewrites it before
processing it.
.PP
The \fBdsrctl\fP command configures L3DSR by initializing loopback aliases
and iptables entries that control how packets are handled on the machine.
You can use the \fBdsrctl\fP \fIstatus\fP command to see the current state
of the L3DSR/L2DSR configurations.
.PP
L3DSR/L2DSR configurations are stored in the \fI/etc/dsr.d\fP directory.  Any
file that ends with \fI.conf\fP is considered a configuration file and is
parsed for configuration information.  DSR configuration files essentially
comprise key=value pairs where the key is the LB/VIP IP address and the
value is the DSCP value.  The configuration file format is defined in
\fBdsr.conf\fP(5).
.PP
\fBdsrctl\fP works with both IPv4 and IPv6 addresses and they can be
intermingled in the same \fI.conf\fP file.  The IPv4 address may be either
a dotted decimal IP address or a fully qualified domain name.  If a fully
qualified domain name is provided, then it defaults to its IPv4 address
even if an IPv6 address exists for the FQDN.  IPv6 addresses may only
be specified as numeric addresses.
.PP
\fBdsrctl\fP operates successfully even if there are other iptables rules or
loopback aliases in use.  \fBdsrctl\fP keeps track of which iptables rules and
loopback aliases are configured on behalf of the DSR configuration and only
modifies those rules and loopbacks.
.PP
It is an error to configure more than one DSR with the same DSCP value unless
the DSCP value is related to one IPv4 address and one IPv6 address.  Two IPv4
addresses with the same DSCP value or two IPv6 addresses with the same DSCP
value result in an invalid configuration.  Neither the initial nor the duplicate
DSRs are started when the \fIstart\fP action is called.
\fBdsrctl\fP does not check whether the IPv4 and IPv6 addresses refer to the
same VIP.
.PP
It is acceptable to configure multiple DSRs with the same IP address as long as
they have different DSCP values.

.SH OPTIONS
.PP

.TP
\fBaction\fP
Run the given action.  You must specify one action.  The following actions are
supported.

.RS

.TP
\fBcheck\fP
Provide a one line status about the state of the configured DSRs.

.TP
\fBrestart\fP
The \fBrestart\fP action calls the \fBstop\fP and \fBstart\fP actions.

.TP
\fBstart\fP
Start the DSRs specified by the configuration file(s).

.TP
\fBstatus\fP
Display the status of all configured DSRs.  The status contains several columns of information.

.TP
\fBstop\fP
Stop the DSRs specified by the configuration file(s).

.RE

.TP
\fB\-a\fR
Display status not only for the configured DSRs, but for all iptables rules and
loopback aliases that are discovered.

.TP
\fB\-d\fR \fIdir\fP
use the given \fIdir\fP to search for configuration files instead of the
default (\fI/etc/dsr.d\fP).

.TP
\fB\-f\fR \fIfile\fP
Use the given \fIfile\fP as the sole configuration file.

.TP
\fB\-h\fR
Print the usage statement for \fBdsrctl\fP.

.TP
\fB\-n\fR
Don't actually perform the operations.  This option is usually paired with
\fB-v\fP in order to see what commands would be run.

.TP
\fB\-v\fR
Print more verbose information.  Additional \fB-v\fP options increase the
verbosity.

.TP
\fB\-x\fR
Don't print the header.


.SH "STATUS DISPLAY"

The \fBstatus\fP display provides several fields of information which are
described below.

.TP
\fBtype\fP
The following types are displayed for DSRs, loopbacks, and iptables rules.  A
configured DSR (one found in a .conf file) will always be either \fIl3dsr\fP
or \fIl2dsr\fP. \fBdsrctl\fP only prints configured DSRs unless the \fB-a\fP
option is given.  Configured and discovered DSRs are differentiated via the
\fBsrc\fP column.

.RS

.TP
\fBl3dsr\fP
A DSR has a type of \fBl3dsr\fP when the DSR is a configured or discovered
L3DSR.  Discovered L3DSRs (\fBsrc\fP is disc) are displayed only when the
\fB-a\fP option is requested and \fBdsrctl\fP finds a matched loopback alias
and iptables rule.

.TP
\fBl2dsr\fP
A DSR has a type of \fBl2dsr\fP when the DSR is a configured L2DSR.

.TP
\fBloopb\fP
When the \fB-a\fP option is requested, \fBdsrctl\fP displays a type of
\fBloopb\fP for loopback aliases that are discovered to be active, not matched
with an iptables rule, and not configured from a .conf file.

.TP
\fBiptbl\fP
When the \fB-a\fP option is requested, \fBdsrctl\fP displays a type of
\fBiptbl\fP for iptables rules that are discovered to be active, not matched
with a loopback alias, and not configured from a .conf file.

.RE

.TP
\fBstate\fP
The state is the current state of the DSR, loopback alias, or iptables rule.

.RS

.TP
\fBstopped\fP
The DSR is not running.  For L3DSRs, neither the loopback alias nor the
iptables rule has been activated.  For L2DSRs, the loopback alias has not been
activated.

.TP
\fBstarted\fP
The DSR has been activated.  For L3DSRs, both the loopback alias and the
iptables rule have been activated.  For L2DSRs, the loopback alias has been
activated.

.TP
\fBpartial\fP
This state is only applicable to L3DSRs and is displayed when either the
loopback alias or the iptables rule has been activated, but not both.

.RE

.TP
\fBname\fP
The name displays the name of the DSR.  If the DSR was configured with a FQDN,
then the FQDN is displayed.  If the DSR was configured with a numerical
VIP (IPv4 or IPv6), then the address is displayed.  For discovered DSRs,
loopbacks, and iptables rules, the numerical VIP is always displayed for the
name.

.TP
\fBipaddr\fP
The ipaddr is the numerical VIP address.

.TP
\fBdscp\fP
The dscp value is only applicable for L3DSRs.  For configured L3DSRs, the dscp
value is the value from the .conf file in its original form (decimal, octal,
or hex).  For discovered L3DSRs, the value is taken from the iptables rule.

.TP
\fBloopback\fP
For IPv4 DSRs and discovered loopback aliases, the displayed loopback is in
the form "lo:n" where \fIn\fP signifies the number of the loopback alias.  For
IPv6 DSRs and discovered loopback aliases, the loopback is just displayed as
"lo".  If the loopback alias is not activated, then it is displayed as "--".

.TP
\fBiptables\fP
If the iptables rule is activated, then it is displayed as "up".  Otherwise,
the iptables rule is displayed as "--".

.TP
\fBsrc\fP
The src column is either \fBconf\fP for configured DSRs or \fBdisc\fP for
discovered DSRs, loopback aliases and iptables rules.  This column is only
displayed when the \fB-a\fP option is requested.


.SH "RETURN VALUES"
.PP
Exit status is 0 if OK, 1 if there are errors (e.g. failure to start the DSR
configuration, syntax errors, failure to
find the configuration file, configuration errors in the \fI.conf\fP files,
not executing as root, running on unsupported RHEL releases, etc.).

.SH FILES
.TP
/etc/dsr.d
This directory is the location where DSR configuration files are stored.  Only
files that end with \fI.conf\fP are considered configuration files and all
others are ignored.

.TP
/etc/rc.d/init.d/dsr (for distros using SySV init)
The \fBdsr\fP rcfile runs during every boot to start all of the configured DSRs.

.TP
/usr/lib/systemd/system/dsr.service (for distros using systemd)
The \fBdsr\fP service runs during every boot to start all of the configured DSRs.

.SH AUTHOR
Wayne Badger, Yahoo, Inc.
.SH "REPORTING BUGS"
Report bugs to <linux\-kernel@yahoo\-inc.com>.
.SH "SEE ALSO"
.BR dsr.conf (5)
