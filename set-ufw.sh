# 1. Reset UFW
ufw reset
ufw default deny incoming
ufw default allow outgoing

# 2. Allow SSH
ufw allow 22/tcp
ufw allow 7320:7330/tcp

# 3. Get Cloudflare IPs
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

# 4. Only allow Cloudflare IPs to access 80 and 443
for ip in $CF_IPV4; do
    ufw allow proto tcp from $ip to any port 80,443 comment 'Cloudflare IP'
done

for ip in $CF_IPV6; do
    ufw allow proto tcp from $ip to any port 80,443 comment 'Cloudflare IP'
done

# 5. Deny all other traffic to 80 and 443
ufw deny proto tcp from any to any port 80,443

# 6. Enable UFW
ufw enable
