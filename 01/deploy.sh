#!/bin/bash
# ==========================================
# Full Setup Script: Flask + MariaDB + Gunicorn + Nginx
# Ubuntu 24.04
# ==========================================

set -e  # Stop on errors

# 1️⃣ Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# 2️⃣ Install required packages
echo "Installing required packages..."
sudo apt install -y python3 python3-venv python3-pip \
 mariadb-server mariadb-client libmariadb-dev \
 nginx curl ufw git build-essential

# 3️⃣ Go to project directory
PROJECT_DIR="/home/ubuntu/db-apps/01"
echo "Going to project directory: $PROJECT_DIR"
cd $PROJECT_DIR

# 4️⃣ Create Python virtual environment if not exists
if [ ! -d "venv_01" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv_01
fi
source venv_01/bin/activate

# 5️⃣ Upgrade pip and install Python dependencies
echo "Upgrading pip..."
pip install --upgrade pip

if [ -f requirements.txt ]; then
    echo "Installing Python dependencies..."
    pip install -r requirements.txt
else
    echo "requirements.txt not found! Skipping Python dependencies installation."
fi

# 6️⃣ Start and enable MariaDB
echo "Starting MariaDB..."
sudo systemctl start mariadb
sudo systemctl enable mariadb

# 7️⃣ Create database and user safely
DB_NAME="flaskapp_db"
DB_USER="flaskapp"
DB_PASS="flaskpass"

echo "Cleaning up existing database and user..."
sudo mysql -u root <<EOF
-- Kill any active connections from the user
SELECT CONCAT('KILL ', id, ';') 
FROM information_schema.processlist 
WHERE user='$DB_USER' 
INTO OUTFILE '/tmp/kill_user.sql';
SOURCE /tmp/kill_user.sql;

-- Remove existing user and database
DROP USER IF EXISTS '$DB_USER'@'localhost';
DROP DATABASE IF EXISTS $DB_NAME;
FLUSH PRIVILEGES;

-- Clean up temp file
\! rm -f /tmp/kill_user.sql
EOF

echo "Creating fresh database and user..."
sudo mysql -u root <<EOF
-- Create fresh database
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create fresh user
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';

-- Grant privileges
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;

-- Verify creation
SELECT "Database and user created successfully!" as Status;
SELECT User, Host FROM mysql.user WHERE User = '$DB_USER';
SHOW DATABASES LIKE '$DB_NAME';
EOF

# 8️⃣ Create and import schema.sql (instead of using init_db.sql)
echo "Creating schema.sql file..."
cat > schema.sql << 'EOF'
CREATE TABLE IF NOT EXISTS servers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    os VARCHAR(100)
);

INSERT INTO servers (name, role, os) VALUES 
('web01', 'web', 'Ubuntu 24.04'),
('db01', 'database', 'Ubuntu 24.04');
EOF

echo "Importing schema.sql into $DB_NAME..."
sudo mysql -u root $DB_NAME < schema.sql
echo "Database schema imported successfully!"

# Verify the data was inserted
echo "Verifying data in $DB_NAME..."
sudo mysql -u root $DB_NAME -e "SELECT COUNT(*) as server_count FROM servers;"
sudo mysql -u root $DB_NAME -e "SELECT * FROM servers;"

# 9️⃣ Test database connection
echo "Testing database connection..."
if sudo mysql -u $DB_USER -p$DB_PASS -e "SELECT 'Connection successful!' as Status;" 2>/dev/null; then
    echo "✓ Database connection successful!"
else
    echo "✗ Database connection failed!"
    exit 1
fi

# 🔟 Create systemd service for Gunicorn
SERVICE_FILE="/etc/systemd/system/db_apps_01.service"
echo "Creating systemd service $SERVICE_FILE..."
sudo tee $SERVICE_FILE > /dev/null <<EOL
[Unit]
Description=Flask + MariaDB App
After=network.target mariadb.service

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv_01/bin"
ExecStart=$PROJECT_DIR/venv_01/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable db_apps_01.service
sudo systemctl restart db_apps_01.service

# 1️⃣1️⃣ Configure Nginx reverse proxy
NGINX_FILE="/etc/nginx/sites-available/db_apps_01"
echo "Configuring Nginx..."
sudo tee $NGINX_FILE > /dev/null <<EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Remove default Nginx site to avoid conflicts
echo "Removing default Nginx site to avoid conflicts..."
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo rm -f /etc/nginx/sites-available/default 2>/dev/null || true

# Enable our site
sudo ln -sf $NGINX_FILE /etc/nginx/sites-enabled/

