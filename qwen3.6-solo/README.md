# qwen3.6-solo

Runs Qwen3.6-35B-A3B on port 8001. Model performance settings are preserved.
See the [root guide](../README.md) for shared observability setup, activation,
readiness, concurrent host-port overrides, and safe shutdown.

`targets.yml` defines profile-specific DNS targets and labels. Register it with
`./scripts/profile.sh register qwen3.6-solo` from the repository root after models
are ready. Unregister before stopping the profile. Optional specialized
dashboards live in `dashboards/`; the generic vLLM dashboard is shared.

`opencode/opencode.json` configures these models and tracing to shared Phoenix.
