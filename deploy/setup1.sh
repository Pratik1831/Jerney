```bash
#!/bin/bash
# ============================================
# Jerney Blog Platform - RHEL 9 EC2 Setup Script
# ============================================

set -e

echo "🛤️  Setting up Jerney Blog Platform..."
echo "==========================================="

# --- Update system ---
echo "📦 Updating system packages..."
sudo dnf update -y

# --- Install required packages ---
echo "📦 Installing required packages..."
sudo dnf install -y curl wget

# --- Install Node.js 20.x ---
echo "📦 Installing Node.js 20.x..."

curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -

sudo dnf install -y nodejs

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# --- Install PostgreSQL ---
echo "📦 Installing PostgreSQL..."
sudo dnf install -y postgresql-server postgresql

# --- Initialize PostgreSQL ---
echo "🗄️  Initializing PostgreSQL..."

if [ ! -d "/var/lib/pgsql/data/base" ]; then
    sudo postgresql-setup --initdb
fi

sudo systemctl enable --now postgresql

# --- Install Nginx ---
echo "📦 Installing Nginx..."
sudo dnf install -y nginx

sudo systemctl enable --now nginx

# --- Install PM2 ---
echo "📦 Installing PM2..."
sudo npm install -g pm2

# --- Configure PostgreSQL ---
echo "🗄️  Configuring PostgreSQL..."

sudo -u postgres psql <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE rolname = 'jerney_user'
    ) THEN
        CREATE USER jerney_user WITH PASSWORD 'jerney_pass_2026';
    END IF;
END
\$\$;

SELECT 'CREATE DATABASE jerney_db OWNER jerney_user'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'jerney_db'
)\gexec

GRANT ALL PRIVILEGES ON DATABASE jerney_db TO jerney_user;
EOF

sudo -u postgres psql -d jerney_db <<EOF
GRANT ALL ON SCHEMA public TO jerney_user;
EOF

echo "✅ PostgreSQL configured"

# --- Set up project directory ---
echo "📁 Setting up project..."

sudo mkdir -p /var/www/jerney
sudo chown -R $USER:$USER /var/www/jerney

# Copy project files
echo "📁 Copying project files..."

cp -r ~/Jerney/* /var/www/jerney/

# --- Install backend dependencies ---
echo "📦 Installing backend dependencies..."

cd /var/www/jerney/backend

npm install --production

# --- Build frontend ---
echo "🔨 Building frontend..."

cd /var/www/jerney/frontend

npm install
npm run build

# --- Configure Nginx ---
echo "🌐 Configuring Nginx..."

sudo cp /var/www/jerney/deploy/jerney-nginx.conf \
    /etc/nginx/conf.d/jerney.conf

sudo nginx -t

sudo systemctl restart nginx

sudo systemctl enable nginx

# --- Start backend with PM2 ---
echo "🚀 Starting backend with PM2..."

cd /var/www/jerney/backend

pm2 start src/index.js --name jerney-backend

pm2 save

pm2 startup systemd -u $USER --hp /home/$USER | tail -1 | sudo bash

echo ""
echo "==========================================="
echo "🎉 Jerney is now live!"
echo "==========================================="
echo ""

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<your-ec2-public-ip>")

echo "Access your blog at:"
echo "http://$PUBLIC_IP"

echo ""
echo "Useful commands:"
echo "  pm2 status"
echo "  pm2 logs"
echo "  pm2 restart jerney-backend"
echo "  sudo systemctl restart nginx"
echo "  sudo systemctl status postgresql"
echo "  sudo systemctl status nginx"
echo ""
```

