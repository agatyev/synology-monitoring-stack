# Synology NAS Monitoring Stack

Минимальный рабочий стек для мониторинга Synology NAS:

- `snmp-exporter`
- `prometheus`
- `grafana`
- dashboard `14284` "Synology NAS Details"

Связка работает так:

`NAS -> SNMP -> snmp-exporter -> Prometheus -> Grafana`

## Что настроить перед запуском

### 1. Grafana пароль

```bash
cp .env.example .env
```

Поменять в `.env`:

```env
GF_ADMIN_PASSWORD=your_password
```

### 2. IP адрес NAS

В [prometheus/prometheus.yml](/home/kali/synology-monitoring-stack/prometheus/prometheus.yml#L12) сейчас стоит:

```yaml
      - targets: ["192.168.1.150"]
```

Если IP NAS другой, заменить его.

### 3. SNMP на NAS

В DSM:

1. `Control Panel -> Terminal & SNMP -> SNMP`
2. Включить `SNMPv1, SNMPv2c service`
3. Community: `public`

Если community будет не `public`, нужно поменять его в [snmp_exporter/snmp.yml](/home/kali/synology-monitoring-stack/snmp_exporter/snmp.yml#L1) в секции `public_v2`.

## Запуск

```bash
docker compose up -d
```

После старта:

- Grafana: `http://IP_ХОСТА:3000`
- Prometheus: `http://IP_ХОСТА:9090`

Логин Grafana по умолчанию:

- user: `admin`
- password: из `.env`

## Что должно быть в Grafana

Datasource:

- `Prometheus`

Dashboard:

- `Synology NAS Details`

Это официальный community dashboard Grafana Labs:

- [14284 Synology NAS Details](https://grafana.com/grafana/dashboards/14284-synology-nas-details/)

## Проверка

Открыть в Prometheus:

- `http://IP_ХОСТА:9090/targets`

Ожидаемо `UP`:

- `prometheus`
- `snmp-exporter`
- `synology-snmp`

Если `synology-snmp` в `DOWN`, проверить:

- SNMP точно включён на NAS
- community совпадает
- доступен UDP `161`
- IP NAS правильный

## Структура

```text
synology-monitoring-stack/
├── docker-compose.yml
├── .env.example
├── prometheus/
│   └── prometheus.yml
├── snmp_exporter/
│   └── snmp.yml
├── grafana/
│   ├── dashboards/
│   │   └── synology-nas-details.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboards.yml
│       └── datasources/
│           └── datasources.yml
└── data/
    ├── prometheus/
    └── grafana/
```

## Для Synology NAS

Если будешь запускать через Synology Container Manager:

1. Скопировать проект в папку вроде `/volume1/docker/monitoring`
2. Убедиться, что существуют:
   `data/prometheus`
   `data/grafana`
3. Создать Project из существующего `docker-compose.yml`
4. Запустить проект
