#!/bin/sh

# Configure iptables backup and restore
iptables-save > /etc/iptables.up.rules
echo "#!/bin/sh" > /etc/network/if-pre-up.d/iptables
echo "/sbin/iptables-restore < /etc/iptables.up.rules" >> /etc/network/if-pre-up.d/iptables
chmod +x /etc/network/if-pre-up.d/iptables

# Configure iptable rules
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
iptables -A INPUT -i eth0 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j DROP
iptables -A INPUT -p tcp --dport 111 -j DROP

# Disable ipv6
echo "#disable ipv6" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "Ignore ICMP request:" >> /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
echo "Ignore Broadcast request:" >> /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf

restart sysctl