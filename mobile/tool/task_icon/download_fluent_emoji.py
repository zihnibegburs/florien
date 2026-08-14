#!/usr/bin/env python3
"""Download Microsoft Fluent Emoji 3D PNGs used by Florien task icons."""

from __future__ import annotations

from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

# storage_name -> GitHub folder under microsoft/fluentui-emoji/assets
FOLDERS: dict[str, str] = {
    "work": "Briefcase",
    "meeting": "Busts in silhouette",
    "presentation": "Chart increasing",
    "email": "Envelope",
    "phone_call": "Telephone receiver",
    "project": "Clipboard",
    "deadline": "Alarm clock",
    "coding": "Laptop",
    "bug_fix": "Bug",
    "research": "Magnifying glass tilted left",
    "study": "Graduation cap",
    "homework": "Notebook",
    "exam": "Pencil",
    "reading": "Open book",
    "writing": "Memo",
    "note_taking": "Memo",
    "language_learning": "Globe with meridians",
    "school": "Backpack",
    "childcare": "Baby",
    "sleep": "Sleeping face",
    "shopping": "Shopping bags",
    "groceries": "Shopping cart",
    "clothes_shopping": "T-shirt",
    "electronics_shopping": "Headphone",
    "online_order": "Package",
    "gift": "Wrapped gift",
    "birthday": "Birthday cake",
    "return_item": "Counterclockwise arrows button",
    "pickup": "Shopping bags",
    "delivery": "Delivery truck",
    "cooking": "Cooking",
    "breakfast": "Cooking",
    "lunch": "Fork and knife",
    "dinner": "Fork and knife with plate",
    "restaurant": "Fork and knife with plate",
    "coffee": "Hot beverage",
    "food_order": "Motor scooter",
    "meal_prep": "Bento box",
    "baking": "Cupcake",
    "drinks": "Cup with straw",
    "health": "Red heart",
    "doctor": "Stethoscope",
    "dentist": "Tooth",
    "medicine": "Pill",
    "pharmacy": "Pill",
    "hospital": "Hospital",
    "therapy": "Couch and lamp",
    "checkup": "Anatomical heart",
    "vaccination": "Syringe",
    "medical_test": "Test tube",
    "meditation": "Person in lotus position",
    "gym": "Flexed biceps",
    "running": "Person running",
    "walking": "Person walking",
    "cycling": "Person biking",
    "swimming": "Person swimming",
    "yoga": "Person in lotus position",
    "workout": "Flexed biceps",
    "sport": "Soccer ball",
    "stretching": "Person in lotus position",
    "travel": "World map",
    "flight": "Airplane",
    "hotel": "Hotel",
    "vacation": "Beach with umbrella",
    "luggage": "Luggage",
    "passport": "Blue book",
    "visa": "Ticket",
    "trip_planning": "World map",
    "sightseeing": "Camera",
    "reservation": "Admission tickets",
    "car": "Automobile",
    "car_maintenance": "Wrench",
    "car_repair": "Hammer and wrench",
    "fuel": "Fuel pump",
    "car_wash": "Soap",
    "parking": "P button",
    "public_transport": "Bus",
    "taxi": "Taxi",
    "train": "Locomotive",
    "driving": "Automobile",
    "home": "House",
    "cleaning": "Soap",
    "laundry": "Jeans",
    "dishes": "Fork and knife",
    "home_repair": "Hammer",
    "gardening": "Seedling",
    "furniture": "Chair",
    "moving": "Package",
    "organizing": "Card file box",
    "bills": "Receipt",
    "finance": "Money bag",
    "payment": "Credit card",
    "banking": "Bank",
    "subscription": "Ticket",
    "family": "People hugging",
    "friends": "People hugging",
    "pet": "Dog",
    "entertainment": "Movie camera",
    "appointment": "Calendar",
    "other": "Check mark button",
}

BASE = "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets"
OUT = Path(__file__).resolve().parents[2] / "assets" / "fluent_emoji"


def slug(folder: str) -> str:
    return folder.lower().replace(" ", "_")


def candidates(folder: str) -> list[str]:
    encoded = quote(folder)
    name = slug(folder)
    return [
        f"{BASE}/{encoded}/3D/{name}_3d.png",
        f"{BASE}/{encoded}/Default/3D/{name}_3d_default.png",
    ]


def download(url: str) -> bytes | None:
    request = Request(url, headers={"User-Agent": "florien-fluent-emoji"})
    try:
        with urlopen(request, timeout=30) as response:
            if response.status != 200:
                return None
            data = response.read()
            return data if data.startswith(b"\x89PNG") else None
    except Exception:
        return None


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    failed: list[str] = []
    seen: dict[str, Path] = {}
    for key, folder in FOLDERS.items():
        dest = OUT / f"{key}.png"
        if dest.exists() and dest.stat().st_size > 0:
            continue
        if folder in seen:
            dest.write_bytes(seen[folder].read_bytes())
            continue
        data = None
        for url in candidates(folder):
            data = download(url)
            if data:
                break
        if data is None:
            failed.append(f"{key} ({folder})")
            continue
        dest.write_bytes(data)
        seen[folder] = dest
        print(f"ok  {key}")
    if failed:
        raise SystemExit("missing:\n" + "\n".join(failed))
    print(f"downloaded {len(FOLDERS)} icons -> {OUT}")


if __name__ == "__main__":
    main()
