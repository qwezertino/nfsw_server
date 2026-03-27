# SBRW — Запуск сервера NFS World на Linux

## Конфигурация

| Параметр | Значение |
|---|---|
| База данных | `nfs_world` |
| Пользователь БД | `nfs_user` |
| Пароль БД | `qwerty123456` |
| Порт core-сервера | `4444` |
| Порт Race (UDP) | `9998` |
| Порт Freeroam (UDP) | `9999` |
| Порт Openfire (XMPP) | `5222` |
| Порт Openfire (панель) | `9090` |

---

## Шаг 1 — Установка зависимостей

```bash
sudo apt update
sudo apt install -y openjdk-11-jdk maven golang-go tmux default-mysql-server mysql-client
```

Проверить версии:
```bash
java -version   # должен быть 11.x
go version
mvn -version
tmux -V
```

---

## Шаг 2 — Создать базу данных и пользователя MySQL

```bash
sudo mysql <<'SQL'
CREATE DATABASE IF NOT EXISTS nfs_world   DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS openfire_nfs DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'nfs_user'@'localhost' IDENTIFIED BY 'qwerty123456';
GRANT ALL PRIVILEGES ON nfs_world.*    TO 'nfs_user'@'localhost';
GRANT ALL PRIVILEGES ON openfire_nfs.* TO 'nfs_user'@'localhost';
FLUSH PRIVILEGES;
SQL
```

> `openfire_nfs` пока создаётся пустой — схема будет заполнена Openfire при первом запуске через мастер настройки.

---

## Шаг 3 — Сборка всех компонентов

```bash
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/build.sh
```

Что соберётся (всё в `/home/qwezert/nfsw_server/sbrw/`):

| Путь | Описание |
|---|---|
| `sbrw/core/core.jar` | soapbox-race-core (Thorntail) |
| `sbrw/freeroam/freeroamd` | Freeroam UDP сервер (Go) |
| `sbrw/race/race.jar` | Race UDP сервер |
| `sbrw/openfire/` | Openfire 4.9.2 |
| `sbrw/openfire/plugins/restAPI.jar` | REST API плагин |
| `sbrw/openfire/plugins/nonSaslAuthentication.jar` | NonSASL Auth плагин |

> Первая сборка длится ~10–20 минут — Maven скачивает зависимости.

---

## Шаг 4 — Инициализация схемы базы данных (только первый раз)

```bash
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/build.sh --init-db
```

Импортирует SQL-схему и начальные данные в `nfs_world`, переименовывает все таблицы в ВЕРХНИЙ регистр (обязательно для корректной работы Hibernate на Linux).

---

## Шаг 5 — Первый запуск и мастер настройки Openfire

Запустить все компоненты:

```bash
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh
```

> Core-сервер упадёт при этом первом запуске — это нормально: он не может подключиться к Openfire, который ещё не настроен. Продолжаем.

Открыть в браузере:
```
http://<IP-сервера>:9090/setup/index.jsp
```

Пройти мастер:

1. **Language** → выбрать язык → `Continue`.

2. **Server Settings**:
   - `XMPP Domain Name` → **IP-адрес сервера** (например `192.168.1.10`)
   - `Server Host Name` → тот же IP
   - → `Continue`.

3. **Database Settings** → `Standard Database Connection` → `Continue`.

4. **Database Driver** → `MySQL`.

5. **Database URL**:
   ```
   jdbc:mysql://localhost:3306/openfire_nfs?rewriteBatchedStatements=true&characterEncoding=UTF-8&characterSetResults=UTF-8&serverTimezone=UTC
   ```
   - `Username`: `nfs_user`
   - `Password`: `qwerty123456`
   - → `Continue`.

6. **Profile Settings** → `Default` → `Continue`.

7. **Administrator Account** → задать email и пароль для панели → `Continue`.

8. `Login to the admin console`.

---

## Шаг 6 — Настройка Openfire в панели администратора

Войти: `admin` / пароль из шага 5.

### Отключить встроенную регистрацию
`Server Settings` → `Registration & Login` → отключить `Inband Account Registration` → `Save Settings`.

### Отключить сжатие
`Server Settings` → `Compression Settings` → оба поля `Not Available` → `Save Settings`.

### Включить и настроить REST API
`Server Settings` → `REST API (SBRW)`:
- Переключить в `Enabled`
- Метод аутентификации: `Secret key auth`
- В поле `Secret key` **ввести** тот токен, что будет использоваться (или запомнить сгенерированный)
- → `Save Settings`

> Токен должен совпадать со значением `OPENFIRE_TOKEN` в таблице `PARAMETER` базы `nfs_world`. Если используешь `configure.sh` — просто введи одно и то же значение и там, и там.

