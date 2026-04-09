# Synology NAS Monitoring Stack

Полный стек мониторинга Synology NAS: метрики (SNMP), логи (syslog + Docker),
дашборды (Grafana), алерты (Telegram).

---

## Перед запуском: что заменить на свои значения

Нужно изменить **3 файла**, в каждом ровно одно место:

### 1. `.env` — пароль Grafana

```bash
cp .env.example .env
```

Открыть `.env` и заменить:

```env
GF_ADMIN_PASSWORD=your_password   # ← пароль для входа в Grafana
```

### 2. `prometheus/prometheus.yml` — IP адрес NAS (строка 25)

Найти и заменить IP на свой:

```yaml
      - targets: ["192.168.1.100"]    # ← IP вашего NAS
```

### 3. `alertmanager/alertmanager.yml` — Telegram (опционально)

Если нужны уведомления в Telegram — заменить в двух местах:

```yaml
      - bot_token: "YOUR_BOT_TOKEN"   # ← токен от @BotFather
        chat_id: 0                     # ← ваш chat_id (число)
```

Если Telegram не нужен — можно не трогать, стек запустится без него.

### 4. Путь Docker на Synology (если Docker не на volume1)

В `docker-compose.yml` по умолчанию указан `/volume1/@docker`.
Если Docker стоит на другом томе (volume2, volume3...) — заменить во всех местах:

```yaml
      - /volume1/@docker:/var/lib/docker:ro        # ← cadvisor
      - /volume1/@docker/containers:/var/lib/docker/containers:ro  # ← promtail
```

---

## Пошаговая настройка Synology DSM

### Шаг 1. Включить SNMP на NAS

SNMP — это то, через что собираются метрики NAS (CPU, RAM, диски, RAID, температура).

1. Открыть **Control Panel** (Панель управления)
2. Перейти в **Terminal & SNMP** (Терминал и SNMP)
3. Нажать вкладку **SNMP**
4. Поставить галочку **Enable SNMP service** (Включить службу SNMP)
5. Поставить галочку **SNMPv1, SNMPv2c service**
6. В поле **Community** ввести: `public`
   (или любое другое слово — тогда поменять его же в `snmp_exporter/snmp.yml` в поле `community`)
7. Нажать **Apply** (Применить)

### Шаг 2. Установить и настроить Log Center

Log Center — это пакет, который нужно установить отдельно. Через него NAS будет
отправлять системные логи (логины, ошибки, бэкапы, пакеты) в наш стек.

**Установка:**

1. Открыть **Package Center** (Центр пакетов)
2. В поиске набрать **Log Center**
3. Нажать **Install** (Установить)

**Настройка отправки логов:**

1. Открыть установленный **Log Center** (из главного меню DSM)
2. В левой панели нажать **Log Sending** (Отправка журналов)
3. Поставить галочку **Send logs to a syslog server** (Отправлять журналы на сервер syslog)
4. Заполнить поля:
   - **Server**: `127.0.0.1` (если стек запущен на самом NAS) или IP машины со стеком
   - **Port**: `1514`
   - **Transfer protocol**: **TCP**
   - **Log format**: **BSD (RFC 3164)** — выбрать этот формат
5. Нажать **Apply** (Применить)

### Шаг 3. Настроить Firewall (если включен)

Если файрвол на NAS включён, нужно разрешить порты для мониторинга.

1. Открыть **Control Panel** → **Security** (Безопасность) → **Firewall** (Брандмауэр)
2. Нажать **Edit Rules** (Редактировать правила) для активного профиля
3. Нажать **Create** (Создать) и добавить правила:

| Порты | Протокол | Источник | Действие | Зачем |
|-------|----------|----------|----------|-------|
| 161 | UDP | Подсеть 127.0.0.0/8 или локальная подсеть | Allow | SNMP-запросы от snmp_exporter |
| 1514 | TCP | Подсеть 127.0.0.0/8 или локальная подсеть | Allow | Syslog от NAS к Promtail |
| 3000 | TCP | Локальная подсеть | Allow | Доступ к Grafana |
| 9090 | TCP | Локальная подсеть | Allow | Доступ к Prometheus (опционально) |
| 9093 | TCP | Локальная подсеть | Allow | Доступ к Alertmanager (опционально) |

