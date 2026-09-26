# Image authors use `hash_ek` to avoid the packaged config's shared UUID.
# Operators retain a stable per-machine UUID across TPM reinstalls.
# Operators expose the agent beyond loopback for remote verifiers. They rely on
# the agent's default mTLS to reject unauthenticated verifiers.

# Image authors must omit quotes and newlines to keep the generated TOML valid.
case "${OPT_REGISTRAR}" in
    '' | *[!A-Za-z0-9.:-]*)
        echo "keylime-agent: registrar must be a hostname or an IP address, got '${OPT_REGISTRAR}'" >&2
        exit 1
        ;;
esac

cat > /etc/keylime/agent.conf.d/50-module-keylime-agent.conf << EOF
[agent]
uuid = "hash_ek"
ip = "0.0.0.0"
registrar_ip = "${OPT_REGISTRAR}"
registrar_tls_enabled = false
EOF

# Image authors set the final owner and mode during the build and avoid waiting
# for Keylime's boot-time tmpfiles correction.
chown keylime:keylime /etc/keylime/agent.conf.d/50-module-keylime-agent.conf
chmod 0400 /etc/keylime/agent.conf.d/50-module-keylime-agent.conf
