from flask import Flask, jsonify, request
import pymysql
import os
from datetime import datetime
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DB_CONFIG = {
    'user': 'taskapp',
    'password': 'taskpass123',
    'host': 'localhost',
    'database': 'task_tracker',
    'port': 3306
}

def init_database():
    """Initialize database - but don't crash if not accessible"""
    try:
        conn = pymysql.connect(**DB_CONFIG)
        conn.close()
        logger.info("\u2705 Task Tracker \u0411\u0414 \u0433\u043e\u0442\u043e\u0432\u0430")
        return True
    except pymysql.err.OperationalError as e:
        logger.warning(f"\u26a0\ufe0f Database not ready: {e}")
        logger.info("Database will be initialized on first API call")
        return False
    except Exception as e:
        logger.error(f"\u274c Database error: {e}")
        return False

def get_db():
    """Get database connection with retry logic"""
    try:
        return pymysql.connect(**DB_CONFIG)
    except pymysql.err.OperationalError:
        # Try to create database on first connection failure
        logger.info("\U0001f504 Attempting to initialize database...")
        try:
            # Try root connection (might not have password)
            root_conn = pymysql.connect(
                host='localhost', user='root',
                password='',  # Empty password for default MariaDB install
                port=3306, autocommit=True
            )
            root_cursor = root_conn.cursor()
            
            # Create database and user
            root_cursor.execute("CREATE DATABASE IF NOT EXISTS task_tracker")
            root_cursor.execute("CREATE USER IF NOT EXISTS 'taskapp'@'localhost' IDENTIFIED BY 'taskpass123'")
            root_cursor.execute("GRANT ALL PRIVILEGES ON task_tracker.* TO 'taskapp'@'localhost'")
            root_cursor.execute("FLUSH PRIVILEGES")
            root_conn.close()
            
            # Create tables
            conn = pymysql.connect(**DB_CONFIG)
            cursor = conn.cursor()
            
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS categories (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL UNIQUE,
                    color VARCHAR(7) DEFAULT '#007bff'
                )
            """)
            
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS tasks (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    description TEXT,
                    category_id INT,
                    status ENUM('todo', 'in_progress', 'done') DEFAULT 'todo',
                    priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
                    due_date DATE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (category_id) REFERENCES categories(id)
                )
            """)
            
            # Insert sample categories
            cursor.executemany(
                "INSERT IGNORE INTO categories (name, color) VALUES (%s, %s)",
                [
                    ('Work', '#dc3545'),
                    ('Personal', '#28a745'),
                    ('Urgent', '#ffc107')
                ]
            )
            
            conn.commit()
            conn.close()
            logger.info("\u2705 Task Tracker \u0411\u0414 \u0438\u043d\u0438\u0446\u0438\u0430\u043b\u0438\u0437\u0438\u0440\u043e\u0432\u0430\u043d\u0430!")
            return pymysql.connect(**DB_CONFIG)
        except Exception as e:
            logger.error(f"\u274c Failed to initialize database: {e}")
            raise

# Don't initialize on import - do it lazily on first request
# init_database()  # REMOVED - this was causing the crash

@app.route('/')
def api_root():
    """Root endpoint with API documentation"""
    return jsonify({
        "api": "Task Tracker API",
        "version": "1.0",
        "status": "operational",
        "description": "A simple task management system with categories and priorities",
        "database": "MariaDB/MySQL",
        "endpoints": {
            "health": "/health",
            "categories": "/categories",
            "tasks": {
                "list_create": "/tasks (GET, POST)",
                "detail_update_delete": "/tasks/<id> (GET, PUT, DELETE)"
            }
        },
        "filters": {
            "status": "?status=todo|in_progress|done",
            "category": "?category=<id>",
            "priority": "?priority=low|medium|high"
        },
        "example_usage": {
            "create_task": {
                "method": "POST /tasks",
                "body": {
                    "title": "Task title",
                    "description": "Optional description",
                    "category_id": 1,
                    "status": "todo",
                    "priority": "medium",
                    "due_date": "2024-12-31"
                }
            },
            "update_task": {
                "method": "PUT /tasks/1",
                "body": {
                    "title": "Updated title",
                    "status": "in_progress"
                }
            }
        }
    })

@app.route('/health', methods=['GET'])
def health():
    try:
        conn = get_db()
        conn.close()
        return jsonify({'status': 'healthy', 'service': 'task_tracker'})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

@app.route('/tasks', methods=['GET', 'POST'])
def tasks():
    conn = get_db()
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    
    if request.method == 'POST':
        data = request.json
        cursor.execute("""
            INSERT INTO tasks (title, description, category_id, status, priority, due_date)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            data['title'], data.get('description'), data.get('category_id'),
            data.get('status', 'todo'), data.get('priority', 'medium'), data.get('due_date')
        ))
        conn.commit()
        task_id = cursor.lastrowid
        cursor.close()
        conn.close()
        return jsonify({'id': task_id, 'status': 'created'}), 201
    
    # GET - фильтры
    status = request.args.get('status')
    category = request.args.get('category')
    priority = request.args.get('priority')
    
    query = """
        SELECT t.*, c.name as category_name, c.color
        FROM tasks t 
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE 1=1
    """
    params = []
    
    if status:
        query += " AND t.status = %s"
        params.append(status)
    if category:
        query += " AND c.id = %s"
        params.append(int(category))
    if priority:
        query += " AND t.priority = %s"
        params.append(priority)
    
    query += " ORDER BY t.created_at DESC"
    
    cursor.execute(query, params)
    tasks = [dict(row) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(tasks)

@app.route('/tasks/<int:task_id>', methods=['GET', 'PUT', 'DELETE'])
def task_detail(task_id):
    conn = get_db()
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    
    if request.method == 'GET':
        cursor.execute("""
            SELECT t.*, c.name as category_name, c.color
            FROM tasks t LEFT JOIN categories c ON t.category_id = c.id
            WHERE t.id = %s
        """, (task_id,))
        task = cursor.fetchone()
        cursor.close()
        conn.close()
        return jsonify(dict(task)) if task else (jsonify({'error': 'not found'}), 404)
    
    elif request.method == 'PUT':
        data = request.json
        # First, get the current task
        cursor.execute("""
            SELECT * FROM tasks WHERE id = %s
        """, (task_id,))
        current_task = cursor.fetchone()
        
        if not current_task:
            cursor.close()
            conn.close()
            return jsonify({'error': 'Task not found'}), 404
        
        # Update only the fields that are provided in the request
        # Use current values for fields that are not provided
        cursor.execute("""
            UPDATE tasks SET 
                title=%s, description=%s, category_id=%s, 
                status=%s, priority=%s, due_date=%s
            WHERE id = %s
        """, (
            data.get('title', current_task['title']), 
            data.get('description', current_task['description']), 
            data.get('category_id', current_task['category_id']), 
            data.get('status', current_task['status']), 
            data.get('priority', current_task['priority']), 
            data.get('due_date', current_task['due_date']), 
            task_id
        ))
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({'status': 'updated'})
    
    elif request.method == 'DELETE':
        cursor.execute("DELETE FROM tasks WHERE id = %s", (task_id,))
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({'status': 'deleted'})

@app.route('/categories', methods=['GET'])
def categories():
    conn = get_db()
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    cursor.execute("SELECT * FROM categories ORDER BY name")
    cats = [dict(row) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(cats)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