4. Убедиться что правила **Allow** стоят **выше** правила Deny All
5. Нажать **OK** → **Apply**

Если файрвол выключен — этот шаг можно пропустить.

### Шаг 4. Подготовить папки на NAS

1. Открыть **File Station**
2. Перейти в `docker/` на volume1 (или создать папку `docker` если её нет)
3. Создать папку `monitoring` внутри `docker/`
4. Загрузить в `/volume1/docker/monitoring/` всё содержимое этого проекта

Итоговая структура на NAS (папки `data/*` должны существовать — в репозитории они уже есть с `.gitkeep`):
```
/volume1/docker/monitoring/
├── docker-compose.yml
├── .env
├── data/
│   ├── prometheus/     # TSDB Prometheus
│   ├── loki/           # чанки логов
│   ├── grafana/        # SQLite Grafana
│   ├── alertmanager/   # silences
│   └── promtail/       # positions.yaml
├── prometheus/
├── alertmanager/
├── snmp_exporter/
├── promtail/
├── loki/
└── grafana/
```

Если копировали проект вручную и **нет** папок `data/prometheus`, `data/alertmanager` и т.д., создайте их в File Station или по SSH:
```bash
mkdir -p data/{prometheus,loki,grafana,alertmanager,promtail}
```
Иначе Container Manager выдаст: `Bind mount failed: '.../data/alertmanager'`.

### Шаг 5. Создать проект в Container Manager

1. Открыть **Container Manager** (из главного меню DSM)
2. В левой панели нажать **Project** (Проект)
3. Нажать **Create** (Создать)
4. **Project name**: `monitoring`
5. **Path**: нажать **Set path** и выбрать `/volume1/docker/monitoring`
6. **Source**: выбрать **Use existing docker-compose.yml**
   (Container Manager найдёт файл `docker-compose.yml` в указанной папке)
7. Нажать **Next**
8. Проверить что всё выглядит верно
9. Нажать **Done** (Готово)

Container Manager скачает образы и запустит все 7 контейнеров.

### Шаг 6. Проверить что всё работает

1. Открыть в браузере: **http://IP_NAS:3000**
2. Войти:
   - Login: `admin`
   - Password: то что указали в `.env` (по умолчанию `admin`)
3. В Grafana слева открыть **Dashboards** → папка **Synology**
4. Открыть **Synology NAS Overview** — через 1-2 минуты появятся данные
5. Открыть **Logs Explorer** — если Log Center настроен, появятся syslog-записи

**Проверка Prometheus** (опционально):
- Открыть **http://IP_NAS:9090** → Status → Targets
- Все targets должны быть в состоянии **UP** (зелёный)

**Если targets в состоянии DOWN:**
- `synology-snmp` DOWN → SNMP не включён или файрвол блокирует UDP 161
- `cadvisor` DOWN → проверить путь `/volume1/@docker` в docker-compose.yml
- `snmp-exporter` DOWN → проверить snmp.yml синтаксис

---

## Стек

| Компонент | Версия | Роль | Порт |
|-----------|--------|------|------|
| Prometheus | v3.10.0 | Хранение метрик (TSDB) | 9090 |
| SNMP Exporter | v0.29.0 | Сбор метрик NAS через SNMP | 9116 |
| cAdvisor | v0.51.0 | Метрики Docker-контейнеров | 8080 |
| Loki | 3.7.1 | Хранение логов | 3100 |
| Promtail | 3.6.10 | Сбор логов (syslog + Docker) | 1514, 9080 |
| Grafana | 12.4.2 | Визуализация и дашборды | 3000 |
| Alertmanager | v0.31.1 | Уведомления (Telegram) | 9093 |

> **Примечание**: Promtail объявлен EOL с марта 2026. Он продолжает работать,
> но не получает новых фич. В будущем рекомендуется мигрировать на Grafana Alloy.

## Архитектура

