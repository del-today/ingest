import json
import subprocess
import sys
import time
from bs4 import BeautifulSoup
import datetime
from common.tz import IST

SEARCH_URL = "https://search-v2.urbanaut.app/multi_search"
TYPESENSE_API_KEY = "NSUWIvHiEDI8jvLN2GLhTfCzg3T6oYYV"
BASE_IMAGE_URL = "https://d10y46cwh6y6x1.cloudfront.net"

DELHI_LAT = 28.6862738
DELHI_LNG = 77.2217831
DELHI_RADIUS = "100km"


def make_payload():
    ts = int(time.time())
    return {
        "searches": [
            {
                "collection": "spot_approved",
                "query_by": "name",
                "q": "*",
                "per_page": 100,
                "include_fields": "*, $account(*) as account_data, $who_is_it_for_tag(*) as who_is_it_for_tags_data, $genre_tag(*) as genre_tags_data",
                "filter_by": (
                    f"enable_list_view:=true && $category(slug:=events) "
                    f"&& lat_lng:({DELHI_LAT}, {DELHI_LNG}, {DELHI_RADIUS}) "
                    f"&& (end_timestamp:>={ts} || has_end_timestamp:false)"
                ),
                "sort_by": "upcoming_session_timestamp:asc",
            }
        ]
    }


def fetch_page(payload):
    result = subprocess.run(
        [
            "curl_chrome116", "-s", "-X", "POST", SEARCH_URL,
            "-H", f"x-typesense-api-key: {TYPESENSE_API_KEY}",
            "-H", "Content-Type: application/json",
            "-H", "Origin: https://urbanaut.app",
            "-H", "Referer: https://urbanaut.app/",
            "-H", "clienttz: Asia/Kolkata",
            "-H", "X-Timezone-Offset: -330",
            "-d", json.dumps(payload),
        ],
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def parse_date(date_str):
    return datetime.datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)


def get_age_range(x):
    tags = x.get("who_is_it_for_tags_data") or []
    audience = " ".join([y.get("path", "") for y in tags]).lower()
    # Drinking age in Delhi is 25
    if "adults_only" in audience:
        return "25+"
    elif "kid_friendly" in audience:
        return "2-"
    elif "for_all_ages" in audience:
        return "5+"
    elif "for_couples" in audience:
        return "16+"
    else:
        return "12+"


def get_event_type(x):
    tags = x.get("genre_tags_data") or []
    tag_str = " ".join([y.get("path", "") for y in tags]).lower()
    name = x.get("name", "").lower()
    if "screening" in name:
        return "ScreeningEvent"
    elif "food" in tag_str:
        return "FoodEvent"
    elif "workshop" in tag_str:
        return "EducationEvent"
    else:
        return "Event"


def get_keywords(x):
    tags = x.get("genre_tags_data") or []
    base = [y["name"] for y in tags if "name" in y]
    return base + ["URBANAUT"]


def make_event(x):
    desc = BeautifulSoup(x.get("short_description", ""), "html.parser").text

    # Use upcoming_session for startDate (next scheduled session)
    # Fall back to start if upcoming_session not present
    start_str = x.get("upcoming_session") or x.get("start")
    end_str = x.get("end")

    if not start_str:
        return

    start_dt = parse_date(start_str)
    end_dt = parse_date(end_str) if end_str else start_dt

    # For multi-day events, endDate may be after upcoming_session
    # Keep end_dt as-is so the event shows its full duration

    ad = x.get("account_data", {})
    url = f"https://urbanaut.app/spot/{x['slug']}"

    yield {
        "@context": "https://schema.org",
        "@type": get_event_type(x),
        "name": x["name"],
        "description": desc,
        "startDate": start_dt.isoformat(),
        "endDate": end_dt.isoformat(),
        "location": {
            "@type": "Place",
            "address": x.get("address", "Delhi"),
            "geo": {
                "@type": "GeoCoordinates",
                "latitude": x.get("lat"),
                "longitude": x.get("lng"),
            },
        },
        "eventAttendanceMode": "OfflineEventAttendanceMode",
        "eventStatus": "EventScheduled",
        "typicalAgeRange": get_age_range(x),
        "offers": {
            "@type": "Offer",
            "price": x.get("price_starts_at"),
            "priceCurrency": x.get("price_starts_at_currency", "INR"),
            "availability": "LimitedAvailability",
        },
        "organizer": {
            "@type": "Organization",
            "name": ad.get("company_name"),
            "url": f"https://urbanaut.app/partner/{ad['slug']}" if ad.get("slug") else None,
        },
        "url": url,
        "keywords": get_keywords(x),
    }


if __name__ == "__main__":
    events = []
    try:
        data = fetch_page(make_payload())
        hits = data["results"][0]["hits"]
        print(f"[URBANAUT] {len(hits)} spots found")
        for hit in hits:
            for event in make_event(hit["document"]):
                events.append(event)
    except Exception as e:
        print(f"[URBANAUT] Failed: {e}", file=sys.stderr)
    finally:
        with open("out/urbanaut.json", "w") as f:
            json.dump(events, f, indent=2)
        print(f"[URBANAUT] {len(events)} events written")