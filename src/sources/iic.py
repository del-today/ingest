"""
India International Centre (IIC) Delhi Event Scraper
Fetches events from iicdelhi.in/programmes/current.
Process:
1. Paginate through the listing page to collect all event URLs
2. For each event detail page, extract title, date/time, venue, description
"""
import json
import re
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
from common.session import get_cached_session
from common.tz import IST

BASE_URL = "https://iicdelhi.in"
LISTING_URL = (
    "https://iicdelhi.in/programmes/current"
    "?field_programme_type_target_id=All"
    "&field_start_date_value_1%5Bmin%5D={start}"
    "&field_start_date_value_1%5Bmax%5D={end}"
    "&combine="
)
IIC_GEO = {"@type": "GeoCoordinates", "latitude": "28.5931", "longitude": "77.2203"}

session = get_cached_session()


def fetch_event_urls():
    start = datetime.now().strftime("%Y-%m-%d")
    end = (datetime.now() + timedelta(days=90)).strftime("%Y-%m-%d")
    url = LISTING_URL.format(start=start, end=end)

    urls = []
    page = 0
    while True:
        paged_url = url + (f"&page={page}" if page > 0 else "")
        resp = session.get(paged_url)
        soup = BeautifulSoup(resp.text, "html.parser")

        for row in soup.select(".views-row"):
            a = row.select_one("a[href^='/programmes/'], a[href^='https://iicdelhi.in/programmes/']")
            if a:
                href = a["href"]
                if not href.startswith("http"):
                    href = BASE_URL + href
                if href not in urls:
                    urls.append(href)

        # Check for next page
        next_link = soup.select_one("li.next a")
        if not next_link:
            break
        page += 1

    return urls


def parse_date(date_str):
    """Parse '06 March 2026, 06:00 pm' format."""
    try:
        dt = datetime.strptime(date_str.strip(), "%d %B %Y, %I:%M %p")
        return dt.replace(tzinfo=IST)
    except ValueError:
        return None


def get_event_type(programme_type):
    MAPPING = {
        "film": "ScreeningEvent",
        "music": "MusicEvent",
        "discussion": "Event",
        "lecture": "Event",
        "exhibition": "ExhibitionEvent",
        "workshop": "EducationEvent",
        "theatre": "Event",
        "dance": "Event",
    }
    if programme_type:
        for key, value in MAPPING.items():
            if key in programme_type.lower():
                return value
    return "Event"


def fetch_event(url):
    resp = session.get(url)
    soup = BeautifulSoup(resp.text, "html.parser")

    article = soup.select_one("article")
    if not article:
        return None

    body = article.select_one(".program-body.dynamic-font-text")
    if not body:
        return None

    # Date is the first text node in .program-body
    date_str = body.get_text(separator="\n", strip=True).split("\n")[0]
    start_dt = parse_date(date_str)
    if not start_dt:
        return None

    # Skip past events
    if start_dt < datetime.now(tz=IST):
        return None

    # Title is in the bold div
    title_el = body.select_one("div[style*='font-size:14px']")
    if not title_el:
        return None
    title = title_el.get_text(strip=True)

    # Programme type
    type_el = article.select_one(".field--name-field-programme-type .field--item")
    programme_type = type_el.get_text(strip=True) if type_el else ""

    # Venue
    venue_el = article.select_one(".field--name-field-venue .field--item")
    venue = venue_el.get_text(strip=True) if venue_el else "India International Centre"
    venue = f"IIC — {venue}"

    # Description
    desc_el = article.select_one(".field--name-body")
    description = desc_el.get_text(strip=True) if desc_el else ""

    return {
        "@type": get_event_type(programme_type),
        "name": title,
        "url": url,
        "startDate": start_dt.isoformat(),
        "endDate": start_dt.isoformat(),
        "description": description,
        "location": {
            "@type": "Place",
            "name": venue,
            "address": "40, Max Mueller Marg, Lodhi Estate, New Delhi 110003",
            "geo": IIC_GEO,
        },
        "organizer": {
            "@type": "Organization",
            "name": "India International Centre",
        },
    }


def main():
    urls = fetch_event_urls()
    print(f"[IIC] {len(urls)} event URLs found")

    events = []
    for i, url in enumerate(urls):
        try:
            event = fetch_event(url)
            if event:
                events.append(event)
                print(f"[IIC] ({i+1}/{len(urls)}) ✓ {event['name'][:60]}")
            else:
                print(f"[IIC] ({i+1}/{len(urls)}) skipped (past or no data)")
        except Exception as e:
            print(f"[IIC] ({i+1}/{len(urls)}) error: {e}")

    events.sort(key=lambda x: x["startDate"])
    with open("out/iic.json", "w") as f:
        json.dump(events, f, indent=2)
    print(f"[IIC] {len(events)} events written")


if __name__ == "__main__":
    main()