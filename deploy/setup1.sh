#!/bin/bash
# ============================================
# Jerney Blog Platform - RHEL 9 EC2 Setup Script
# ============================================

set -e

echo "🛤️  Setting up Jerney Blog Platform..."
echo "==========================================="

# --- Update system ---
echo "📦 Updating system packages..."
sudo yum update -y

# --- Install required packages ---
echo "📦 Installing required packages..."
sudo yum install -y curl wget

# --- Install Node.js 20.x ---
echo "📦 Installing Node.js 20.x..."

curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -

sudo yum install -y nodejs

echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# --- Install PostgreSQL ---
echo "📦 Installing PostgreSQL..."
sudo yum install -y postgresql-server postgresql

# --- Initialize PostgreSQL ---
echo "🗄️  Initializing PostgreSQL..."

if [ ! -d "/var/lib/pgsql/data/base" ]; then
    sudo postgresql-setup --initdb
fi

sudo systemctl enable --now postgresql

echo "✅ PostgreSQL service started"

# --- Install Nginx ---
echo "📦 Installing Nginx..."
sudo yum install -y nginx

sudo systemctl enable --now nginx

echo "✅ Nginx service started"

# --- Install PM2 ---
echo "📦 Installing PM2..."
sudo npm install -g pm2

echo "✅ PM2 installed"

# --- Configure PostgreSQL ---
echo "🗄️  Configuring PostgreSQL..."

sudo -u postgres psql <<'SQL'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE rolname = 'jerney_user'
    ) THEN
        CREATE USER jerney_user WITH PASSWORD 'jerney_pass_2026';
    END IF;
END
$$;

SELECT 'CREATE DATABASE jerney_db OWNER jerney_user'
WHERE NOT EXISTS (
    SELECT FROM pg_database
    WHERE datname = 'jerney_db'
)\gexec

GRANT ALL PRIVILEGES ON DATABASE jerney_db TO jerney_user;
SQL

sudo -u postgres psql -d jerney_db <<'SQL'
GRANT ALL ON SCHEMA public TO jerney_user;
SQL

echo "✅ PostgreSQL configured"

# --- Verify PostgreSQL ---
echo "🔍 Verifying PostgreSQL..."

sudo -u postgres psql -c "\du" | grep jerney_user

sudo -u postgres psql -l | grep jerney_db

echo "✅ PostgreSQL verification successful"

# --- Set up project directory ---
echo "📁 Setting up project..."

if [ ! -d "$HOME/Jerney" ]; then
    echo "❌ Project directory $HOME/Jerney does not exist"
    echo "Please clone the Jerney repository first."
    exit 1
fi

sudo mkdir -p /var/www/jerney
sudo chown -R "$USER:$USER" /var/www/jerney

# --- Copy project files ---
echo "📁 Copying project files..."

cp -r "$HOME/Jerney/." /var/www/jerney/

echo "✅ Project files copied"

# --- Verify project structure ---
echo "🔍 Checking project structure..."

if [ ! -d "/var/www/jerney/backend" ]; then
    echo "❌ Backend directory not found"
    exit 1
fi

if [ ! -d "/var/www/jerney/frontend" ]; then
    echo "❌ Frontend directory not found"
    exit 1
fi

if [ ! -f "/var/www/jerney/deploy/jerney-nginx.conf" ]; then
    echo "❌ Nginx configuration file not found:"
    echo "/var/www/jerney/deploy/jerney-nginx.conf"
    exit 1
fi

echo "✅ Project structure verified"

# --- Install backend dependencies ---
echo "📦 Installing backend dependencies..."

cd /var/www/jerney/backend

npm install --production

echo "✅ Backend dependencies installed"

# --- Build frontend ---
echo "🔨 Building frontend..."

cd /var/www/jerney/frontend

npm install

npm run build

echo "✅ Frontend build completed"

# --- Configure Nginx ---
echo "🌐 Configuring Nginx..."

sudo cp \
    /var/www/jerney/deploy/jerney-nginx.conf \
    /etc/nginx/conf.d/jerney.conf

echo "✅ Nginx configuration copied"

# --- Test Nginx configuration ---
echo "🔍 Testing Nginx configuration..."

sudo nginx -t

# --- Restart Nginx ---
echo "🔄 Restarting Nginx..."

sudo systemctl restart nginx

sudo systemctl enable nginx

echo "✅ Nginx configured successfully"

# --- Start backend with PM2 ---
echo "🚀 Starting backend with PM2..."

cd /var/www/jerney/backend

# Stop existing PM2 application if it exists
pm2 delete jerney-backend 2>/dev/null || true

pm2 start src/index.js --name jerney-backend

pm2 save

echo "✅ Backend started with PM2"

# --- Configure PM2 startup ---
echo "⚙️  Configuring PM2 startup..."

pm2 startup systemd -u "$USER" --hp "/home/$USER" | tail -1 | sudo bash

pm2 save

echo "✅ PM2 startup configured"

# --- Get Public IP ---
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "<your-ec2-public-ip>")

echo ""
echo "==========================================="
echo "🎉 Jerney is now live!"
echo "==========================================="
echo ""

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

echo "==========================================="
echo "✅ Setup completed successfully!"
echo "==========================================="
