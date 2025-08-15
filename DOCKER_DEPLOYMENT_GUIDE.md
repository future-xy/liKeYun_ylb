# 🐳 Docker Deployment Guide for liKeYun_Ylb (私域引流宝)

## 📋 Prerequisites

Before deploying, ensure you have:
- Docker installed (version 20.10 or higher)
- Docker Compose installed (version 1.29 or higher)
- At least 2GB of free disk space
- Port 8080 available (or modify the port in docker compose.yml)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/future-xy/liKeYun_ylb.git
cd liKeYun_ylb
```

### 2. Build and Start the Container
```bash
# Build and start the container
docker compose up -d

# Check if the container is running
docker ps

# View logs
docker compose logs -f
```

### 3. Initial Setup
1. Open your browser and navigate to: `http://your-server-ip:8080/install/`
2. Follow the installation wizard
3. Use these database credentials during setup:
   - **Database Host**: `localhost`
   - **Database Name**: `likeyun_ylb`
   - **Database User**: `root`
   - **Database Password**: `likeyun123456`
4. Create your admin account
5. After successful installation, **DELETE the install directory**:
   ```bash
   docker exec likeyun-ylb rm -rf /var/www/html/install/
   ```

## 📁 Directory Structure

After deployment, the following directories will be created:
```
liKeYun_Ylb/
├── data/
│   ├── mysql/        # MySQL database files (persistent)
│   ├── uploads/      # User uploaded files (persistent)
│   └── logs/         # Application logs
├── docker/           # Docker configuration files
├── docker compose.yml
└── Dockerfile
```

## 🔧 Configuration

### Changing the Port
Edit `docker compose.yml` and modify the ports section:
```yaml
ports:
  - "YOUR_PORT:80"  # Replace YOUR_PORT with your desired port
```

### Database Credentials
Default database credentials are set in the Dockerfile. For production, you should:
1. Modify the password in `docker/start.sh`
2. Update the password in the Dockerfile
3. Rebuild the image

### Timezone
Default timezone is set to `Asia/Shanghai`. To change it:
1. Edit the `TZ` environment variable in `docker compose.yml`
2. Restart the container

## 🛠️ Common Operations

### Start/Stop the Container
```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart
```

### View Logs
```bash
# All logs
docker compose logs -f

# Nginx logs
docker exec likeyun-ylb tail -f /var/log/nginx/access.log
docker exec likeyun-ylb tail -f /var/log/nginx/error.log

# MySQL logs
docker exec likeyun-ylb tail -f /var/log/supervisor/mysql.log
```

### Access the Container
```bash
docker exec -it likeyun-ylb bash
```

### Backup Database
```bash
# Create backup
docker exec likeyun-ylb mysqldump -uroot -plikeyun123456 likeyun_ylb > backup_$(date +%Y%m%d).sql

# Restore backup
docker exec -i likeyun-ylb mysql -uroot -plikeyun123456 likeyun_ylb < backup.sql
```

### Update Application
```bash
# Pull latest code
git pull

# Rebuild and restart
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 🔒 Security Recommendations

### For Production Deployment:

1. **Change Default Passwords**
   - Modify MySQL root password in `docker/start.sh`
   - Update the corresponding password in application configuration

2. **Use HTTPS**
   - Set up a reverse proxy (Nginx/Caddy) with SSL certificates
   - Example Nginx configuration:
   ```nginx
   server {
       listen 443 ssl;
       server_name your-domain.com;
       
       ssl_certificate /path/to/cert.pem;
       ssl_certificate_key /path/to/key.pem;
       
       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

3. **Firewall Rules**
   - Only expose necessary ports
   - Restrict database access to localhost

4. **Regular Backups**
   - Set up automated daily backups
   - Store backups in a secure location

5. **Remove Install Directory**
   - Always delete `/install/` directory after setup

## 🐛 Troubleshooting

### Container Won't Start
```bash
# Check logs
docker compose logs

# Check if ports are in use
netstat -tulpn | grep 8080
```

### MySQL Connection Issues
```bash
# Check if MySQL is running
docker exec likeyun-ylb service mysql status

# Restart MySQL
docker exec likeyun-ylb service mysql restart
```

### Permission Issues
```bash
# Fix upload directory permissions
docker exec likeyun-ylb chmod -R 777 /var/www/html/console/upload
docker exec likeyun-ylb chown -R www-data:www-data /var/www/html
```

### Reset Admin Password
```bash
# Access MySQL
docker exec -it likeyun-ylb mysql -uroot -plikeyun123456 likeyun_ylb

# Update admin password (replace 'newpassword' and 'admin_username')
UPDATE huoma_user SET user_pass = MD5('newpassword') WHERE user_name = 'admin_username';
```

## 📊 Monitoring

### Check Container Health
```bash
docker compose ps
docker inspect likeyun-ylb --format='{{.State.Health.Status}}'
```

### Resource Usage
```bash
docker stats likeyun-ylb
```

## 🆘 Support

- **Documentation**: https://docs.qq.com/doc/DREdWVGJxeFFOSFhI
- **GitHub Issues**: https://github.com/likeyun/liKeYun_Ylb/issues
- **Author WeChat**: sansure2016

## 📝 Notes

- The container includes all required services (MySQL, Nginx, PHP-FPM)
- Data is persisted in the `./data/` directory
- Default admin panel: `http://your-server-ip:8080/console/`
- The application supports various plugins which can be installed from the admin panel

## 🔄 Version Information

- **Application Version**: 2.4.6
- **PHP Version**: 7.4
- **MySQL Version**: 8.0
- **Nginx Version**: Latest from Ubuntu 20.04
- **Base Image**: Ubuntu 20.04

---

**Remember**: Always test in a development environment before deploying to production!