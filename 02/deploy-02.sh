#!/bin/bash
# ==========================================
# Complete Deployment Script for Project 02: Task Tracker
# Ubuntu 24.04
# ==========================================

set -e  # Stop on errors

echo "======================================="
echo "COMPLETE DEPLOYMENT: Task Tracker API (Project 02)"
echo "======================================="
echo ""

# Clear any existing service first
echo "🔄 Stopping any existing service..."
sudo systemctl stop db_apps_02 2>/dev/null || true
sudo systemctl disable db_apps_02 2>/dev/null || true

# Configuration
PROJECT_DIR="/home/ubuntu/db-apps/02"
VENV_DIR="$PROJECT_DIR/venv_02"
SERVICE_NAME="db_apps_02"
GUNICORN_PORT="8002"
NGINX_LOCATION="tasks"
API_BASE="http://localhost/$NGINX_LOCATION"
DIRECT_BASE="http://127.0.0.1:$GUNICORN_PORT"

echo "📋 Configuration:"
echo "  Project Dir: $PROJECT_DIR"
echo "  Service: $SERVICE_NAME"
echo "  Port: $GUNICORN_PORT"
echo "  API Base: $API_BASE"
echo "  Direct: $DIRECT_BASE"
echo ""

# 1. Go to project directory
cd "$PROJECT_DIR"
echo "📁 Working in: $(pwd)"

# 2. Create/update virtual environment
echo "🐍 Setting up Python virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "✅ Created virtual environment"
else
    echo "✅ Using existing virtual environment"
fi

source "$VENV_DIR/bin/activate"

# 3. Install Python dependencies
echo "📦 Installing Python packages..."
pip install --upgrade pip
pip install flask gunicorn pymysql python-dotenv

