#!/bin/bash
# Complete the MCRIT 1.7.0 disassembly split (mcrit issue #137).
#
# Upgrading to 1.7.0 does NOT require this: every reader falls back to the inline
# disassembly, so the instance serves correctly on the old shape. Running it moves the
# blobs out of the hot `functions` collection, which is where the speedup comes from.
#
# The migration is resumable - an interrupted run costs only the batch in flight - and
# re-running it after completion does nothing.
# shellcheck disable=SC1091
source .env

if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"; else COMPOSE="docker-compose"; fi

echo "MCRIT ${MCRIT_TAG}: moving disassembly out of the functions collection."
echo
echo "Before you continue:"
echo "  * this needs free disk roughly the size of your stored disassembly, and does not"
echo "    return it until you compact the collection afterwards (see README, Maintenance)"
echo "  * once migrated, OLDER MCRIT versions can no longer read this database and fail"
echo "    quietly - run '--mode unsplit' before ever downgrading the images"
echo "  * byte-for-byte verification is only possible BEFORE this runs (rehearse with"
echo "    '--mode copy --target <db>', or take a dump first)"
echo
printf 'Proceed with the in-place migration (y/n)? '
read -r key_result
if [ "$key_result" != "${key_result#[Yy]}" ] ; then
    ${COMPOSE} exec mcrit-server python -m mcrit.migrations.migrate_xcfg_split --mode inplace
    echo
    echo "Verifying:"
    ${COMPOSE} exec mcrit-server python -m mcrit.migrations.migrate_xcfg_split --mode verify
    echo
    echo "If /status still reports inline_xcfg_remaining: true, the migration has not finished."
else
    echo "Aborting..."
fi
