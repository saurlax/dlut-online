"""Publish registered EDA outdoor fixtures without changing map geometry."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def build():
    source = json.loads((ROOT / "references/eda/site-fixtures.json").read_text(encoding="utf-8"))
    data = {"lamps": source["lamps"], "noticeboards": source["noticeboards"],
            "sourceCommit": source["sourceCommit"], "precision": source["precision"]}
    output = ROOT / "apps/web/public/campuses/eda/site-fixtures.json"
    output.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Published {len(data['lamps'])} lamps and {len(data['noticeboards'])} noticeboards")


if __name__ == "__main__":
    build()
