import json
import sys
import curl_cffi
from datetime import datetime
from common.tz import IST

BASE_URL = "https://www.adidas.co.in/adidasrunners"
COMMUNITY_ID = "9a60ba1f-dac1-47db-a6bf-2c6953c6ecd0"
COUNTRY_CODE = "IN"
BROWSER_CODE = "safari18_4_ios"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; blr.today-bot; +https://blr.today/bot/)"
}


def _date(date_str):
    return datetime.fromisoformat(date_str).astimezone(IST).isoformat()


def fetch_events():
    events = []
    url = f"{BASE_URL}/ar-api/gw/default/gw-api/v2/events/communities/{COMMUNITY_ID}?countryCodes={COUNTRY_CODE}"
    body = curl_cffi.get(url, impersonate=BROWSER_CODE, headers=HEADERS).content
    res = json.loads(body)
    for data in res["_embedded"]["events"]:
        location = data["meta"]["adidas_runners_locations"]
        _id = data["id"]
        events.append(
            {
                "name": "Adidas Runners " + data["title"],
                "about": data["description"],
                "url": f"https://www.adidas.co.in/adidasrunners/events/event/{_id}",
                "startDate": _date(data["eventStartDate"]),
                "endDate": _date(data["eventStartDate"]),
                "image": data["_links"]["img"]["href"],
                "location": {
                    "@type": "Place",
                    "name": location,
                    "address": location + ", New Delhi",
                },
            }
        )
    return events


def main():
    events = []
    try:
        events = fetch_events()
    except Exception as e:
        print(f"[ADIDAS] Failed: {e}", file=sys.stderr)
    with open("out/adidas.json", "w") as f:
        json.dump(events, f, indent=2)
    print(f"[ADIDAS] {len(events)} events")


if __name__ == "__main__":
    main()