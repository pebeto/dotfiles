"""Tiny inventory tool: load items from CSV and print a stock report."""
import argparse
import csv
import sys
from dataclasses import dataclass


@dataclass
class Item:
    sku: str
    name: str
    qty: int
    unit_price: float
    category: str

    @property
    def value(self) -> float:
        return self.qty * self.unit_price


def load_items(path: str) -> list[Item]:
    with open(path, newline="") as fh:
        return [
            Item(row["sku"], row["name"], int(row["qty"]), float(row["unit_price"]), row["category"])
            for row in csv.DictReader(fh)
        ]


def summarize(items: list[Item], low_stock: int) -> dict:
    by_category: dict[str, dict] = {}
    for item in items:
        cat = by_category.setdefault(item.category, {"items": 0, "units": 0, "value": 0.0})
        cat["items"] += 1
        cat["units"] += item.qty
        cat["value"] += item.value
    return {
        "total_value": sum(i.value for i in items),
        "categories": by_category,
        "low_stock": sorted(i.sku for i in items if i.qty <= low_stock),
    }


def render_text(summary: dict) -> str:
    lines = [f"Total value: {summary['total_value']:.2f}"]
    for name in sorted(summary["categories"]):
        cat = summary["categories"][name]
        lines.append(f"{name}: {cat['items']} items, {cat['units']} units, {cat['value']:.2f}")
    if summary["low_stock"]:
        lines.append("Low stock: " + ", ".join(summary["low_stock"]))
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="inventory")
    sub = parser.add_subparsers(dest="command", required=True)
    report = sub.add_parser("report", help="print a stock report")
    report.add_argument("csv")
    report.add_argument("--low-stock", type=int, default=5)
    args = parser.parse_args(argv)
    summary = summarize(load_items(args.csv), args.low_stock)
    print(render_text(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
