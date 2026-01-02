# Flask + MariaDB App 
Простое REST API на Flask с Gunicorn + Nginx + MariaDB для управления серверами. Развертывание на Ubuntu 24.04 через systemd.

## 🚀 Автоматическое развертывание

### Полная установка одним скриптом
```bash
chmod +x deploy.sh
./deploy.sh



Скрипт deploy.sh автоматически устанавливает:

Python 3.12 + виртуальное окружение

MariaDB (создает БД flaskapp_db и пользователя flaskapp)

Nginx (обратный прокси на порту 80)

Gunicorn (3 воркера на порту 8000)

Настраивает systemd сервис db_apps_01.service

Настраивает UFW firewall

После установки приложение будет доступно по:

Внутренний адрес: http://127.0.0.1:8000

Внешний адрес: http://ВАШ_IP/









📊 Статус сервисов

# Проверить статус Flask приложения
sudo systemctl status db_apps_01.service

# Проверить статус Nginx
sudo systemctl status nginx

# Проверить статус MariaDB
sudo systemctl status mariadb








📝 Логи

# Логи Flask/Gunicorn
sudo journalctl -u db_apps_01.service -f

# Логи ошибок Nginx
sudo tail -f /var/log/nginx/error.log

# Логи доступа Nginx
sudo tail -f /var/log/nginx/access.log





🛠 Ручная установка (устаревший способ)
Инициализация базы данных


mysql -uroot -p < init_db.sql





Запуск Gunicorn вручную

gunicorn --workers 3 --bind 0.0.0.0:8000 wsgi:app






Тестирование базы данных

# Проверить соединение
sudo mysql -u flaskapp -pflaskpass -e "SELECT 1;"

# Просмотреть данные
sudo mysql -u flaskapp -pflaskpass flaskapp_db -e 'SELECT * FROM servers;'







🔧 Управление сервисами

# Перезапустить Flask приложение
sudo systemctl restart db_apps_01.service

# Перезапустить Nginx
sudo systemctl restart nginx

# Перезапустить MariaDB
sudo systemctl restart mariadb

# Включить автозапуск
sudo systemctl enable db_apps_01.service
sudo systemctl enable nginx
sudo systemctl enable mariadb







🔐 Конфигурация базы данных
База данных: flaskapp_db

Пользователь: flaskapp

Пароль: flaskpass

Хост: localhost

Порт: 3306








🧪 Тестирование API

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





📁 Структура проекта

db-apps/01/
├── deploy.sh          # Скрипт автоматического развертывания
├── init_db.sql        # Исходная схема базы данных
├── clean_schema.sql   # Очищенная схема (создается скриптом)
├── requirements.txt   # Python зависимости
├── venv_01/          # Виртуальное окружение Python
├── wsgi.py           # Точка входа Flask приложения
└── README.md         # Эта документация









🔄 Обновление приложения

cd /home/ubuntu/db-apps/01

# Активировать виртуальное окружение
source venv_01/bin/activate

# Обновить зависимости
pip install -r requirements.txt

# Перезапустить сервис
sudo systemctl restart db_apps_01.service







🚨 Устранение неполадок
Если приложение не отвечает:
Проверьте статус сервисов:

sudo systemctl status db_apps_01.service
sudo systemctl status nginx





Проверьте логи:
sudo journalctl -u db_apps_01.service --no-pager | tail -20
sudo tail -20 /var/log/nginx/error.log


Проверьте порты:
sudo netstat -tulpn | grep -E ':80|:8000'



Проверьте firewall:
sudo ufw status


Если база данных недоступна:
# Проверить доступ к MySQL
sudo mysql -u flaskapp -pflaskpass -e "SHOW DATABASES;"

# Восстановить пользователя и БД
sudo mysql -u root <<EOF
DROP USER IF EXISTS 'flaskapp'@'localhost';
DROP DATABASE IF EXISTS flaskapp_db;
CREATE DATABASE flaskapp_db;
CREATE USER 'flaskapp'@'localhost' IDENTIFIED BY 'flaskpass';
GRANT ALL PRIVILEGES ON flaskapp_db.* TO 'flaskapp'@'localhost';
FLUSH PRIVILEGES;
EOF




Последнее обновление: $(date +%Y-%m-%d)
Развернуто на: Ubuntu 24.04





















































version --old

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