```
Synology NAS (DSM)
  ├── SNMP (UDP 161) ──────> snmp_exporter ──> Prometheus ──> Grafana
  ├── Syslog (TCP 1514) ──> Promtail ──────> Loki ─────────> Grafana
  └── Docker containers ──> cAdvisor ──────> Prometheus ──> Grafana
                          └> Promtail (logs) > Loki ──────> Grafana
                                                 │
                                          Prometheus ──> Alertmanager ──> Telegram
```

## Где хранятся данные

Все данные на диске NAS в `./data/` (или `VOLUME_BASE` из `.env`).

| Данные | Путь | Формат | Ретеншн |
|--------|------|--------|---------|
| **Метрики** | `data/prometheus/` | Prometheus TSDB (собственная БД) | 30 дней |
| **Логи** | `data/loki/` | Loki chunks + TSDB index | 7 дней |
| **Grafana** | `data/grafana/` | SQLite (встроенная БД) | Без лимита |
| **Alertmanager** | `data/alertmanager/` | nflog + silences | Без лимита |
| **Promtail** | `data/promtail/` | Файл позиций | Минимальный |

Никакой внешней базы данных не нужно. Prometheus и Loki используют собственные
файловые хранилища. Grafana хранит настройки в SQLite. Всё лежит на volume NAS.

## Какие логи собираются

| Источник | Метод | Что попадает |
|----------|-------|--------------|
| **Synology DSM** | Syslog TCP:1514 | Логины/логауты пользователей, системные события, ошибки пакетов, бэкапы, обновления, сетевые события, файловые операции |
| **Docker контейнеры** | Promtail docker_sd (auto-discovery) | Stdout/stderr **всех** запущенных контейнеров, автоматически |
| **Контейнер метрики** | cAdvisor → Prometheus | CPU, RAM, сеть, диск для каждого контейнера |

## Дашборды

Загружаются автоматически при первом запуске:

- **Synology NAS Overview** — статус, температура, CPU, RAM, диски, RAID, Storage IO, сеть
- **Docker Containers** — CPU/RAM/сеть для каждого контейнера + логи
- **Logs Explorer** — syslog NAS + логи контейнеров, фильтр по severity/app/container

Дополнительно можно импортировать community-дашборды из Grafana Labs:
- ID **14284** — Synology NAS Details
- ID **18643** — Synology SNMP

## Алерты

| Алерт | Условие | Severity |
|-------|---------|----------|
| SynologyTargetDown | NAS недоступен > 3 мин | critical |
| SynologySystemFailed | Статус системы != Normal | critical |
| SynologyHighCPU | CPU > 90% за 5 мин | warning |
| SynologyHighMemory | RAM > 90% за 5 мин | warning |
| SynologyHighTemperature | Система > 60°C | warning |
| SynologyPowerFailed | Питание != Normal | critical |
| SynologyFanFailed | Вентилятор != Normal | critical |
| SynologyDiskTemperatureHigh | Диск > 50°C | warning |
| SynologyDiskTemperatureCritical | Диск > 60°C | critical |
| SynologyDiskFailed | Статус диска != Normal | critical |
| SynologyRaidDegraded | RAID != Normal | critical |
| SynologyVolumeSpaceLow | Том > 85% заполнен | warning |
| SynologyVolumeSpaceCritical | Том > 95% заполнен | critical |
| SynologyUPSLowBattery | Заряд ИБП < 30% | critical |
| SynologyUPSHighLoad | Нагрузка ИБП > 80% | warning |
| ContainerHighCPU | Контейнер CPU > 80% | warning |
| ContainerHighMemory | Контейнер RAM > 90% лимита | warning |

### Настройка Telegram-уведомлений

