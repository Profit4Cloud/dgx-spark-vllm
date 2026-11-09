# DGX Spark vLLM

Independent vLLM deployment profiles share one persistent observability stack:
Prometheus, Grafana, Phoenix, node-exporter, and DCGM exporter. Images are pinned;
all published ports bind to `127.0.0.1`. Model performance settings are unchanged.

```text
observability/
  compose.yaml, prometheus.yml, .env.example
  targets/                         # registered targets (generated, ignored)
  grafana/provisioning/
  grafana/dashboards/               # host + generic vLLM dashboards
    profiles/                      # registered specialized dashboards (ignored)
qwen3.6-solo/
  compose.yaml, targets.yml, opencode/
qwen3.6+3.8/
  compose.yaml, targets.yml, dashboards/, opencode/
scripts/profile.sh                 # register/unregister monitoring files
```

## Preserve an existing installation

Before starting the new stack, stop any old observability containers using their
original Compose file/project, **without `-v`**. Stop old model containers too if
migrating their Compose project. Keep the original `.env` and take your normal
backups. Do not run two observability stacks against the same volumes.

Inspect the volume names rather than assuming the new project owns your data.
If `observability/.env` already exists, edit it in place instead of copying over
it:

```bash
docker volume ls
docker volume inspect <existing-prometheus-volume> <existing-grafana-volume> <existing-phoenix-volume>
cp observability/.env.example observability/.env
chmod 600 observability/.env
```

Set `PROMETHEUS_VOLUME`, `GRAFANA_VOLUME`, and `PHOENIX_VOLUME` to the exact
existing volume names. Reuse your Grafana password from the previous `.env`.
Existing Grafana database credentials remain authoritative; this environment
variable initializes new databases and does not reset an existing password.

The Compose volumes are **external**: Docker must find them, and Compose cannot
silently create empty replacements or delete them on `down`. Grafana dashboard
UIDs and the Prometheus datasource UID are retained. The comparison dashboard
also includes older series that predate the `profile` label. Phoenix retains its
original `/data` mount and working directory.

For a **fresh installation only**, use the names in `.env.example`, set a Grafana
password, and create those volumes once:

```bash
docker volume create dgx-vllm-prometheus-data
docker volume create dgx-vllm-grafana-data
docker volume create dgx-vllm-phoenix-data
```

## Start observability

Run commands from the repository root:

```bash
docker compose -f observability/compose.yaml config --quiet
docker compose -f observability/compose.yaml up -d
```

This creates `dgx-observability`. Model profiles join it as an external network.
Observability starts with no active model targets; exporters are always scraped.
Persistent data belongs to the external volumes, independently of model projects.

## Activate a profile

Models require an NVIDIA GPU, NVIDIA Container Toolkit, and model weights already
in `~/.cache/huggingface/hub` because offline loading is enabled.

```bash
docker compose -f qwen3.6-solo/compose.yaml up -d --wait --wait-timeout 900
./scripts/profile.sh register qwen3.6-solo
```

To use both models, substitute `qwen3.6+3.8`. Its Qwen3.8 service waits for
Qwen3.6 to become healthy before loading. Qwen3.8 has no readiness healthcheck;
before registering the dual profile, wait for
`curl --fail http://127.0.0.1:8000/health` to succeed (or use its configured host
port). Follow loading with `docker compose -f <profile>/compose.yaml logs -f`.
Register only when models are ready to avoid startup scrape failures.

Registration atomically copies `<profile>/targets.yml` into the directory already
mounted by Prometheus. Files are discovered and removed automatically, without
restarting Prometheus or editing its configuration. Re-register after editing a
profile's targets or optional `dashboards/*.json`. Grafana polls for dashboard
changes every 15 seconds; specialized dashboards remain after unregistration so
historical views remain available. UI edits to provisioned dashboards can be
saved, but re-registering their source can overwrite those edits.

## Concurrent profiles and switching

Each profile has a unique Compose project and DNS aliases. Scrape definitions use
those aliases and internal model ports, so changing host ports does not change
targets. Default API ports remain 8001 for Qwen3.6 and 8000 for Qwen3.8.
For example, keep the dual profile running and start solo on port 8002:

```bash
QWEN36_PORT=8002 docker compose -f qwen3.6-solo/compose.yaml up -d --wait --wait-timeout 900
./scripts/profile.sh register qwen3.6-solo
```

Set `QWEN36_PORT`/`QWEN38_PORT` in each profile's `.env` for persistent overrides.
Resources must accommodate every active model; this change does not increase GPU
memory allocations or otherwise tune inference settings. Use the generic vLLM
dashboard's **Deployment profile** and **Model** selectors to compare profiles.

To switch instead, unregister the old profile, stop it, and activate the next:

```bash
./scripts/profile.sh unregister qwen3.6-solo
docker compose -f qwen3.6-solo/compose.yaml down
docker compose -f qwen3.6+3.8/compose.yaml up -d --wait --wait-timeout 900
# Wait for the second model's /health before registering.
./scripts/profile.sh register qwen3.6+3.8
```

Always unregister before stopping a model profile. This removes its active
scrape targets while preserving historical data and every other active profile.
Register both profiles to monitor both simultaneously. The active registry
survives observability restarts; unregister profiles you no longer run.

## Access and stop

Forward ports over SSH for remote access (for example,
`ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 -L 6006:127.0.0.1:6006 <host>`).
Forward model ports as needed too.

- Grafana: <http://localhost:3000> (`admin` and your existing/configured password)
- Prometheus targets: <http://localhost:9090/targets>
- Phoenix traces: <http://localhost:6006>
- Qwen APIs: <http://localhost:8001/v1> and <http://localhost:8000/v1>

Each profile's `opencode/opencode.json` configures its models and tracing to
Phoenix. Merge it into `~/.config/opencode/opencode.json` (Windows:
`%USERPROFILE%\.config\opencode\opencode.json`); update API URLs if overriding
ports, then restart OpenCode.

To stop everything, unregister and stop **each active profile**, then stop
observability last so Docker can remove its shared network:

```bash
./scripts/profile.sh unregister qwen3.6-solo
docker compose -f qwen3.6-solo/compose.yaml down
./scripts/profile.sh unregister qwen3.6+3.8
docker compose -f qwen3.6+3.8/compose.yaml down
docker compose -f observability/compose.yaml down
```

Do not delete persistent volumes. Model `down` commands never include
observability services.

## Add another profile

1. Create a folder with a Compose file and a unique project `name`. Attach its
   services to external network `dgx-observability` with unique DNS aliases;
   omit fixed `container_name` values and choose available localhost host ports.
2. Add `targets.yml` using the aliases and internal ports. Use one target group
   per model with `profile`, `model`, and `job` labels:

   ```yaml
   - targets: ['example-profile-model:8000']
     labels:
       profile: 'example-profile'
       model: 'example-model'
       job: 'vllm'
   ```

3. Optionally add `dashboards/*.json` with unique dashboard UIDs and datasource
   UID `prometheus`. Scope queries to the profile; the shared vLLM dashboard
   already works through labels, without a profile-specific dashboard.
4. Start the profile, wait for readiness, and run
   `./scripts/profile.sh register example-profile`.

No changes to shared Compose, Prometheus, or Grafana provisioning are required.
