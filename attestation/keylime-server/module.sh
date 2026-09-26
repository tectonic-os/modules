# Operators use the all-interface bind for remote agents and can keep local
# verifier-to-registrar traffic on loopback.
for component in registrar verifier; do
    cat > "/etc/keylime/${component}.conf.d/50-module-keylime-server.conf" << EOF
[${component}]
ip = "0.0.0.0"
EOF
    chown keylime:keylime "/etc/keylime/${component}.conf.d/50-module-keylime-server.conf"
    chmod 0400 "/etc/keylime/${component}.conf.d/50-module-keylime-server.conf"
done
