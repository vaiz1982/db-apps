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
    """Автоинициализация БД на первом запуске"""
    try:
        conn = pymysql.connect(**DB_CONFIG)
        conn.close()
        logger.info("✅ Task Tracker БД готова")
        return True
    except pymysql.err.OperationalError:
        logger.info("🔄 Инициализация Task Tracker БД...")
        
        # Root подключение (Unix socket)
        root_conn = pymysql.connect(
            host='localhost', user='root', 
            password=os.getenv('DB_ROOT_PASS', ''),
            port=3306, autocommit=True
        )
        root_cursor = root_conn.cursor()
        
        # Создаем БД и пользователя
        root_cursor.execute("CREATE DATABASE IF NOT EXISTS task_tracker")
        root_cursor.execute("CREATE USER IF NOT EXISTS 'taskapp'@'localhost' IDENTIFIED BY 'taskpass123'")
        root_cursor.execute("GRANT ALL PRIVILEGES ON task_tracker.* TO 'taskapp'@'localhost'")
        root_cursor.execute("FLUSH PRIVILEGES")
        root_conn.close()
        
        # App БД - создаем таблицы
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
        
        # Тестовые категории
        cursor.executemany(
            "INSERT IGNORE INTO categories (name, color) VALUES (%s, %s)",
            [
                ('Work', '#dc3545'),
                ('Personal', '#28a745'),
                ('Urgent', '#ffc107')
            ]
        )
        
        # Тестовые задачи
        cursor.executemany("""
            INSERT IGNORE INTO tasks (title, description, category_id, status, priority, due_date) 
            VALUES (%s, %s, %s, %s, %s, %s)
        """, [
            ('Setup monitoring', 'Configure Prometheus + Grafana', 1, 'todo', 'high', '2025-12-25'),
            ('Review PRs', 'Code review for team', 1, 'in_progress', 'medium', None),
            ('Buy groceries', 'Milk, bread, eggs', 2, 'done', 'low', '2025-12-20')
        ])
        
        conn.commit()
        conn.close()
        logger.info("✅ Task Tracker БД инициализирована!")
        return True

def get_db():
    return pymysql.connect(**DB_CONFIG)

# Инициализация при старте
init_database()

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
        cursor.execute("""
            UPDATE tasks SET 
                title=%s, description=%s, category_id=%s, 
                status=%s, priority=%s, due_date=%s
            WHERE id = %s
        """, (
            data['title'], data.get('description'), data.get('category_id'),
            data.get('status', 'todo'), data.get('priority', 'medium'), 
            data.get('due_date'), task_id
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

