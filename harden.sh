#!/bin/sh

function CheckEntry {
    if grep -q $1 $2;
    then
        echo "entry '$1' allready present in '$2'"
    else
        echo $1 >> $2
    fi

# Configure iptables backup and restore
echo "#!/bin/sh" > /etc/network/if-pre-up.d/iptables
echo "/sbin/iptables-restore < /etc/iptables.up.rules" >> /etc/network/if-pre-up.d/iptables
chmod +x /etc/network/if-pre-up.d/iptables

# Configure iptable rules
iptables -F INPUT
iptables -F OUTPUT
iptables -F FORWARD
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -s 127.0.0.1/32 -p tcp -m tcp --dport 22 -m state --state NEW -j ACCEPT
-A INPUT -j DROP
-A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -j DROP
-A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A OUTPUT -m state --state NEW -j ACCEPT

# Save iptables
iptables-save > /etc/iptables.up.rules

# Disable ipv6
CheckEntry("#disable ipv6","/etc/sysctl.conf")

#echo "#disable ipv6" >> /etc/sysctl.conf
#echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
#echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
#echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
#echo "Ignore ICMP request:" >> /etc/sysctl.conf
#echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
#echo "Ignore Broadcast request:" >> /etc/sysctl.conf
#echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf

sysctl -p