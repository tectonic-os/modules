if [ -z "${IMAGE_REGISTRY:-}" ]; then
    echo "signature-policy: no registry namespace to scope the policy to;" \
        "this image will not verify its own updates" >&2
else
    mkdir -p /etc/containers/registries.d
    cat > /etc/containers/registries.d/10-sigstore.yaml << EOF
docker:
  ${IMAGE_REGISTRY}:
    use-sigstore-attachments: true
EOF

    python3 << 'PYEOF'
import json, os
path = '/etc/containers/policy.json'
# containers-common 6 ships the base's policy under /usr/share, and /etc overrides it.
seed = next((f for f in (path, '/usr/share/containers/policy.json') if os.path.exists(f)), None)
p = json.load(open(seed)) if seed else {'default': [{'type': 'reject'}], 'transports': {}}
p.setdefault('transports', {}).setdefault('docker', {})[os.environ['IMAGE_REGISTRY']] = [
    {'type': 'sigstoreSigned', 'keyPath': '/etc/pki/containers/cosign.pub', 'signedIdentity': {'type': 'matchRepository'}}
]
json.dump(p, open(path, 'w'), indent=2)
PYEOF
fi
