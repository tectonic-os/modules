# SSG's remediation for the profile the image declares, run in the finalize
# layer because it measures the finished image and every module layer is
# already below it.

# `conforms` is what says the image is measured, and remediation follows the
# same declaration: hardening an image nobody asked to harden is a surprise.
if [ -z "${CONFORMS:-}" ] || [ -z "${SCAP_CONTENT:-}" ]; then
    echo "scap-remediation: no conforms, nothing to remediate"
else
    # Installed, used and removed inside the finalize layer's one RUN, so none
    # of it reaches the image. scap-security-guide alone is 708 MiB installed,
    # 468 MiB of that datastreams for other products.
    dnf -y install openscap-utils scap-security-guide openscap-engine-sce setools-console

    # What no remediation may touch: what a module refuses outright, and every
    # rule a module claims. A claim holds only while the module is what makes
    # the rule pass, so a claimed rule SSG also sets is a claim nothing proves.
    # Refusals arrive as rule IDs and claims as benchmark numbers, and `tect`
    # owns that mapping — a hook re-deriving it would be a second copy of the
    # rule every claim in this collection rests on.
    scap_exempt="${SCAP_REFUSED:-}"
    if [ -n "${SCAP_CLAIMED:-}" ]; then
        # shellcheck disable=SC2086 # one number per argument is the point
        scap_exempt="${scap_exempt} $(/ctx/tect scap rules \
            --datastream "${SCAP_CONTENT}" ${SCAP_CLAIMED})"
    fi

    scap_profile="${CONFORMS}"
    scap_tailoring=()
    scap_unselect=()
    for scap_rule in ${scap_exempt}; do
        scap_unselect+=(-u "${scap_rule}")
    done
    if [ "${#scap_unselect[@]}" -gt 0 ]; then
        autotailor "${SCAP_CONTENT}" "${CONFORMS}" "${scap_unselect[@]}" \
            -p "${CONFORMS}_tect" -o /tmp/tect-tailoring.xml
        scap_profile="${CONFORMS}_tect"
        scap_tailoring=(--tailoring-file /tmp/tect-tailoring.xml)
        echo "scap-remediation: ${#scap_unselect[@]} rules left to their owners"
    fi

    # oscap exits non-zero whenever any rule fails, which is the ordinary case
    # and not a build failure. oscap-im swallows 0 and 2 itself and still
    # returns non-zero for a bootloader rule that cannot run in a container.
    oscap-im --profile "${scap_profile}" "${scap_tailoring[@]}" \
        --results-arf /tmp/tect-scap-arf.xml "${SCAP_CONTENT}" || true
    [ -s /tmp/tect-scap-arf.xml ] || { echo "scap-remediation: the scan wrote no report"; exit 1; }

    # The report is not baked: it is 31 MiB, and what wants it is a CI
    # attestation against the published digest rather than every running image.
    dnf -y remove openscap-utils scap-security-guide openscap-engine-sce setools-console
    dnf -y clean all
    rm -f /tmp/tect-tailoring.xml /tmp/tect-scap-arf.xml
fi