### Создать служебного XMPP-пользователя
Core-сервер подключается к Openfire как XMPP-клиент от имени пользователя `sbrw.engine.engine`, пароль которого равен значению `OPENFIRE_TOKEN`.

`Users/Groups` → `Users` → `Create New User`:
- **Username**: `sbrw.engine.engine`
- **Password**: значение `OPENFIRE_TOKEN` (по умолчанию `nfsw_secret_token`)
- → `Create User`.

> Без этого пользователя core упадёт с `SASLError: not-authorized`.

---

## Шаг 7 — Настройка параметров сервера

Запустить интерактивный скрипт конфигурации:

```bash
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/configure.sh
```

Скрипт спросит:
- **Server IP** — IP-адрес машины, который будет видеть клиент
- **Server port** — порт core (по умолчанию `4444`)
- **Openfire secret key** — токен из REST API (шаг 6)

Помимо обновления таблицы `PARAMETER` в `nfs_world`, скрипт также автоматически пропишет в `openfire_nfs`:
- `plugin.restapi.enabled = true`
- `adminConsole.access.allow-wildcards-in-excludes = true` (без этого REST API плагин не работает на Openfire 4.9.2)

---

## Шаг 8 — Открыть порты (если нужно)

```bash
sudo ufw allow 4444/tcp   # core-сервер
sudo ufw allow 5222/tcp   # XMPP (Openfire)
sudo ufw allow 9090/tcp   # Openfire панель (можно закрыть после настройки)
sudo ufw allow 9998/udp   # Race
sudo ufw allow 9999/udp   # Freeroam
```

---

## Шаг 9 — Полный перезапуск

```bash
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh --stop
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh
```

Следить за запуском core:
```bash
tmux attach -t sbrw
# Ctrl+b, 3 — переключиться на окно core
```

Когда появится строка **`Thorntail is Ready`** — сервер полностью запущен.

---

## Управление сервером

```bash
# Подключиться к логам
tmux attach -t sbrw

# Переключать окна внутри tmux: Ctrl+b, затем цифра
# Отсоединиться (не убивая): Ctrl+b, d
# Остановить всё:
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh --stop
```

| Окно tmux | Компонент | Лог |
|---|---|---|
| 0 | Openfire | `sbrw/logs/openfire.log` |
| 1 | Freeroam | `sbrw/logs/freeroam.log` |
| 2 | Race | `sbrw/logs/race.log` |
| 3 | Core | `sbrw/logs/core.log` |

---

## Подключение клиента

1. Скачать [SBRW Launcher](https://github.com/SoapboxRaceWorld/GameLauncher_NFSW/releases/latest).
2. Нажать `+` → ввести адрес: `http://<IP-сервера>:4444` → `OK`.
3. Перезапустить лаунчер, выбрать сервер, зарегистрироваться и войти.

---

## Обновление IP (после перезагрузки машины/WSL)

IP WSL меняется при каждом перезапуске. Повторно запустить:

```bash
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/configure.sh
# затем
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh --stop
bash /home/qwezert/nfsw_server/setting-up-sbrw/Files/start.sh
```

---

## Частые проблемы

**Core падает с `SASLError: not-authorized`**
- Пользователь `sbrw.engine.engine` не создан в Openfire, или его пароль не совпадает с `OPENFIRE_TOKEN`.
- Проверить: `mysql -u nfs_user -pqwerty123456 nfs_world -e "SELECT VALUE FROM PARAMETER WHERE NAME='OPENFIRE_TOKEN';"`

**Core падает с `HTTP 302 Found`**
- REST API плагин отключён или в `openfire_nfs` не прописаны нужные свойства.
- Запустить `configure.sh` повторно — он пропишет `plugin.restapi.enabled=true` и `adminConsole.access.allow-wildcards-in-excludes=true`.

**Порт 4444 не отвечает**
- Ждать строку `Thorntail is Ready` в окне 3 tmux — старт занимает ~1-2 минуты.
- Убедиться, что `SERVER_ADDRESS` совпадает с реальным IP.

**Openfire не стартует**
- Проверить, что база `openfire_nfs` существует и доступна пользователю `nfs_user`.

**Freeroam сразу падает**
- `config.toml` генерируется автоматически при первом запуске в `sbrw/freeroam/`. Если файл повреждён — удалить его.

**Пересобрать только core (быстрее)**
```bash
cd /home/qwezert/nfsw_server/soapbox-race-core
mvn clean package -q -DskipTests
cp target/core-thorntail.jar /home/qwezert/nfsw_server/sbrw/core/core.jar
```
