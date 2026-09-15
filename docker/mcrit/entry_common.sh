#!/bin/sh
# Sourced by the entry scripts before they exec their process; every caller sets -eu itself.

CONFIG_DIR=/opt/mcrit/mcrit/config
# Image copy of the config the installed MCRIT ships, taken before anything overwrote it. It lives
# outside /opt/mcrit so the development compose file's bind mount of a host checkout cannot hide it.
CONFIG_STOCK=/opt/config.stock

# The deployment's config is assembled rather than mounted over the package directory: the shipped
# defaults first, then whatever the operator overrides in config.local. Absent when the development
# compose file mounts ./config read-only instead, in which case the package directory already is
# the deployment's config.
if [ -d /opt/mcrit/config.default ]; then
    cp /opt/mcrit/config.default/*.py "$CONFIG_DIR/"
    if [ -d /opt/mcrit/config.local ]; then
        for override in /opt/mcrit/config.local/*.py; do
            [ -e "$override" ] || break
            cp "$override" "$CONFIG_DIR/"
        done
    fi
fi

# An MCRIT upgrade can add settings that this repository's config/ does not carry yet; the assembled
# module then silently lacks them. Report it at startup instead of leaving it to be discovered.
CONFIG_DIR="$CONFIG_DIR" CONFIG_STOCK="$CONFIG_STOCK" python - <<'PY' || true
import ast
import os
import pathlib


def settings(path):
    # settings are module-level or class-level assignments; names bound inside a function are
    # locals however they are spelled, so function bodies are not descended into
    names = set()

    def collect(body):
        for node in body:
            if isinstance(node, ast.Assign):
                targets = node.targets
            elif isinstance(node, ast.AnnAssign):
                targets = [node.target]
            else:
                targets = []
                if isinstance(node, (ast.ClassDef, ast.If, ast.Try)):
                    collect(node.body)
                    collect(getattr(node, "orelse", []))
                    for handler in getattr(node, "handlers", []):
                        collect(handler.body)
                    collect(getattr(node, "finalbody", []))
            names.update(t.id for t in targets if isinstance(t, ast.Name) and t.id.isupper())

    collect(ast.parse(path.read_text()).body)
    return names


config = pathlib.Path(os.environ["CONFIG_DIR"])
for stock in sorted(pathlib.Path(os.environ["CONFIG_STOCK"]).glob("*.py")):
    assembled = config / stock.name
    try:
        missing = settings(stock) - (settings(assembled) if assembled.exists() else set())
    except SyntaxError as error:
        print(f"WARNING: {stock.name} could not be parsed: {error}", flush=True)
        continue
    if missing:
        print(f"WARNING: {stock.name} is missing settings the installed MCRIT defines: {', '.join(sorted(missing))}", flush=True)
PY
