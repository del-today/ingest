"""
Fillum.in Event Scraper
Fetches film screening events from fillum.in/film-screenings-in-delhi.
Only scrapes the listing page — detail pages have no additional useful data.
"""
import json
from datetime import datetime
from bs4 import BeautifulSoup
from common.session import get_cached_session
from common.tz import IST

LISTING_URL = "https://fillum.in/film-screenings-in-delhi"
BASE_URL = "https://fillum.in"

VENUE_ADDRESSES = {
    "alliance française": "Lodhi Road, New Delhi",
    "goethe": "Lodhi Road, New Delhi",
    "mool": "South Ex II, New Delhi",
    "sound redefined": "Lado Sarai, New Delhi",
    "niv art centre": "Sainik Farm, New Delhi",
}

session = get_cached_session()


def parse_date(date_str):
    """Parse '06 Mar, 2026 · 5:30 PM' format. Returns aware datetime."""
    try:
        dt = datetime.strptime(date_str.strip(), "%d %b, %Y · %I:%M %p")
        return dt.replace(tzinfo=IST)
    except ValueError:
        return None


def scrape():
    resp = session.get(LISTING_URL)
    soup = BeautifulSoup(resp.text, "html.parser")
    events = []

    for block in soup.select(".screeningbox2.screeningcitydelhi"):
        # URL is on the screening/event link
        href_el = block.select_one("a[href^='screening/'], a[href^='event/']")
        if not href_el:
            continue
        href = BASE_URL + "/" + href_el.get("href", "").lstrip("/")

        # Title
        title_el = block.select_one(".scfilmname a")
        if not title_el:
            continue
        title = title_el.get_text(strip=True)

        # Date — find anchor with '·' in text (contains date + time)
        date_els = block.select("a[href^='screening/'], a[href^='event/']")
        date_el = next((a for a in date_els if "·" in a.get_text()), None)
        if not date_el:
            continue
        start_date = parse_date(date_el.get_text(strip=True))
        if not start_date:
            continue

        # Skip past events — fixed: use tz=IST to match aware datetime
        if start_date < datetime.now(tz=IST):
            continue
        
        # Venue
        venue_el = block.select_one(".sclocation")
        venue = venue_el.get_text(strip=True) if venue_el else "Delhi"
        address = next((addr for key, addr in VENUE_ADDRESSES.items() if key in venue.lower()), "Delhi")

        # Organizer / host
        host_el = block.select_one(".schost a")
        organizer = host_el.get_text(strip=True) if host_el else "Fillum"

        # Description
        desc_el = block.select_one(".scdescription")
        description = desc_el.get_text(strip=True) if desc_el else ""

        events.append({
            "@type": "Event",  # changed from ScreeningEvent for build.py compatibility
            "name": title,
            "url": href,
            "startDate": start_date.isoformat(),  # fixed: serialize to string for json.dump
            "endDate": start_date.isoformat(),
            "description": description,
            "location": {
                "@type": "Place",
                "name": venue,
                "address": address,
            },
            "organizer": {
                "@type": "Organization",
                "name": organizer,
            },
        })

    events.sort(key=lambda x: x["startDate"])
    return events


def main():
    events = scrape()
    with open("out/fillum.json", "w") as f:
        json.dump(events, f, indent=2)
    print(f"[FILLUM] {len(events)} events")


if __name__ == "__main__":
    main()