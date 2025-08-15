# 🚀 Production Deployment with Cloudflare HTTPS

## Architecture Overview
```
User → Cloudflare (HTTPS) → Your Server (HTTP:8080) → Docker Container
```

## Step-by-Step Deployment Guide

### Step 1: Prepare Your Server
```bash
# SSH into your server
ssh user@your-server-ip

# Install Docker (Docker Compose is included)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Logout and login again for group changes to take effect
exit
ssh user@your-server-ip
```

### Step 2: Deploy the Application
```bash
# Clone the repository
git clone https://github.com/future-xy/liKeYun_ylb.git
cd liKeYun_ylb

# Start the container (port 8080 is already configured)
docker compose up -d

# Verify it's running
docker ps
curl http://localhost:8080  # Should return HTML
```

### Step 3: Configure Firewall
```bash
# Allow SSH and HTTP from Cloudflare only
sudo ufw allow 22/tcp

# Allow port 8080 only from Cloudflare IPs
# Get Cloudflare IPs from: https://www.cloudflare.com/ips/
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    sudo ufw allow from $ip to any port 8080
done

# Enable firewall
sudo ufw --force enable
sudo ufw status
```

### Step 4: Configure Cloudflare

1. **Add DNS Record**:
   - Login to Cloudflare Dashboard
   - Go to your domain's DNS settings
   - Add an A record:
     - Type: `A`
     - Name: `ylb` (or `@` for root domain)
     - IPv4 address: `your-server-ip`
     - Proxy status: **Proxied (Orange Cloud ON)** ← Important!
     - TTL: Auto

2. **Configure SSL/TLS**:
   - Go to SSL/TLS → Overview
   - Set encryption mode to **Flexible** (Cloudflare to origin server uses HTTP)
   - This is OK since Cloudflare handles the HTTPS for users

3. **Configure Page Rules** (Optional but recommended):
   - Go to Rules → Page Rules
   - Create rule for `http://ylb.domain.com/*`
   - Setting: Always Use HTTPS
   - Save and Deploy

4. **Configure Firewall Rules** (Optional):
   - Go to Security → WAF
   - Create custom rules as needed

### Step 5: Configure Nginx Reverse Proxy (Alternative - More Secure)

If you want better security with Full SSL mode in Cloudflare:

```bash
# Install Nginx on the host
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/ylb
```

Add this configuration:
```nginx
server {
    listen 80;
    server_name ylb.domain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Cloudflare real IP
        set_real_ip_from 173.245.48.0/20;
        set_real_ip_from 103.21.244.0/22;
        set_real_ip_from 103.22.200.0/22;
        set_real_ip_from 103.31.4.0/22;
        set_real_ip_from 141.101.64.0/18;
        set_real_ip_from 108.162.192.0/18;
        set_real_ip_from 190.93.240.0/20;
        set_real_ip_from 188.114.96.0/20;
        set_real_ip_from 197.234.240.0/22;
        set_real_ip_from 198.41.128.0/17;
        set_real_ip_from 162.158.0.0/15;
        set_real_ip_from 104.16.0.0/13;
        set_real_ip_from 104.24.0.0/14;
        set_real_ip_from 172.64.0.0/13;
        set_real_ip_from 131.0.72.0/22;
        real_ip_header CF-Connecting-IP;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/ylb /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Get Cloudflare Origin Certificate (for Full SSL mode)
# Go to Cloudflare → SSL/TLS → Origin Server
# Create certificate and save the files
sudo mkdir -p /etc/ssl/cloudflare
sudo nano /etc/ssl/cloudflare/cert.pem  # Paste certificate
sudo nano /etc/ssl/cloudflare/key.pem   # Paste private key

# Update Nginx config for SSL
sudo nano /etc/nginx/sites-available/ylb
```

Add SSL configuration:
```nginx
server {
    listen 443 ssl http2;
    server_name ylb.domain.com;

    ssl_certificate /etc/ssl/cloudflare/cert.pem;
    ssl_certificate_key /etc/ssl/cloudflare/key.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

server {
    listen 80;
    server_name ylb.domain.com;
    return 301 https://$server_name$request_uri;
}
```

```bash
# Reload Nginx
sudo nginx -t
sudo systemctl reload nginx

# Update firewall for HTTPS
sudo ufw allow 443/tcp
```

Then in Cloudflare, change SSL/TLS mode to **Full**.

### Step 6: Initial Setup

1. Visit `https://ylb.domain.com/install/`
2. Complete the installation wizard:
   - Database Host: `localhost`
   - Database Name: `likeyun_ylb`
   - Database User: `root`
   - Database Password: `likeyun123456`
3. Create admin account
4. **Delete install directory**:
   ```bash
   docker exec likeyun-ylb rm -rf /var/www/html/install/
   ```

### Step 7: Post-Installation Security

```bash
# Change MySQL password (recommended)
docker exec -it likeyun-ylb bash
mysql -uroot -plikeyun123456
ALTER USER 'root'@'localhost' IDENTIFIED BY 'YOUR_NEW_STRONG_PASSWORD';
FLUSH PRIVILEGES;
exit
exit

# Update the password in the container
docker exec likeyun-ylb sed -i "s/likeyun123456/YOUR_NEW_STRONG_PASSWORD/g" /var/www/html/console/Db.php
docker exec likeyun-ylb sed -i "s/likeyun123456/YOUR_NEW_STRONG_PASSWORD/g" /start.sh

# Restart container
docker compose restart
```

## 🔒 Security Checklist

- [x] Cloudflare Proxy enabled (hides real server IP)
- [x] Firewall configured (only allow Cloudflare IPs)
- [x] HTTPS enforced via Cloudflare
- [ ] Change default MySQL password
- [ ] Delete install directory after setup
- [ ] Enable Cloudflare WAF rules
- [ ] Set up regular backups

## 🔧 Troubleshooting

### "521 Web Server Is Down" Error
```bash
# Check if container is running
docker ps
docker compose logs

# Check if port 8080 is accessible
curl http://localhost:8080

# Restart container
docker compose restart
```

### "Error 520/522/524" on Cloudflare
- 520: Unknown error - check server logs
- 522: Connection timed out - check firewall allows Cloudflare IPs
- 524: Timeout - increase Cloudflare timeout or optimize slow queries

### Real Visitor IPs Not Showing
Add to your application's PHP files:
```php
if (isset($_SERVER['HTTP_CF_CONNECTING_IP'])) {
    $_SERVER['REMOTE_ADDR'] = $_SERVER['HTTP_CF_CONNECTING_IP'];
}
```

## 📊 Monitoring

```bash
# View container logs
docker compose logs -f

# Monitor resource usage
docker stats likeyun-ylb

# Check Nginx access logs
docker exec likeyun-ylb tail -f /var/log/nginx/access.log
```

## 🔄 Maintenance

### Update Application
```bash
cd liKeYun_ylb
git pull
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Backup Database
```bash
# Create backup
docker exec likeyun-ylb mysqldump -uroot -pYOUR_PASSWORD likeyun_ylb > backup_$(date +%Y%m%d).sql

# Automated daily backup (add to crontab)
0 2 * * * docker exec likeyun-ylb mysqldump -uroot -pYOUR_PASSWORD likeyun_ylb > /backups/ylb_$(date +\%Y\%m\%d).sql
```

---

**Quick Summary:**
1. Deploy Docker container on port 8080
2. Configure Cloudflare DNS with proxy ON
3. Set Cloudflare SSL to Flexible mode
4. Configure firewall to only allow Cloudflare IPs
5. Access via https://ylb.domain.com

That's it! Your application is now accessible via HTTPS with Cloudflare's SSL certificate.