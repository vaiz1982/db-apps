from flask import Flask, jsonify, request
import mariadb
import os

app = Flask(__name__)

DB_CONFIG = {
    'user': os.getenv('DB_USER', 'flaskapp'),
    'password': os.getenv('DB_PASS', 'flaskpass'),
    'host': 'localhost',
    'database': 'flaskapp_db',
    'port': 3306
}

def get_db_connection():
    return mariadb.connect(**DB_CONFIG)

@app.route('/servers', methods=['GET', 'POST'])
def servers():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    if request.method == 'POST':
        data = request.json
        cursor.execute(
            "INSERT INTO servers (name, role, os) VALUES (?, ?, ?)",
            (data['name'], data['role'], data['os'])
        )
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({'status': 'created'}), 201
    
    cursor.execute("SELECT id, name, role, os FROM servers")
    servers = [{'id': row[0], 'name': row[1], 'role': row[2], 'os': row[3]} 
               for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return jsonify(servers)

@app.route('/servers/<int:server_id>', methods=['GET', 'DELETE'])
def server_detail(server_id):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    if request.method == 'DELETE':
        cursor.execute("DELETE FROM servers WHERE id = ?", (server_id,))
        conn.commit()
        cursor.close()
        conn.close()
        return jsonify({'status': 'deleted'})
    
    cursor.execute("SELECT id, name, role, os FROM servers WHERE id = ?", (server_id,))
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    
    if row:
        return jsonify({'id': row[0], 'name': row[1], 'role': row[2], 'os': row[3]})
    return jsonify({'error': 'not found'}), 404

if __name__ == '__main__':
    app.run(debug=True)

