"""
Kiran Nadar Museum of Art (KNMA) Event Scraper
Fetches events from knma.org/whats-on/ across six sections:
- exhibitions, talks, events, guided-tours, workshops, performing-arts

All sections share the same card structure (a.content_grid_v5).
Date format differs: exhibitions have a range "05 Feb 2026 — 30 Jun 2026"
while talks/events/tours have a single date "06 Mar 2026" + time "5:30 pm".
"""
import json
from datetime import datetime
from bs4 import BeautifulSoup
from common.session import get_cached_session
from common.tz import IST

BASE_URL = "https://www.knma.org"

# Each section URL and its default @type
SECTIONS = [
    ("https://www.knma.org/whats-on/exhibitions/", "ExhibitionEvent"),
    ("https://www.knma.org/whats-on/talks/", "EducationEvent"),
    ("https://www.knma.org/whats-on/events/", "Event"),
    ("https://www.knma.org/whats-on/guided-tours/", "EducationEvent"),
    ("https://www.knma.org/whats-on/workshops/", "EducationEvent"),
    ("https://www.knma.org/whats-on/performing-arts/", "TheaterEvent"),
]

KNMA_GEO = {"@type": "GeoCoordinates", "latitude": "28.5274", "longitude": "77.2159"}

# Venues that are definitively outside India — skip these events
OUTSIDE_INDIA = ["venice", "london", "kochi", "paris", "berlin", "new york", "tokyo", "dubai"]

session = get_cached_session()


def parse_single_date(date_str, time_str):
    """Parse '06 Mar 2026' + '5:30 pm' into aware datetime."""
    try:
        dt = datetime.strptime(f"{date_str.strip()} {time_str.strip()}", "%d %b %Y %I:%M %p")
        return dt.replace(tzinfo=IST)
    except ValueError:
        try:
            dt = datetime.strptime(date_str.strip(), "%d %b %Y")
            return dt.replace(hour=10, tzinfo=IST)
        except ValueError:
            return None


def parse_date_range(range_str):
    """Parse '05 Feb 2026 — 30 Jun 2026' into (start, end) aware datetimes."""
    try:
        parts = [p.strip() for p in range_str.split("—")]
        start = datetime.strptime(parts[0], "%d %b %Y").replace(hour=10, tzinfo=IST)
        end = datetime.strptime(parts[1], "%d %b %Y").replace(hour=18, tzinfo=IST)
        return start, end
    except (ValueError, IndexError):
        return None, None


def get_event_type(default_type, tag):
    """Refine @type based on the tag label on the card."""
    if not tag:
        return default_type
    tag_lower = tag.lower()
    if "film" in tag_lower or "screening" in tag_lower:
        return "ScreeningEvent"
    if "workshop" in tag_lower:
        return "EducationEvent"
    if "music" in tag_lower or "concert" in tag_lower:
        return "MusicEvent"
    return default_type


def scrape_section(url, default_type):
    """Scrape one section page and return a list of events."""
    resp = session.get(url)
    soup = BeautifulSoup(resp.text, "html.parser")
    events = []

    for card in soup.select("a.content_grid_v5"):
        href = card.get("href", "")
        if not href:
            continue
        if not href.startswith("http"):
            href = BASE_URL + href

        # Tag (e.g. "Film Screening", "Painting", "Digital")
        tag_el = card.select_one(".tag")
        tag = tag_el.get_text(strip=True) if tag_el else ""

        # Location
        loc_el = card.select_one(".location_label")
        location_name = loc_el.get_text(strip=True) if loc_el else "KNMA"
        location_lower = location_name.lower()

        # Skip events at venues outside India
        if any(place in location_lower for place in OUTSIDE_INDIA):
            print(f"[KNMA] Skipping non-India venue: {location_name}")
            continue

        # Title — can be multi-line, join with space
        title_el = card.select_one(".content_grid_v5_info--title")
        if not title_el:
            continue
        title = title_el.get_text(separator=" ", strip=True)

        # Date text
        date_el = card.select_one(".content_grid_v5_info--text")
        if not date_el:
            continue
        date_text = date_el.get_text(separator="\n", strip=True)
        lines = [l.strip() for l in date_text.split("\n") if l.strip()]

        # Determine if this is a date range (exhibition) or single date (event)
        if "—" in date_text:
            start_dt, end_dt = parse_date_range(lines[0])
            if not start_dt:
                continue
            # Skip if exhibition has already ended
            if end_dt < datetime.now(tz=IST):
                continue
        else:
            date_str = lines[0] if len(lines) > 0 else ""
            time_str = lines[1] if len(lines) > 1 else "10:00 am"
            start_dt = parse_single_date(date_str, time_str)
            if not start_dt:
                continue
            # Skip past events
            if start_dt < datetime.now(tz=IST):
                continue
            end_dt = start_dt

        # Determine address and geo based on venue
        # Only attach KNMA_GEO to KNMA's own premises
        if "saket" in location_lower or "citywalk" in location_lower:
            address = "Saket, New Delhi"
            geo = KNMA_GEO
        elif "noida" in location_lower:
            address = "DLF Mall of India, Sector 18, Noida"
            geo = KNMA_GEO
        elif "humayun" in location_lower:
            address = "Humayun's Tomb, Nizamuddin, New Delhi"
            geo = None  # let geo.py handle it
        else:
            # Unknown venue in India — use generic address, let geo.py handle
            address = "New Delhi"
            geo = None

        events.append({
            "@type": get_event_type(default_type, tag),
            "name": title,
            "url": href,
            "startDate": start_dt.isoformat(),
            "endDate": end_dt.isoformat(),
            "description": tag,
            "location": {
                "@type": "Place",
                "name": location_name,
                "address": address,
                **({"geo": geo} if geo else {}),
            },
            "organizer": {
                "@type": "Organization",
                "name": "Kiran Nadar Museum of Art",
            },
            "keywords": ["KNMA"],
        })

    return events


def main():
    all_events = []
    for url, default_type in SECTIONS:
        section_events = scrape_section(url, default_type)
        print(f"[KNMA] {url.split('/')[-2]}: {len(section_events)} events")
        all_events += section_events

    # Deduplicate by URL
    seen = set()
    events = []
    for e in all_events:
        if e["url"] not in seen:
            seen.add(e["url"])
            events.append(e)

    events.sort(key=lambda x: x["startDate"])

    with open("out/knma.json", "w") as f:
        json.dump(events, f, indent=2)
    print(f"[KNMA] {len(events)} total events written")


if __name__ == "__main__":
    main()