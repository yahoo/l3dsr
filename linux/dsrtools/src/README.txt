This directory contains configuration files for the dsrtools package.  Only
files that end in ".conf" are configuration files.  dsrctl ignores all other
files.

An example L3DSR configuration might look like this.
	# VIP=DSCP
	98.139.235.245=28    # this is the best L3DSR ever
	201F::0080:1d0:f8=29 # this is a good one, too

An example L2DSR configuration might look like this.
	# VIP
	98.139.235.245       # this is the best L2DSR ever
	201F::0080:1d0:f8    # this is a good one, too

See dsr.conf(5) for more information.