1. Написать [@BotFather](https://t.me/BotFather) в Telegram → `/newbot` → следовать инструкциям → получить **токен**
2. Добавить созданного бота в нужный чат (группу) или написать ему лично
3. Написать боту любое сообщение
4. Открыть в браузере: `https://api.telegram.org/bot<ТОКЕН>/getUpdates`
5. В ответе JSON найти поле `"chat":{"id": ЧИСЛО}` — это ваш **chat_id**
6. Вписать токен и chat_id в `alertmanager/alertmanager.yml` (в два места: critical и warning)

## SNMP: что мониторится

Метрики по Synology MIB (`1.3.6.1.4.1.6574`) + стандартные MIB:

- **System**: статус, температура, питание, вентиляторы, модель, версия DSM, обновления
- **CPU**: user / system / idle
- **Memory**: total / available / buffer / cached
- **Load Average**: 1 / 5 / 15 минут
- **Disk**: статус, температура, модель, тип — по каждому bay
- **RAID**: статус, имя, свободное/общее место
- **Storage IO**: чтение/запись байт, IOPS, load average по каждому диску
- **Space IO**: чтение/запись по каждому volume
- **Network**: трафик по интерфейсам, статус, скорость (64-bit счётчики)
- **Host Resources**: использование разделов (hrStorage)
- **UPS**: модель, статус, нагрузка, заряд батареи

## Структура проекта

```
synology-monitoring-stack/
├── docker-compose.yml              # 7 сервисов, пиннированные версии
├── .env.example                    # Шаблон переменных
├── .env                            # Ваши настройки (в .gitignore)
├── prometheus/
│   ├── prometheus.yml              # Scrape: SNMP + cAdvisor
│   └── alerts.yml                  # 17 правил алертов
├── alertmanager/
│   └── alertmanager.yml            # Telegram-роутинг
├── snmp_exporter/
│   └── snmp.yml                    # Synology SNMP-модуль
├── promtail/
│   └── promtail.yml                # Syslog-приёмник + Docker SD
├── loki/
│   └── loki.yml                    # Файловое хранилище логов
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml     # Prometheus + Loki + Alertmanager
│   │   └── dashboards/
│   │       └── dashboards.yml      # Dashboard provider
│   └── dashboards/
│       ├── synology-overview.json  # NAS метрики
│       ├── docker-containers.json  # Контейнеры + логи
│       └── logs-explorer.json      # Все логи
└── data/                           # Персистентные данные (в .gitignore)
    ├── prometheus/
    ├── loki/
    ├── grafana/
    ├── alertmanager/
    └── promtail/
```

## Обслуживание

```bash
# Логи стека
docker compose logs -f --tail=50

# Остановка
docker compose down

# Обновление (проверить release notes перед обновлением!)
docker compose pull && docker compose up -d

# Проверить конфиг Prometheus
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Проверить правила алертов
docker compose exec prometheus promtool check rules /etc/prometheus/alerts.yml
```

## Ретеншн

| Компонент | Параметр | Где менять | По умолчанию |
|-----------|----------|------------|--------------|
| Prometheus | `PROMETHEUS_RETENTION` | `.env` | 30 дней |
| Loki | `retention_period` | `loki/loki.yml` | 168h (7 дней) |

Увеличивать с учётом свободного места на volume NAS.
Примерный расход: ~50-100 МБ/день для Prometheus, ~10-50 МБ/день для Loki
(зависит от количества контейнеров и активности логов).

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `Bind mount failed: '.../data/alertmanager'` (или другой каталог в `data/`) | На хосте нет этой папки. Создайте: `mkdir -p data/{prometheus,loki,grafana,alertmanager,promtail}` в каталоге проекта, либо возьмите актуальный репозиторий с папками `data/*/.gitkeep` |
| Grafana не открывается (порт 3000) | Проверить `docker compose ps` — все ли контейнеры running |
| SNMP target DOWN | 1) Проверить SNMP включён в DSM. 2) Проверить community string совпадает. 3) Firewall: UDP 161 |
| Нет логов в Logs Explorer | 1) Установлен ли Log Center? 2) Настроена ли Log Sending на TCP:1514? 3) Firewall: TCP 1514 |
| cAdvisor ошибки | Проверить что путь `/volume1/@docker` существует. Попробовать `ls /volume1/@docker/` через SSH |
| Логи контейнеров пустые | Проверить что Docker socket доступен: `/var/run/docker.sock` |
| Alertmanager не шлёт в Telegram | Проверить bot_token и chat_id в alertmanager.yml. Бот должен быть в чате |
| Ошибка permission denied | Контейнеры Prometheus/Loki/Grafana запускаются с `user: "0"` (root). Если проблема — проверить права на папку data/ |