# Test and restart Nginx
sudo nginx -t
sudo systemctl restart nginx

# 1️⃣2️⃣ Configure UFW firewall
echo "Configuring UFW firewall..."
sudo ufw allow 'OpenSSH'
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# 1️⃣3️⃣ Show status
echo "Checking services status..."
echo ""
echo "=== MariaDB Status ==="
sudo systemctl status mariadb --no-pager | head -5
echo ""
echo "=== Gunicorn Status ==="
sudo systemctl status db_apps_01.service --no-pager | head -10
echo ""
echo "=== Nginx Status ==="
sudo systemctl status nginx --no-pager | head -5

# 1️⃣4️⃣ COMPREHENSIVE TESTING SECTION
echo ""
echo "======================================="
echo "COMPREHENSIVE TESTING"
echo "======================================="

echo ""
echo "1. Testing Flask Application Import..."
python3 -c "
from app import app
print('✓ App imported successfully')
print(f'  App name: {app.name}')
"

echo ""
echo "2. Testing Database Connection..."
python3 -c "
import mariadb
try:
    conn = mariadb.connect(
        user='$DB_USER',
        password='$DB_PASS',
        host='localhost',
        database='$DB_NAME',
        port=3306
    )
    print('✓ Database connection successful')
    
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM servers')
    count = cursor.fetchone()[0]
    print(f'✓ Database has {count} servers')
    
    cursor.execute('SELECT * FROM servers')
    servers = cursor.fetchall()
    print('  Sample data:')
    for server in servers:
        print(f'    - ID: {server[0]}, Name: {server[1]}, Role: {server[2]}, OS: {server[3]}')
    
    cursor.close()
    conn.close()
except mariadb.Error as e:
    print(f'✗ Database error: {e}')
except Exception as e:
    print(f'✗ Error: {e}')
"

echo ""
echo "3. Testing Gunicorn Direct Connection..."
if curl -s -f http://127.0.0.1:8000/ > /dev/null; then
    GUNICORN_RESPONSE=$(curl -s http://127.0.0.1:8000/)
    if echo "$GUNICORN_RESPONSE" | grep -q "status.*online\|Flask.*API"; then
        echo "✓ Gunicorn is running correctly on port 8000"
        echo "  Response: $(echo "$GUNICORN_RESPONSE" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))" 2>/dev/null | head -10)"
    else
        echo "⚠️  Gunicorn responding with unexpected content"
        echo "  Preview: ${GUNICORN_RESPONSE:0:200}..."
    fi
else
    echo "✗ Gunicorn not responding on port 8000"
fi

echo ""
echo "4. Testing Nginx Proxy..."
if curl -s -f http://localhost/ > /dev/null; then
    NGINX_RESPONSE=$(curl -s http://localhost/)
    if echo "$NGINX_RESPONSE" | grep -q "Welcome to nginx"; then
        echo "✗ Nginx is serving DEFAULT PAGE, not proxying to Flask!"
        echo "  Debug: Default Nginx site might still be active"
        echo "  Fix: sudo rm -f /etc/nginx/sites-enabled/default"
    elif echo "$NGINX_RESPONSE" | grep -q "status.*online\|Flask.*API"; then
        echo "✓ Nginx is correctly proxying to Flask app"
        echo "  Response: $(echo "$NGINX_RESPONSE" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))" 2>/dev/null | head -10)"
    else
        echo "⚠️  Nginx responding but content unexpected"
        echo "  Preview: ${NGINX_RESPONSE:0:200}..."
    fi
else
    echo "✗ Nginx not responding on port 80"
fi

