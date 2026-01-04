# Task Tracker API
A production-ready REST API for task management with automatic MariaDB initialization, comprehensive testing, and deployment automation.

## 🚀 Features

- **RESTful API** - Full CRUD operations for tasks and categories
- **Automatic Database Setup** - Self-initializing MariaDB database
- **Partial Update Support** - PUT endpoint supports updating individual fields
- **Production Ready** - Systemd service, Nginx reverse proxy, firewall configuration
- **Comprehensive Testing** - Built-in deployment testing for all endpoints
- **Filtering** - Filter tasks by status, category, or priority
- **Environment Configuration** - `.env` based configuration

## 📋 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health check |
| GET | `/categories` | List all categories |
| GET | `/tasks` | List all tasks (with filters) |
| POST | `/tasks` | Create a new task |
| GET | `/tasks/{id}` | Get specific task |
| PUT | `/tasks/{id}` | Update task (supports partial updates) |
| DELETE | `/tasks/{id}` | Delete task |

### 🔍 Filter Parameters for GET `/tasks`
- `?status=todo|in_progress|done`
- `?category=1` (category ID)
- `?priority=low|medium|high`

## 🛠️ Quick Start

### 1. Clone and Deploy
```bash
# Clone the repository
git clone <your-repo-url>
cd db-apps/02

# Make deploy script executable
chmod +x deploy-02.sh

# Run deployment
./deploy-02.sh




2. Manual Setup
# Create virtual environment
python3 -m venv venv_02
source venv_02/bin/activate

# Install dependencies
pip install flask gunicorn pymysql python-dotenv

# Configure environment
cp .env.example .env
nano .env  # Edit with your settings

# Run with Gunicorn
gunicorn --workers 3 --bind 0.0.0.0:8002 --access-logfile - --error-logfile - wsgi:app




📁 Project Structure

02/
├── app.py                 # Main Flask application
├── wsgi.py               # Gunicorn entry point
├── deploy-02.sh          # Complete deployment script
├── requirements.txt      # Python dependencies
├── .env.example          # Environment configuration template
├── .env                  # Environment variables (local, not in git)
├── .gitignore           # Git ignore rules
└── README.md            # This file





🔧 Configuration
Environment Variables (.env)

# Database Configuration
DB_NAME=task_tracker
DB_USER=taskapp
DB_PASSWORD=your_secure_password
DB_HOST=localhost
DB_PORT=3306
DB_ROOT_PASS=             # Optional, for root database initialization

# Flask/Gunicorn
FLASK_ENV=production
GUNICORN_WORKERS=3
GUNICORN_PORT=8002
SECRET_KEY=your-secret-key-here






Database Schema
The API automatically creates:

categories table with id, name, color

tasks table with id, title, description, category_id, status, priority, due_date, created_at

🧪 Testing
Manual Testing

# Health check
curl http://localhost/tasks/health

# List categories
curl http://localhost/tasks/categories

# List all tasks
curl http://localhost/tasks/tasks

# Filter tasks
curl "http://localhost/tasks/tasks?status=done&priority=high"

# Create task
curl -X POST http://localhost/tasks/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Deploy monitoring",
    "description": "Prometheus + Grafana setup",
    "category_id": 1,
    "priority": "high"
  }'

# Get specific task
curl http://localhost/tasks/tasks/1

# Partial update (only change status)
curl -X PUT http://localhost/tasks/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "in_progress"}'

# Full update
curl -X PUT http://localhost/tasks/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated title",
    "status": "done",
    "priority": "low"
  }'

# Delete task
curl -X DELETE http://localhost/tasks/tasks/1






Automated Testing
The deployment script includes comprehensive testing:




🚀 Production Deployment
What the Deployment Script Does:
System Updates - Updates Ubuntu packages

Dependencies - Installs Python, MariaDB, Nginx

Virtual Environment - Creates Python virtual environment

Database Setup - Creates database, user, and tables

Service Configuration - Creates systemd service

Nginx Proxy - Sets up reverse proxy with /tasks/ path

Firewall - Configures UFW firewall

Comprehensive Testing - Tests all API endpoints

Health Monitoring - Sets up service monitoring






Management Commands

# Service management
sudo systemctl status db_apps_02
sudo systemctl restart db_apps_02
sudo systemctl stop db_apps_02

# View logs
sudo journalctl -u db_apps_02 -f
sudo tail -f /var/log/nginx/error.log

# Database access
sudo mysql -u taskapp -p task_tracker






🔄 API Response Examples
Create Task (POST /tasks)

{
  "id": 5,
  "status": "created"
}





🐛 Troubleshooting
Common Issues:
"502 Bad Gateway" from Nginx

# Check if service is running
sudo systemctl status db_apps_02

# Check Nginx configuration
sudo nginx -t
sudo systemctl restart nginx

# Test direct connection
curl http://127.0.0.1:8002/health








Database Connection Failed
# Test database connection
sudo mysql -u taskapp -p -e "SELECT 'Connected'"

# Check database exists
sudo mysql -e "SHOW DATABASES LIKE 'task_tracker'"









Summary of README updates:
✅ Comprehensive documentation - Clear instructions for all features

✅ API Reference - All endpoints documented with examples

✅ Deployment Guide - Both quick start and detailed setup

✅ Configuration - Environment variables and database schema

✅ Testing Section - Manual and automated testing

✅ Production Setup - Management commands and monitoring

✅ Troubleshooting - Common issues and solutions

✅ Partial Updates Highlight - Specifically documents the PUT fix

✅ Response Examples - Shows expected JSON responses

✅ Development Guide - For contributors

Your repository now has:

✅ Working code (app.py with PUT fix)

✅ Deployment script (deploy-02.sh)

✅ Configuration (.env.example)

✅ Documentation (README.md)

✅ Ignore rules (.gitignore)

✅ Dependencies (requirements.txt)



OEF
