# Flask + MariaDB App 
Простое REST API на Flask с Gunicorn + Nginx + MariaDB для управления серверами. Развертывание на Ubuntu 24.04 через systemd.

## Запуск

```bash
mysql -uroot -p < init_db.sql

gunicorn --workers 3 --bind 0.0.0.0 wsgi:app
```

## Тестирование
```bash
# Список серверов
curl http://localhost/servers

# Добавить сервер
curl -X POST http://localhost/servers \
  -H "Content-Type: application/json" \
  -d '{"name":"api01","role":"api","os":"Ubuntu 24.04"}'

# Получить сервер
curl http://localhost/servers/1

# Удалить сервер
curl -X DELETE http://localhost/servers/1
```
