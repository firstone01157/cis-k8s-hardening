#!/bin/bash
# CIS Benchmark: 4.2.2
# Title: Ensure that the --authorization-mode argument is set to Webhook
# Level: Level 1 - Worker Node
# Remediation Script

set -euo pipefail

kubelet_config_path() {
	local config
	config=$(ps -eo args | grep -m1 '[k]ubelet' | sed -n 's/.*--config[= ]\([^ ]*\).*/\1/p')
	if [ -n "$config" ]; then
		printf '%s' "$config"
	else
		printf '%s' "/var/lib/kubelet/config.yaml"
	fi
}

config_file=$(kubelet_config_path)
if [ ! -f "$config_file" ]; then
	echo "[WARN] kubelet config not found at $config_file; skipping 4.2.2."
	exit 0
fi

backup_file="$config_file.bak.$(date +%s)"
cp -p "$config_file" "$backup_file"

status=$(python3 - "$config_file" <<'PY'
from pathlib import Path
import sys

try:
	import yaml
except ImportError:
	sys.exit('yaml module unavailable')

path = Path(sys.argv[1])
original_text = path.read_text()
data = yaml.safe_load(original_text) or {}
if not isinstance(data, dict):
	data = {}

changed = False

def ensure_dict(parent, key):
	value = parent.get(key)
	if not isinstance(value, dict):
		value = {}
		parent[key] = value
	return value

auth = ensure_dict(data, 'authorization')
current = auth.get('mode')
if current == 'Webhook':
	print('UNCHANGED')
	sys.exit(0)

auth['mode'] = 'Webhook'
changed = True

if changed:
	new_text = yaml.safe_dump(data, sort_keys=False, default_flow_style=False, width=4096)
	if not new_text.endswith('\n'):
		new_text += '\n'
	path.write_text(new_text)
	print('UPDATED')
else:
	print('UNCHANGED')
PY
)

if [ "$status" = "UPDATED" ]; then
	echo "[FIXED] authorization mode set to Webhook in $config_file"
	echo "[INFO] Reload kubelet: systemctl daemon-reload && systemctl restart kubelet"
elif [ "$status" = "UNCHANGED" ]; then
	echo "[INFO] authorization mode already Webhook in $config_file"
else
	echo "[ERROR] Unexpected status from YAML updater: $status"
	exit 1
fi
