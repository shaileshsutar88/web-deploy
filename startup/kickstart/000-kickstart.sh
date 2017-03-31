#!/bin/bash
set -e

# Fix "stdin: is not a tty" warning
sudo sed -ie 's/^mesg/#mesg/' /root/.profile

# Setup FQDN update script
sudo tee /etc/network/if-up.d/update_fqdn <<"EOF"
#!/bin/bash
set -e

# Variable IFACE is setup by Ubuntu network init scripts to whichever interface changed status.
[ "$IFACE" == "eth0" ] || exit

# Knock out line with "old" IP
sed -i '/FQDN/ d' /etc/hosts

# Get IP address and hostname
ipaddress=$(/usr/bin/curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
hostname=$(/usr/bin/curl -s http://169.254.169.254/latest/meta-data/hostname)

# Add FQDN to hosts file
echo "$ipaddress $hostname # FQDN managed by /etc/network/if-up.d/update_fqdn" >> /etc/hosts
EOF
sudo chmod 755 /etc/network/if-up.d/update_fqdn
sudo IFACE=eth0 /etc/network/if-up.d/update_fqdn
