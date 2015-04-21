.TH DSR.CONF "5" "March 2015" "dsr.conf __VERSION__" "System Management Commands"
.SH NAME
dsr.conf \- configuration file for DSRs

.SH DESCRIPTION

The \fBdsrctl\fP command parses all files that end with \fI.conf\fP in
\fB/etc/dsr.d\fP as DSR configuration files.  The \fI.conf\fP files are parsed
in a sorted order that is defined by the locale specified in the environment.

\fBdsrctl\fP performs very limited input validation.

The basic format for each line in a \fI.conf\fP files is
.nf
	key=value
.fi

\fBdsrctl\fP supports both L3DSR and L2DSR, but the configuration is
different.

This is an example L3DSR configuration.
.nf
	# VIP=DSCP
	98.139.235.245=28    # this is the best L3DSR ever
.fi

This is an example L2DSR configuration.
.nf
	# VIP
	98.139.235.245       # this is the best L2DSR ever
.fi

The maximum DSCP value is 63.  The DSCP value may be specified as a decimal
(e.g. 33), octal (e.g. 041), or hex (e.g. 0x21) value.  \fBdsrctl\fP does not
stop you from using a DSCP value of 0, but since this is the likely default value
for the DSCP in most packets, it is a poor choice.

Spaces/tabs are allowed anywhere, but the key and value must reside on the
same line.  Only one DSR configuration is allowed per line.

Lines that begin with an octothorp (#) are considered comments and are
ignored.  Empty lines and lines containing only spaces and tabs are ignored.
Comments are allowed on the key=value lines.  Everything after the octothorp
is ignored.


.SH FILES
.TP
/etc/dsr.d
This directory is the location where DSR configuration files are stored.  Only
files that end with \fI.conf\fP are considered configuration files and all
others are ignored.

.SH AUTHOR
Wayne Badger, Yahoo!.
.SH "REPORTING BUGS"
Report bugs to <linux\-kernel@yahoo\-inc.com>.
.SH "SEE ALSO"
.BR dsrctl (8)
