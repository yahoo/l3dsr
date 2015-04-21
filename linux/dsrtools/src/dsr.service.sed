# dsrtools version __VERSION__

[Unit]
Description=DSR control
After=network.service
Documentation=man:dsrctl(8)

[Service]
Type=oneshot
ExecStart=/usr/sbin/dsrctl start
ExecStop=/usr/sbin/dsrctl stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
