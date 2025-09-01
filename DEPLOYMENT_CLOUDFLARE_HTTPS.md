# 🚀 Production Deployment with Cloudflare HTTPS

## Architecture Overview
```
User → Cloudflare (HTTPS) → Your Server (HTTP:80) → Docker Container
```

## ⚠️ Important: Cloudflare Port Requirements
Cloudflare only proxies specific ports. We use **port 80** for HTTP traffic.
- **Supported HTTP ports:** 80, 8880, 2052, 2082, 2086, 2095
- **Common mistake:** Port 8080 is NOT proxied by Cloudflare!

## 🐳 Docker-Only Deployment (Recommended)

Everything runs in Docker for maximum portability and simplicity.

### Step 1: Prepare Your Server
```bash
# SSH into your server
ssh user@your-server-ip

# Install Docker (includes Docker Compose)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Logout and login again for group changes
exit
ssh user@your-server-ip
```

### Step 2: Deploy the Application
```bash
# Clone the repository
git clone https://github.com/future-xy/liKeYun_ylb.git
cd liKeYun_ylb

# (Optional) Configure environment
cp env.example .env
# Edit .env if needed - default uses port 80

# Start the container (requires sudo for port 80)
sudo docker compose up -d

# Verify it's running
docker ps
curl http://localhost  # Should return HTML
```

**Development Mode:** To use port 8080 for local development:
```bash
echo "HOST_PORT=8080" > .env
docker compose up -d  # No sudo needed
# Note: This won't work with Cloudflare proxy!
```

### Step 3: Configure Firewall
```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow port 80 only from Cloudflare IPs
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    sudo ufw allow from $ip to any port 80
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
   - Set encryption mode to **Flexible** (Cloudflare to origin uses HTTP)
   - This is secure since Cloudflare handles HTTPS for users

3. **Configure Page Rules** (Optional but recommended):
   - Go to Rules → Page Rules
   - Create rule for `http://ylb.domain.com/*`
   - Setting: Always Use HTTPS
   - Save and Deploy

4. **Configure Firewall Rules** (Optional):
   - Go to Security → WAF
   - Create custom rules as needed

### Step 5: Initial Setup

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

### Step 6: Post-Installation Security

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

## 🔄 Alternative Port Configurations

### Using Cloudflare-Compatible Alternative Ports

If port 80 is unavailable, use other Cloudflare-supported ports:

```bash
# Option 1: Port 8880 (HTTP alternative)
echo "HOST_PORT=8880" > .env
sudo docker compose up -d

# Update firewall for port 8880
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    sudo ufw allow from $ip to any port 8880
done
```

### Multiple Services on Same Server

If you need to run multiple services, consider using Docker networks and a reverse proxy container:

```yaml
# docker-compose.override.yml
services:
  nginx-proxy:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - likeyun-ylb
    networks:
      - web

  likeyun-ylb:
    # Remove ports section from main service
    networks:
      - web

networks:
  web:
    driver: bridge
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

### Common Issue: "Error 522" - Connection Timed Out
**Most common causes:**
1. Using port 8080 with Cloudflare proxy enabled
2. Firewall blocking Cloudflare IPs
3. Container not running

**Solutions:**
```bash
# Check container status
docker ps
docker compose logs

# Test local access
curl http://localhost

# Check firewall
sudo ufw status

# Restart if needed
sudo docker compose restart
```

### Port 80 Permission Denied
```bash
# Need sudo for privileged ports (< 1024)
sudo docker compose up -d

# Or use a higher port for development
echo "HOST_PORT=8080" > .env
docker compose up -d
```

### "521 Web Server Is Down" Error
```bash
# Check if container is running
docker ps

# View logs
docker compose logs -f

# Check health
docker compose ps

# Force recreate
docker compose down
docker compose up -d --force-recreate
```

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

# Check nginx logs inside container
docker exec likeyun-ylb tail -f /var/log/nginx/access.log
docker exec likeyun-ylb tail -f /var/log/nginx/error.log

# Health check
curl -I http://localhost
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

# Restore backup
docker exec -i likeyun-ylb mysql -uroot -pYOUR_PASSWORD likeyun_ylb < backup_20240101.sql

# Automated daily backup (add to crontab)
0 2 * * * docker exec likeyun-ylb mysqldump -uroot -pYOUR_PASSWORD likeyun_ylb > /backups/ylb_$(date +\%Y\%m\%d).sql
```

### View/Edit Files in Container
```bash
# Access container shell
docker exec -it likeyun-ylb bash

# View specific file
docker exec likeyun-ylb cat /var/www/html/console/Db.php

# Copy file out for editing
docker cp likeyun-ylb:/var/www/html/config.php ./config.php

# Copy file back
docker cp ./config.php likeyun-ylb:/var/www/html/config.php
```

---

## 📋 Quick Deployment Checklist

1. ✅ Install Docker on server
2. ✅ Clone repository
3. ✅ Configure `.env` (optional)
4. ✅ Run `sudo docker compose up -d`
5. ✅ Configure firewall for Cloudflare IPs
6. ✅ Set up Cloudflare DNS with proxy ON
7. ✅ Set Cloudflare SSL to Flexible mode
8. ✅ Access via `https://ylb.domain.com/install/`
9. ✅ Complete setup and remove install directory
10. ✅ Change default passwords

⚠️ **Remember:** 
- Use port 80 (or other Cloudflare-supported ports)
- Port 8080 is NOT proxied by Cloudflare
- Everything runs in Docker - no external dependencies needed!