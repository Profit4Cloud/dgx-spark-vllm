# Shared observability

See the [root guide](../README.md) for volume migration, startup, profile
registration, and shutdown. External volume names are configured in `.env`;
model targets are discovered from `targets/*.yml`. This directory contains no
model-specific configuration.

Grafana provisions shared dashboards and registered profile dashboards from the
mounted `grafana/dashboards/` directory. Dashboard deletion is disabled to retain
historical views. The Prometheus datasource UID remains `prometheus`.

`grafana/grafana.ini` disables `kubernetesDashboards` for the pinned Grafana 12.2
release. Validation against a copy of the existing database showed stale
API content after file provisioning with that feature enabled; the legacy
dashboard path reflects registered source changes correctly. Dashboard UIDs,
credentials, and persistent data are retained.
