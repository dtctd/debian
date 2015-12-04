#!/bin/sh

# Configure iptables backup and restore
iptables-save > /etc/iptables.up.rules
echo ""#!/bin/sh\n /sbin/iptables-restore < /etc/iptables.up.rules\n" > /etc/network/if-pre-up.d/iptables
chmod +x /etc/network/if-pre-up.d/iptables

# Configure iptable rules
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j DROP
iptables -A INPUT -p tcp --dport 111 -j DROP

# Disable ipv6
echo "#disable ipv6\n net.ipv6.conf.all.disable_ipv6 = 1\n net.ipv6.conf.default.disable_ipv6 = 1\n net.ipv6.conf.lo.disable_ipv6 = 1\n" > /etc/sysctl.conf
echo "\n Ignore ICMP request:\n net.ipv4.icmp_echo_ignore_all = 1\n Ignore Broadcast request:\n net.ipv4.icmp_echo_ignore_broadcasts = 1\n" /etc/sysctl.conf

restart sysctl