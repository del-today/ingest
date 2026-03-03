"""
India Habitat Centre (IHC) Event Scraper
Fetches events from indiahabitat.org and converts to Schema.org Event format.
Process:
1. Fetch https://indiahabitat.org/Events to get all event listing URLs
2. For each event detail page, extract title, date/time, venue, description
"""
import json
import re
from datetime import datetime
from bs4 import BeautifulSoup
from common.session import get_cached_session
from common.tz import IST

LISTING_URL = "https://indiahabitat.org/Events"
BASE_URL = "https://indiahabitat.org"
IHC_GEO = {"@type": "GeoCoordinates", "latitude": "28.5921", "longitude": "77.2040"}

session = get_cached_session()


def fetch_event_urls():
    resp = session.get(LISTING_URL)
    soup = BeautifulSoup(resp.text, "html.parser")
    urls = []
    for a in soup.select("a[href*='/Events_details/']"):
        href = a["href"]
        if href not in urls:
            urls.append(href)
    return urls


def parse_date(date_str):
    """Parse '7:00 PM Fri 6th Mar' style strings."""
    # Remove ordinal suffixes: 1st, 2nd, 3rd, 4th etc.
    date_str = re.sub(r"(\d+)(st|nd|rd|th)", r"\1", date_str)
    current_year = datetime.now().year
    for fmt in ["%I:%M %p %a %d %b", "%I:%M %p %A %d %b"]:
        try:
            dt = datetime.strptime(f"{date_str.strip()} {current_year}", fmt + " %Y")
            dt = dt.replace(tzinfo=IST)
            # If the date is in the past, try next year
            if dt < datetime.now(IST):
                dt = dt.replace(year=current_year + 1)
            return dt
        except ValueError:
            continue
    return None


def fetch_event(url):
    resp = session.get(url)
    soup = BeautifulSoup(resp.text, "html.parser")

    # Title is in the h1
    title_el = soup.select_one("h1")

    title = title_el.get_text(strip=True).replace(" | India Habitat Centre", "") if title_el else None
    if not title:
        return None

    # Date/time
    time_div = soup.select_one("div.time h3")
    start_dt = None
    if time_div:
        raw = time_div.get_text(separator=" ", strip=True)
        start_dt = parse_date(raw)

    if not start_dt:
        return None

    # Only future events
    if start_dt < datetime.now(tz=IST):
        return None

    # Venue
    venue_div = soup.select_one("div.venue h4")
    venue_name = venue_div.get_text(strip=True) if venue_div else "India Habitat Centre"

    # Description
    desc_el = soup.select_one("section.event-description p, div.event-desc p, .event-content p")
    description = desc_el.get_text(strip=True) if desc_el else ""

    return {
        "@type": "Event",
        "name": title,
        "url": url,
        "startDate": start_dt.isoformat(),
        "endDate": start_dt.isoformat(),  # IHC doesn't show end times
        "description": description,
        "location": {
            "@type": "Place",
            "name": f"IHC — {venue_name}",
            "address": "Lodhi Road, New Delhi 110003",
            "geo": IHC_GEO,
        },
        "organizer": {
            "@type": "Organization",
            "name": "India Habitat Centre",
        },
    }


def main():
    urls = list(dict.fromkeys(  # deduplicate while preserving order
        u if u.startswith("http") else BASE_URL + u
        for u in fetch_event_urls()
    ))
    print(f"[IHC] {len(urls)} unique event URLs")
    events = []
    for i, url in enumerate(urls):
        try:
            event = fetch_event(url)
            if event:
                events.append(event)
                print(f"[IHC] ({i+1}/{len(urls)}) ✓ {event['name'][:60]}")
            else:
                print(f"[IHC] ({i+1}/{len(urls)}) skipped (past or no data)")
        except Exception as e:
            print(f"[IHC] ({i+1}/{len(urls)}) error: {e}")

    events.sort(key=lambda x: x["startDate"])

    with open("out/ihc.json", "w") as f:
        json.dump(events, f, indent=2)

    print(f"[IHC] {len(events)} events")


if __name__ == "__main__":
    main()