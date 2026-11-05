# qwen3.6+3.8

Runs Qwen3.6-35B-A3B on port 8001 and Qwen3.8-27B on port 8000. Model performance settings are preserved.
See the [root guide](../README.md) for shared observability setup, activation,
readiness, concurrent host-port overrides, and safe shutdown.

`targets.yml` defines profile-specific DNS targets and labels. Register it with
`./scripts/profile.sh register qwen3.6+3.8` from the repository root after models
are ready. Unregister before stopping the profile. Optional specialized
dashboards live in `dashboards/`; the generic vLLM dashboard is shared.

`opencode/opencode.json` configures these models and tracing to shared Phoenix.
