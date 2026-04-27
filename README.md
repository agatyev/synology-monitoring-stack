# Synology NAS Monitoring

Simple monitoring for Synology NAS.

It uses Grafana, Prometheus, snmp-exporter, and process-exporter.

It has 2 dashboards:

- Synology NAS Details
- NAS Applications

## Need

- Synology DSM 7.3+
- Container Manager
- SNMP enabled on Synology

## Install

Edit `prometheus/prometheus.yml`.

Change this IP to your NAS IP:

```yaml
targets: ["192.168.1.150"]
```

On Synology: Control Panel -> Terminal & SNMP -> enable SNMP -> community: `public`.

In File Station, open the `docker` shared folder.

Create a folder:

```text
monitoring
```

Copy this project into:

```text
/volume1/docker/monitoring
```

Open Container Manager.

Create a new project from this folder:

```text
/volume1/docker/monitoring
```

## Login

`.env` is optional.

Grafana login is:

- user: `admin`
- password: `admin`

Grafana will ask you to set a new password.

## Open

Open Grafana:

```text
http://NAS_IP:3000
```

Only Grafana port `3000` is open.

Prometheus is used inside Docker.
