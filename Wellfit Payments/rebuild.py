#!/usr/bin/env python3
"""Rebuild Wellfit Payments/ import pack from core + tickets + regression sources."""

from __future__ import annotations

import json
import uuid
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = Path(__file__).resolve().parent
CORE = ROOT / "postman/collections/core"
TICKETS = ROOT / "postman/collections/tickets"
REG_COLL = ROOT / "regression/9.6/Regression-STAGE/Regression-STAGE.postman_collection.json"
REG_ENV = ROOT / "regression/9.6/Regression-STAGE/Regression-STAGE.postman_environment.json"
ACH_ENV = ROOT / "postman/environments/core/ACH Payments V2 Env.postman_environment.json"


def load_collections(folder: Path):
    items = []
    if not folder.is_dir():
        return items
    for p in sorted(folder.glob("*.postman_collection.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        name = (data.get("info") or {}).get("name") or p.stem
        folder_item = {
            "name": name,
            "description": (data.get("info") or {}).get("description") or f"From {p.name}",
            "item": deepcopy(data.get("item") or []),
        }
        vars_ = data.get("variable") or []
        if vars_:
            keys = ", ".join(v.get("key", "") for v in vars_[:25])
            folder_item["description"] = (folder_item.get("description") or "") + f"\n\nCollection vars: {keys}"
        if data.get("auth"):
            folder_item["auth"] = deepcopy(data["auth"])
        items.append((name, folder_item, vars_))
    return items


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    core_cols = load_collections(CORE)
    ticket_cols = load_collections(TICKETS)
    reg = json.loads(REG_COLL.read_text(encoding="utf-8"))
    reg_modules = deepcopy(reg.get("item") or [])

    merged_vars, seen = [], set()
    for v in reg.get("variable") or []:
        k = v.get("key")
        if k and k not in seen:
            seen.add(k)
            merged_vars.append(
                {"key": k, "value": v.get("value") if v.get("value") is not None else "", "type": v.get("type") or "string"}
            )
    for _, _, vars_ in core_cols + ticket_cols:
        for v in vars_:
            k = v.get("key")
            if not k or k in seen:
                continue
            seen.add(k)
            merged_vars.append(
                {"key": k, "value": v.get("value") if v.get("value") is not None else "", "type": v.get("type") or "string"}
            )

    collection = {
        "info": {
            "_postman_id": str(uuid.uuid4()),
            "name": "Wellfit Payments",
            "description": (
                "Import folder Wellfit Payments/ (collection + env).\n\n"
                "0 — Regression → modules directly (no nested 9.6 folder)\n"
                "1 — Core\n"
                "2 — Tickets\n\n"
                "Env: Wellfit Payments STAGE"
            ),
            "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
        },
        "variable": merged_vars[:120],
        "item": [
            {
                "name": "0 — Regression",
                "description": "Release 9.6 STAGE. Modules are direct children.",
                "item": reg_modules,
            },
            {
                "name": "1 — Core",
                "description": "Product APIs.",
                "item": [f for _, f, _ in core_cols],
            },
            {
                "name": "2 — Tickets",
                "description": "PAY-XXXX suites.",
                "item": [f for _, f, _ in ticket_cols],
            },
        ],
    }
    if reg.get("auth"):
        collection["item"][0]["auth"] = deepcopy(reg["auth"])

    reg_env = json.loads(REG_ENV.read_text(encoding="utf-8"))
    values, seen_keys = [], set()
    for v in reg_env.get("values", []):
        k = v.get("key")
        if not k or k in seen_keys:
            continue
        seen_keys.add(k)
        values.append(deepcopy(v))
    if ACH_ENV.exists():
        for v in json.loads(ACH_ENV.read_text(encoding="utf-8")).get("values", []):
            k = v.get("key")
            if not k or k in seen_keys:
                continue
            seen_keys.add(k)
            values.append(deepcopy(v))

    environment = {
        "id": str(uuid.uuid4()),
        "name": "Wellfit Payments STAGE",
        "values": values,
        "_postman_variable_scope": "environment",
    }

    coll_path = DEST / "Wellfit Payments.postman_collection.json"
    env_path = DEST / "Wellfit Payments STAGE.postman_environment.json"
    coll_path.write_text(json.dumps(collection, indent=2) + "\n", encoding="utf-8")
    env_path.write_text(json.dumps(environment, indent=2) + "\n", encoding="utf-8")

    (DEST / "README.md").write_text(
        "# Wellfit Payments — Postman import\n\n"
        "1. Import this folder in Postman.\n"
        "2. Select env **Wellfit Payments STAGE**.\n\n"
        "## Structure\n\n"
        "```\n"
        "Wellfit Payments\n"
        "├── 0 — Regression   (CNP, TokenVault, Provisioning, Wallet, PAY-2603, Treasury)\n"
        "├── 1 — Core\n"
        "└── 2 — Tickets\n"
        "```\n\n"
        "Rebuild after adding sources: `python3 \"Wellfit Payments/rebuild.py\"`\n",
        encoding="utf-8",
    )

    print("Rebuilt:", coll_path)
    print("Env:", env_path)
    print("Regression modules:", [m["name"] for m in reg_modules])
    print("Core:", len(core_cols), "Tickets:", len(ticket_cols), "Env keys:", len(values))


if __name__ == "__main__":
    main()
