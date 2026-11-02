# Observability setup

## 1. Set the Grafana password

Create `.env` by copying `.env.example`:

```bash
cp .env.example .env
chmod 600 .env
```

And enter a Grafana password:

```dotenv
GRAFANA_ADMIN_PASSWORD=your-password
```

The .env is already excluded from git.


## 2. Start services

```bash
docker compose config --quiet
docker compose up -d
```

Qwen3.8 waits for Qwen 3.6 to finish loading, before it starts, so it finished last. 
Follow the logs to see when it is ready:

```bash
docker logs -f qwen3.8-27b
```

## 3. Access from Windows over SSH

In the Windows SSH config (`%USERPROFILE%\.ssh\config`), add the following port forwards:

```sshconfig
Host spark
    HostName <spark-host-or-ip>
    User <username>
    LocalForward 8000 127.0.0.1:8000
    LocalForward 8001 127.0.0.1:8001
    LocalForward 3000 127.0.0.1:3000
    LocalForward 9090 127.0.0.1:9090
    LocalForward 6006 127.0.0.1:6006
```

Test the URLs in the browser:
- Qwen3.6-35B-A3B: [http://localhost:8001/v1/models](http://localhost:8001/v1/models)
- Qwen3.8-27B: [http://localhost:8000/v1/models](http://localhost:8000/v1/models)
- Prometheus: [http://localhost:9090/targets](http://localhost:9090/targets)
- Grafana: [http://localhost:3000](http://localhost:3000)
- Arize Phoenix: [http://localhost:6006](http://localhost:6006)

## 4. Import Grafana dashboards

1. When using a headless DGX Spark, copy the JSON files from `./observability/grafana/dashboards/` to your PC, or download them from GitHub.
2. Open Grafana at [http://localhost:3000](http://localhost:3000).
3. Navigate to **Dashboards → New → Import**.
4. Click **Upload dashboard JSON file**, select one of the copied files, and click **Import**.
5. Repeat for all dashboard JSON files.

## 5. Configure OpenCode

The `./opencode/opencode.json` file configures both local Qwen models and enables tracing to Arize Phoenix.

1. Locate your OpenCode configuration directory:
   - **Windows:** `%USERPROFILE%\.config\opencode\`
   - **Linux:** `~/.config/opencode/`
2. Back up your existing `opencode.json`, if present.
3. Copy `./opencode/opencode.json` into this directory.
   **Warning:** Overwriting an existing configuration may remove custom providers, agents, plugins and other settings. Review and merge configurations when necessary.
5. Restart OpenCode.

The provided `opencode.json` also enables OpenTelemetry tracing. Traces can be viewed in Arize Phoenix at [http://localhost:6006](http://localhost:6006).