# Flags
default['pmacct']['registered'] = false

# x2kafka sflow listener (sfacctd)
default['pmacct']['port'] = 6343
# keepalived checks /health on this port: keep it in sync with the health_port of sfacctd
# in cookbook-rb-manager and with the ports opened by cookbook-rb-firewall
default['pmacct']['stats_port'] = 7984