echo ""
echo "5. Testing API Endpoints..."
echo "   Testing GET /servers:"
if SERVERS_RESPONSE=$(curl -s -f http://localhost/servers 2>/dev/null); then
    if echo "$SERVERS_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(f'    ✓ Success! Found {len(data)} servers')" 2>/dev/null; then
        echo "    ✓ JSON response valid"
    else
        echo "    ⚠️  Response not valid JSON"
    fi
else
    echo "    ✗ Failed to reach /servers endpoint"
fi

echo ""
echo "   Testing POST /servers:"
POST_RESPONSE=$(curl -s -X POST http://localhost/servers \
  -H "Content-Type: application/json" \
  -d '{"name":"api-test-01","role":"test","os":"Ubuntu 24.04"}' 2>/dev/null || echo "POST_FAILED")
  
if [ "$POST_RESPONSE" != "POST_FAILED" ]; then
    if echo "$POST_RESPONSE" | python3 -c "import sys,json; data=json.load(sys.stdin); print(f'    ✓ Created server with ID: {data.get(\"id\", \"unknown\")}')" 2>/dev/null; then
        echo "    ✓ POST request successful"
    else
        echo "    ⚠️  POST responded with: ${POST_RESPONSE:0:100}..."
    fi
else
    echo "    ✗ POST request failed"
fi

echo ""
echo "6. Testing Database Consistency..."
sudo mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "
SELECT 'Current servers in database:' as Message;
SELECT id, name, role, os FROM servers;
SELECT CONCAT('Total: ', COUNT(*), ' servers') as Total FROM servers;
"

echo ""
echo "7. Testing Full CRUD Cycle (if POST worked)..."
# Check if we created a test server
TEST_SERVER_ID=$(sudo mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "SELECT id FROM servers WHERE name = 'api-test-01' LIMIT 1;" 2>/dev/null || echo "")
if [ -n "$TEST_SERVER_ID" ]; then
    echo "   Test server found with ID: $TEST_SERVER_ID"
    echo "   Testing DELETE /servers/$TEST_SERVER_ID:"
    DELETE_RESPONSE=$(curl -s -X DELETE http://localhost/servers/$TEST_SERVER_ID 2>/dev/null || echo "DELETE_FAILED")
    if [ "$DELETE_RESPONSE" != "DELETE_FAILED" ]; then
        echo "   ✓ Delete request sent"
        # Verify deletion
        REMAINING=$(sudo mysql -u $DB_USER -p$DB_PASS $DB_NAME -sN -e "SELECT COUNT(*) FROM servers WHERE id = $TEST_SERVER_ID;" 2>/dev/null || echo "1")
        if [ "$REMAINING" = "0" ]; then
            echo "   ✓ Server successfully deleted from database"
        else
            echo "   ⚠️  Server might still exist in database"
        fi
    else
        echo "   ✗ Delete request failed"
    fi
else
    echo "   No test server found for CRUD cycle test"
fi

echo ""
echo "8. Checking Logs for Errors..."
echo "   Gunicorn logs (last 5 lines):"
sudo journalctl -u db_apps_01.service --no-pager | tail -5 | sed 's/^/     /'
echo ""
echo "   Nginx error logs (last 5 lines):"
sudo tail -5 /var/log/nginx/error.log 2>/dev/null | sed 's/^/     /' || echo "     No error log found"

echo ""
echo "9. Network Configuration Check..."
echo "   Listening ports:"
sudo netstat -tulpn | grep -E ':80|:8000|:3306' | sed 's/^/     /' || echo "     No relevant ports found"
echo ""
echo "   Firewall status:"
sudo ufw status | sed 's/^/     /'

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "your-server-ip")
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================="
echo "DEPLOYMENT SUMMARY"
echo "======================================="
echo "Your Flask app should be accessible on:"
echo "  • http://$PUBLIC_IP/"
echo "  • http://$LOCAL_IP/"
echo ""
echo "Database Configuration:"
echo "  • Database: $DB_NAME"
echo "  • Username: $DB_USER"
echo "  • Password: $DB_PASS"
echo "  • Host: localhost:3306"
echo ""
echo "Service Information:"
echo "  • Flask/Gunicorn: http://127.0.0.1:8000"
echo "  • Nginx Proxy: Port 80"
echo "  • MariaDB: Port 3306"
echo ""
echo "API Endpoints:"
echo "  • GET  /          - API info"
echo "  • GET  /servers   - List all servers"
echo "  • POST /servers   - Add new server"
echo "  • GET  /servers/{id} - Get server by ID"
echo "  • DELETE /servers/{id} - Delete server"
echo ""
echo "Troubleshooting Commands:"
echo "  • Check Flask logs: sudo journalctl -u db_apps_01.service -f"
echo "  • Check Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "  • Test database: sudo mysql -u $DB_USER -p$DB_PASS $DB_NAME"
echo "  • Test API: curl http://localhost/servers"
echo "  • Restart services: sudo systemctl restart db_apps_01.service nginx mariadb"
echo ""
echo "Quick Tests:"
echo "  • curl http://localhost/"
echo "  • curl http://localhost/servers"
echo "  • curl -X POST http://localhost/servers -H 'Content-Type: application/json' -d '{\"name\":\"test\",\"role\":\"test\",\"os\":\"Ubuntu\"}'"
echo ""
echo "If you see Nginx default page instead of Flask app:"
echo "  sudo rm -f /etc/nginx/sites-enabled/default && sudo systemctl reload nginx"
echo "======================================="
