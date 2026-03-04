"""
KHOJ Studios Event Scraper
Fetches events from khojstudios.org/events/

All data is in the initial HTML — no AJAX or detail page fetching needed.
Date format: DD/MM/YYYY, no time given (defaults to 10:00 AM IST).

Note: khojstudios.org is behind Cloudflare, so we use curl_chrome116
instead of get_cached_session() to bypass the JS challenge.

For exhibitions, we fetch the detail page to get the end date.
"""
import json
import subprocess
from datetime import datetime
from bs4 import BeautifulSoup
from common.tz import IST

LISTING_URL = "https://khojstudios.org/events/"
KHOJ_GEO = {"@type": "GeoCoordinates", "latitude": "28.6453", "longitude": "77.1851"}

# Map KHOJ event type labels to Schema.org @type
EVENT_TYPE_MAP = {
    "exhibition": "ExhibitionEvent",
    "film screening": "ScreeningEvent",
    "screenings": "ScreeningEvent",
    "book launch": "LiteraryEvent",
    "readings": "LiteraryEvent",
    "performance": "TheaterEvent",
    "short courses": "EducationEvent",
    "curated walk": "Event",
    "listening rooms": "MusicEvent",
    "open studio day": "Event",
    "presentation": "Event",
    "special event": "Event",
    "fundraising event": "Event",
    "webinar": "EducationEvent",
}


def fetch_page(url, retries=3):
    """Fetch a URL using curl_chrome116 to bypass Cloudflare. Retries on challenge page."""
    for attempt in range(retries):
        result = subprocess.run(
            ["curl_chrome116", "--silent", url],
            capture_output=True, text=True
        )
        if "Just a moment" not in result.stdout and "Enable JavaScript" not in result.stdout:
            return result.stdout
        print(f"[KHOJ] Cloudflare challenge, retrying ({attempt+1}/{retries})...")
    return result.stdout  # return last attempt regardless


def fetch_end_date(url):
    """Fetch detail page to get end date for exhibitions."""
    html = fetch_page(url)
    soup = BeautifulSoup(html, "html.parser")
    lines = soup.get_text(separator="\n", strip=True).splitlines()
    for i, line in enumerate(lines):
        if "End Date" in line and i + 1 < len(lines):
            end_str = lines[i + 1].strip()
            try:
                dt = datetime.strptime(end_str, "%b %d, %Y")
                return dt.replace(hour=18, tzinfo=IST)
            except ValueError:
                return None
    return None


def get_event_type(type_label):
    """Map KHOJ type label to Schema.org @type."""
    return EVENT_TYPE_MAP.get(type_label.lower().strip(), "Event")


def parse_date(date_str):
    """Parse 'DD/MM/YYYY' format. Returns aware datetime at 10:00 AM IST."""
    try:
        dt = datetime.strptime(date_str.strip(), "%d/%m/%Y")
        return dt.replace(hour=10, tzinfo=IST)
    except ValueError:
        return None


def scrape():
    html = fetch_page(LISTING_URL)
    soup = BeautifulSoup(html, "html.parser")
    events = []

    for card in soup.select(".listing-present__item"):
        # URL
        a = card.select_one("a")
        if not a:
            continue
        url = a.get("href", "")
        if not url:
            continue

        # Title
        title_el = card.select_one("h2.varweight .text-link")
        if not title_el:
            continue
        title = title_el.get_text(strip=True)

        # Description
        desc_el = card.select_one(".h6 p")
        description = desc_el.get_text(strip=True) if desc_el else ""

        # Type and date are in span.h6 elements
        spans = card.select("span.h6")
        if len(spans) < 2:
            continue
        type_label = spans[0].get_text(strip=True)
        date_str = spans[1].get_text(strip=True)

        start_dt = parse_date(date_str)
        if not start_dt:
            continue

        # Skip past events
        if start_dt < datetime.now(tz=IST):
            continue

        event_type = get_event_type(type_label)
        end_dt = start_dt

        # For exhibitions, fetch detail page to get end date
        if event_type == "ExhibitionEvent":
            fetched_end = fetch_end_date(url)
            if fetched_end:
                end_dt = fetched_end
                print(f"[KHOJ] Exhibition end date: {title[:40]} → {end_dt.date()}")

        events.append({
            "@type": event_type,
            "name": title,
            "url": url,
            "startDate": start_dt.isoformat(),
            "endDate": end_dt.isoformat(),
            "description": description,
            "location": {
                "@type": "Place",
                "name": "KHOJ Studios",
                "address": "S-17, Khirkee Extension, Malviya Nagar, New Delhi 110017",
                "geo": KHOJ_GEO,
            },
            "organizer": {
                "@type": "Organization",
                "name": "KHOJ International Artists' Association",
            },
            "keywords": ["KHOJ"],
        })

    events.sort(key=lambda x: x["startDate"])
    return events


def main():
    events = scrape()
    with open("out/khoj.json", "w") as f:
        json.dump(events, f, indent=2)
    print(f"[KHOJ] {len(events)} events")


if __name__ == "__main__":
    main()