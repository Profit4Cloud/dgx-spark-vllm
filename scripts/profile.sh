#!/bin/sh
# Register monitoring files only; model containers have their own Compose lifecycle.
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 register|unregister PROFILE" >&2
    exit 2
fi

action=$1
profile=$2
case "$profile" in
    ''|*[!a-zA-Z0-9._+-]*|[!a-zA-Z0-9]*)
        echo "Invalid profile name: $profile" >&2
        exit 2
        ;;
esac

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
profile_dir=$repo_dir/$profile
targets_dir=$repo_dir/observability/targets
dashboards_dir=$repo_dir/observability/grafana/dashboards/profiles/$profile

case "$action" in
    register)
        if [ ! -f "$profile_dir/targets.yml" ]; then
            echo "Missing target definitions: $profile_dir/targets.yml" >&2
            exit 1
        fi
        mkdir -p "$targets_dir"
        staged=$(mktemp "$targets_dir/.$profile.XXXXXX")
        trap 'rm -f "$staged"' EXIT HUP INT TERM
        cp "$profile_dir/targets.yml" "$staged"
        chmod 644 "$staged"
        # Grafana polls the mounted directory; publish each optional dashboard atomically.
        for dashboard in "$profile_dir"/dashboards/*.json; do
            [ -f "$dashboard" ] || continue
            mkdir -p "$dashboards_dir"
            dashboard_name=$(basename -- "$dashboard")
            cp "$dashboard" "$dashboards_dir/.$dashboard_name.tmp"
            chmod 644 "$dashboards_dir/.$dashboard_name.tmp"
            mv -f "$dashboards_dir/.$dashboard_name.tmp" "$dashboards_dir/$dashboard_name"
        done
        mv -f "$staged" "$targets_dir/$profile.yml"
        echo "Registered $profile; Prometheus discovers targets automatically."
        ;;
    unregister)
        rm -f "$targets_dir/$profile.yml"
        # Keep dashboards available for historical queries after a profile stops.
        echo "Unregistered $profile; dashboards and historical data retained."
        ;;
    *)
        echo "Unknown action: $action (use register or unregister)" >&2
        exit 2
        ;;
esac
