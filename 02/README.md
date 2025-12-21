# Task Tracker API
REST API для управления задачами с автоматической инициализацией MariaDB.

## Запуск
```bash
gunicorn --workers 3 --bind 0.0.0.0 wsgi:app
```

## Тестирование
```bash
# Healthcheck
curl http://localhost/health

# Категории
curl http://localhost/categories

# Задачи (все)
curl http://localhost/tasks

# Фильтры
curl "http://localhost/tasks?status=todo&priority=high"

# Создать задачу
curl -X POST http://localhost/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Deploy monitoring",
    "description": "Prometheus + Grafana setup",
    "category_id": 1,
    "status": "in_progress",
    "priority": "high",
    "due_date": "2025-12-25"
  }'

# Получить задачу
curl http://localhost/tasks/1

# Обновить
curl -X PUT http://localhost/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "done", "priority": "low"}'

# Удалить
curl -X DELETE http://localhost/tasks/1

```
