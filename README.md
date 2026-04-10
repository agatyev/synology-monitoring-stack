# Synology NAS Monitoring Stack

A minimal working stack for monitoring a Synology NAS:

- `snmp-exporter`
- `node-exporter`
- `process-exporter`
- `prometheus`
- `grafana`
- dashboard `14284` "Synology NAS Details"

The stack works like this:

`NAS -> SNMP -> snmp-exporter -> Prometheus -> Grafana`

`host /proc + /sys -> node-exporter + process-exporter -> Prometheus -> Grafana`

## What to configure before startup

### 1. Grafana password

```bash
cp .env.example .env
```

Change this in `.env`:

```env
GF_ADMIN_PASSWORD=your_password
```

### 2. NAS IP address

The current target in [prometheus/prometheus.yml](prometheus/prometheus.yml) is:

```yaml
      - targets: ["192.168.1.150"]
```

Replace it if your NAS uses a different IP.

### 3. SNMP on the NAS

In DSM:

1. `Control Panel -> Terminal & SNMP -> SNMP`
2. Enable `SNMPv1, SNMPv2c service`
3. Community: `public`

If your community string is not `public`, update it in [snmp_exporter/snmp.yml](snmp_exporter/snmp.yml) under `public_v2`.

## Start

```bash
docker compose up -d
```

After startup:

- Grafana: `http://HOST_IP:3000`
- Prometheus: `http://HOST_IP:9090`

Default Grafana login:

- user: `admin`
- password: from `.env`

## What you should see in Grafana

Datasource:

- `Prometheus`

Dashboard:

- `Synology NAS Details`
- `Node Exporter Full`
- `Named processes`

This is the official Grafana Labs community dashboard:

- [14284 Synology NAS Details](https://grafana.com/grafana/dashboards/14284-synology-nas-details/)
- [1860 Node Exporter Full](https://grafana.com/grafana/dashboards/1860-node-exporter-full/)
- [249 Named processes](https://grafana.com/grafana/dashboards/249-named-processes/)

## Validation

Open this in Prometheus:

- `http://HOST_IP:9090/targets`

Expected `UP` targets:

- `prometheus`
- `snmp-exporter`
- `node`
- `process-exporter`
- `synology-snmp`

If `synology-snmp` is `DOWN`, check:

- SNMP is enabled on the NAS
- the community string matches
- UDP `161` is reachable
- the NAS IP is correct

## Structure

```text
synology-monitoring-stack/
├── docker-compose.yml
├── .env.example
├── prometheus/
│   └── prometheus.yml
├── process_exporter/
│   └── config.yml
├── snmp_exporter/
│   └── snmp.yml
├── grafana/
│   ├── dashboards/
│   │   ├── named-processes.json
│   │   ├── node-exporter-full.json
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

## For Synology NAS

If you want to run it with Synology Container Manager:

1. Copy the project into `/volume1/docker/monitoring`
2. Make sure these directories exist:
   `data/prometheus`
   `data/grafana`
3. Create a Project from the existing `docker-compose.yml`
4. Start the project

If DSM Firewall is enabled:

- allow `Grafana` in the firewall rules so port `3000` is reachable