# 4. Ensure app.py is fixed
echo "🔧 Ensuring app.py is correct..."
if grep -q "data\['title'\]" app.py && grep -A5 "elif request.method == 'PUT':" app.py | grep -q "data\['title'\]"; then
    echo "⚠️  Fixing PUT endpoint in app.py..."
    # Backup original
    cp app.py app.py.backup.$(date +%Y%m%d_%H%M%S)
    
    # Apply fix to PUT endpoint
    sed -i '/elif request.method == .PUT.:/,/^[[:space:]]*elif request.method == .DELETE.:/ {
        /elif request.method == .PUT.:/ {
            n
            a\        data = request.json\
            a\        # First, get the current task\
            a\        cursor.execute(""\"\
            a\            SELECT * FROM tasks WHERE id = %s\
            a\        ""\"", (task_id,))\
            a\        current_task = cursor.fetchone()\
            a\        \
            a\        if not current_task:\
            a\            cursor.close()\
            a\            conn.close()\
            a\            return jsonify({\"error\": \"Task not found\"}), 404\
            a\        \
            a\        # Update only the fields that are provided in the request\
            a\        # Use current values for fields that are not provided\
            a\        cursor.execute(""\"\
            a\            UPDATE tasks SET \
            a\                title=%s, description=%s, category_id=%s, \
            a\                status=%s, priority=%s, due_date=%s\
            a\            WHERE id = %s\
            a\        ""\"", (\
            a\            data.get(\"title\", current_task[\"title\"]), \
            a\            data.get(\"description\", current_task[\"description\"]), \
            a\            data.get(\"category_id\", current_task[\"category_id\"]), \
            a\            data.get(\"status\", current_task[\"status\"]), \
            a\            data.get(\"priority\", current_task[\"priority\"]), \
            a\            data.get(\"due_date\", current_task[\"due_date\"]), \
            a\            task_id\
            a\        ))
            d
        }
        /data\[.title.\]/d
        /cursor.execute.*UPDATE tasks/,/task_id)/ {
            /cursor.execute.*UPDATE tasks/d
            /task_id)/d
        }
    }' app.py
    
    echo "✅ Fixed PUT endpoint in app.py"
else
    echo "✅ app.py looks good"
fi

# 5. Create systemd service
echo "⚙️  Creating systemd service..."
sudo tee /etc/systemd/system/db_apps_02.service > /dev/null << EOF
[Unit]
Description=Task Tracker API (Project 02)
After=network.target mariadb.service
Wants=mariadb.service

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/db-apps/02
Environment=PATH=/home/ubuntu/db-apps/02/venv_02/bin
ExecStart=/home/ubuntu/db-apps/02/venv_02/bin/gunicorn \
    --workers 3 \
    --bind 0.0.0.0:8002 \
    --access-logfile - \
    --error-logfile - \
    wsgi:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable db_apps_02

# 6. Configure Nginx
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/db_apps > /dev/null << EOF
server {
    listen 80;
    server_name _;

    # Project 01: Servers Manager
    location /servers {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Project 02: Task Tracker API
    location /tasks/ {
        proxy_pass http://127.0.0.1:8002/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Root redirect
    location / {
        return 200 'API Gateway\\n\\nAvailable APIs:\\n- /servers - Servers Manager\\n- /tasks   - Task Tracker';
        add_header Content-Type text/plain;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/db_apps /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
sudo nginx -t && sudo systemctl restart nginx

# 7. Start the service
echo "🚀 Starting service..."
sudo systemctl restart db_apps_02
sleep 3  # Give it time to start

# 8. Simple testing function
test_endpoint() {
    local name=$1
    local method=$2
    local url=$3
    local data=$4
    
    echo -n "Testing $name: "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    elif [ "$method" = "POST" ] || [ "$method" = "PUT" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null || echo "000")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" 2>/dev/null || echo "000")
    fi
    
    if [ "$response" = "200" ] || [ "$response" = "201" ]; then
        echo "✅ ($response)"
        return 0
    else
        echo "❌ ($response)"
        return 1
    fi
}

# 9. Run comprehensive tests
echo ""
echo "======================================="
echo "🧪 RUNNING TESTS"
echo "======================================="
echo ""

# Check service
echo "1. Service status:"
if sudo systemctl is-active --quiet db_apps_02; then
    echo "   ✅ Running"
else
    echo "   ❌ Not running"
    sudo systemctl status db_apps_02 --no-pager | head -10
    exit 1
fi

# Check port
echo "2. Port $GUNICORN_PORT:"
if sudo ss -tulpn | grep -q ":$GUNICORN_PORT"; then
    echo "   ✅ Listening"
else
    echo "   ❌ Not listening"
    exit 1
fi

# Test endpoints
echo ""
echo "3. API Endpoints:"

# Test direct connection first
echo "   Direct connection:"
test_endpoint "Health" "GET" "http://127.0.0.1:8002/health"
test_endpoint "Categories" "GET" "http://127.0.0.1:8002/categories"
test_endpoint "Tasks" "GET" "http://127.0.0.1:8002/tasks"

echo ""
echo "   Through Nginx:"
test_endpoint "Health" "GET" "http://localhost/tasks/health"
test_endpoint "Categories" "GET" "http://localhost/tasks/categories"
test_endpoint "Tasks" "GET" "http://localhost/tasks/tasks"

# Create a task
echo ""
echo "4. Creating test task:"
CREATE_DATA='{"title":"Test Task","description":"From deployment","category_id":1,"priority":"medium"}'
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$CREATE_DATA" "http://localhost/tasks/tasks")
task_id=$(echo "$response" | jq -r '.id' 2>/dev/null || echo "")
if [ -n "$task_id" ] && [ "$task_id" != "null" ]; then
    echo "   ✅ Task created (ID: $task_id)"
    
    # Test updates
    echo ""
    echo "5. Testing updates:"
    test_endpoint "Partial update" "PUT" "http://localhost/tasks/tasks/$task_id" '{"status":"in_progress"}'
    test_endpoint "Full update" "PUT" "http://localhost/tasks/tasks/$task_id" '{"title":"Updated","status":"done","priority":"high"}'
    test_endpoint "Delete" "DELETE" "http://localhost/tasks/tasks/$task_id"
else
    echo "   ❌ Failed to create task"
    echo "   Response: $response"
fi

echo ""
echo "======================================="
echo "🎉 DEPLOYMENT COMPLETE"
echo "======================================="
echo ""
echo "📋 Service Information:"
echo "   Name: db_apps_02"
echo "   Status: $(sudo systemctl is-active db_apps_02)"
echo "   Port: 8002"
echo ""
echo "🔗 Access URLs:"
echo "   Health:      http://localhost/tasks/health"
echo "   Categories:  http://localhost/tasks/categories"
echo "   Tasks:       http://localhost/tasks/tasks"
echo ""
echo "🛠️  Management:"
echo "   sudo systemctl status db_apps_02"
echo "   sudo journalctl -u db_apps_02 -f"
echo "   sudo systemctl restart db_apps_02"
echo ""
echo "======================================="
