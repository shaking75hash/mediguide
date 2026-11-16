import json
import math
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


RAJSHAHI_SEARCH_RADIUS_METERS = 8_000
_RAJSHAHI_BOUNDS = (24.15, 24.60, 88.30, 88.85)
_USER_AGENT = "MediGuide/1.0 (+https://github.com/shaking75hash/mediguide)"
_GEOCODE_CACHE_SECONDS = 24 * 60 * 60
_FACILITY_CACHE_SECONDS = 30 * 60
_RESULT_LIMIT = 40

_geocode_cache: dict[str, tuple[float, tuple[float, float, str]]] = {}
_facility_cache: dict[str, tuple[float, list[dict[str, Any]]]] = {}
_geocode_lock = threading.Lock()
_facility_lock = threading.Lock()
_last_geocode_request = 0.0
_last_facility_request = 0.0


class CareSearchError(Exception):
    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code


def _normalize(value: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[_-]+", " ", value.lower())).strip()


def _contains_word(text: str, word: str) -> bool:
    return re.search(rf"\b{re.escape(word)}\b", text) is not None


def specialty_for_concern(query: str) -> tuple[str | None, tuple[str, ...]]:
    text = _normalize(query)
    if any(
        _contains_word(text, word)
        for word in ("heart", "cardiac", "cardiology", "cardiologist")
    ):
        return "cardiology", ("cardiolog", "cardiac")
    if any(
        _contains_word(text, word)
        for word in (
            "fever",
            "flu",
            "cold",
            "cough",
            "sickness",
            "physician",
            "primary care",
            "family doctor",
        )
    ):
        return "general practice", (
            "general practice",
            "general practitioner",
            "general physician",
            "general medicine",
            "primary care",
            "family medicine",
            "internal medicine",
        )
    if any(
        _contains_word(text, word)
        for word in ("skin", "rash", "acne", "dermatology", "dermatologist")
    ):
        return "dermatology", ("dermatolog",)
    if any(
        _contains_word(text, word)
        for word in ("child", "children", "pediatric", "paediatric")
    ):
        return "pediatrics", ("pediatric", "paediatric")
    if any(
        _contains_word(text, word)
        for word in ("eye", "vision", "ophthalmology", "ophthalmologist")
    ):
        return "ophthalmology", ("ophthalmolog",)

    ignored_words = {"a", "an", "and", "care", "doctor", "for", "the"}
    terms = tuple(
        word for word in re.findall(r"[a-z0-9]+", text) if word not in ignored_words
    )
    return None, terms


def _geocode_location(location: str) -> tuple[float, float, str]:
    global _last_geocode_request

    normalized_location = _normalize(location)
    if not normalized_location:
        raise CareSearchError(422, "Enter a Rajshahi city or area.")

    with _geocode_lock:
        cached = _geocode_cache.get(normalized_location)
        now = time.monotonic()
        if cached is not None and cached[0] > now:
            return cached[1]

        delay = 1.0 - (now - _last_geocode_request)
        if delay > 0:
            time.sleep(delay)

        query = location.strip()
        if "rajshahi" not in _normalize(query):
            query = f"{query}, Rajshahi"
        if "bangladesh" not in _normalize(query):
            query = f"{query}, Bangladesh"
        params = urllib.parse.urlencode(
            {
                "q": query,
                "format": "jsonv2",
                "limit": "1",
                "countrycodes": "bd",
                "viewbox": "88.85,24.60,88.30,24.15",
                "bounded": "1",
            }
        )
        base_url = os.getenv(
            "OSM_NOMINATIM_URL", "https://nominatim.openstreetmap.org/search"
        ).rstrip("/")
        _last_geocode_request = time.monotonic()
        data = _request_json(f"{base_url}?{params}")

        if not isinstance(data, list) or not data:
            raise CareSearchError(
                404,
                "That location was not found in Rajshahi. Try a nearby area or Rajshahi.",
            )

        try:
            lat = float(data[0]["lat"])
            lon = float(data[0]["lon"])
        except (KeyError, TypeError, ValueError) as error:
            raise CareSearchError(
                503, "OpenStreetMap returned an invalid location. Please try again."
            ) from error

        south, north, west, east = _RAJSHAHI_BOUNDS
        if not (south <= lat <= north and west <= lon <= east):
            raise CareSearchError(
                404,
                "That location was not found in Rajshahi. Try a nearby area or Rajshahi.",
            )

        display_name = str(data[0].get("display_name", location)).split(",")
        result = (lat, lon, display_name[0].strip())
        _geocode_cache[normalized_location] = (
            time.monotonic() + _GEOCODE_CACHE_SECONDS,
            result,
        )
        return result


def _request_json(
    url: str, data: bytes | None = None, timeout: int = 10
) -> Any:
    headers = {
        "Accept": "application/json",
        "User-Agent": _USER_AGENT,
    }
    if data is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except (
        urllib.error.URLError,
        TimeoutError,
        OSError,
        json.JSONDecodeError,
    ) as error:
        raise CareSearchError(
            503, "OpenStreetMap search is temporarily unavailable. Please try again."
        ) from error


def _get_nearby_elements(lat: float, lon: float) -> list[dict[str, Any]]:
    global _last_facility_request

    cache_key = f"{lat:.4f},{lon:.4f}"
    with _facility_lock:
        cached = _facility_cache.get(cache_key)
        now = time.monotonic()
        if cached is not None and cached[0] > now:
            return cached[1]

        delay = 1.0 - (now - _last_facility_request)
        if delay > 0:
            time.sleep(delay)

        endpoint = os.getenv(
            "OSM_OVERPASS_URL", "https://overpass-api.de/api/interpreter"
        ).rstrip("/")
        query = (
            "[out:json][timeout:20];("
            f'nwr(around:{RAJSHAHI_SEARCH_RADIUS_METERS},{lat},{lon})'
            '["healthcare"~"^(doctor|specialist|hospital)$"];'
            f'nwr(around:{RAJSHAHI_SEARCH_RADIUS_METERS},{lat},{lon})'
            '["amenity"~"^(doctors|hospital)$"];'
            ");out center;"
        )
        data = urllib.parse.urlencode({"data": query}).encode("ascii")
        _last_facility_request = time.monotonic()
        result = _request_json(endpoint, data, timeout=8)
        if not isinstance(result, dict) or not isinstance(
            result.get("elements"), list
        ):
            raise CareSearchError(
                503, "OpenStreetMap returned invalid provider data. Please try again."
            )

        elements = [
            element for element in result["elements"] if isinstance(element, dict)
        ]
        _facility_cache[cache_key] = (
            time.monotonic() + _FACILITY_CACHE_SECONDS,
            elements,
        )
        return elements


def _element_coordinates(element: dict[str, Any]) -> tuple[float, float] | None:
    coordinates = element.get("center", element)
    if not isinstance(coordinates, dict):
        return None
    try:
        return float(coordinates["lat"]), float(coordinates["lon"])
    except (KeyError, TypeError, ValueError):
        return None


def _distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    earth_radius_km = 6371.0
    lat_delta = math.radians(lat2 - lat1)
    lon_delta = math.radians(lon2 - lon1)
    distance = (
        math.sin(lat_delta / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(lon_delta / 2) ** 2
    )
    return earth_radius_km * 2 * math.atan2(math.sqrt(distance), math.sqrt(1 - distance))


def _element_kind(tags: dict[str, Any]) -> str | None:
    healthcare = _normalize(str(tags.get("healthcare", "")))
    amenity = _normalize(str(tags.get("amenity", "")))
    if healthcare == "hospital" or amenity == "hospital":
        return "hospital"
    if healthcare in {"doctor", "specialist"} or amenity == "doctors":
        return "doctor"
    return None


def _element_specialty(tags: dict[str, Any]) -> str:
    for key in (
        "healthcare:speciality",
        "healthcare:specialty",
        "doctor:speciality",
        "specialty",
        "speciality",
    ):
        value = tags.get(key)
        if value:
            return str(value).replace("_", " ").replace(";", ", ").title()
    return "Specialty not listed"


def _specialty_matches(specialty: str, terms: tuple[str, ...]) -> bool:
    if not terms:
        return False
    normalized_specialty = _normalize(specialty)
    return any(term in normalized_specialty for term in terms)


def _make_provider(
    element: dict[str, Any],
    search_lat: float,
    search_lon: float,
    search_location: str,
) -> dict[str, Any] | None:
    tags = element.get("tags")
    coordinates = _element_coordinates(element)
    if not isinstance(tags, dict) or coordinates is None or not tags.get("name"):
        return None

    lat, lon = coordinates
    element_type = element.get("type")
    element_id = element.get("id")
    if element_type not in {"node", "way", "relation"} or element_id is None:
        return None

    location_parts = [
        tags.get("addr:suburb") or tags.get("addr:neighbourhood"),
        tags.get("addr:city") or tags.get("addr:district"),
    ]
    provider_location = ", ".join(
        str(part) for part in location_parts if part
    ) or f"Near {search_location}"
    distance = _distance_km(search_lat, search_lon, lat, lon)
    return {
        "id": f"{element_type}/{element_id}",
        "name": str(tags["name"]),
        "specialty": _element_specialty(tags),
        "category": str(tags.get("healthcare", tags.get("amenity", "Hospital"))),
        "location": provider_location,
        "latitude": lat,
        "longitude": lon,
        "distance_km": round(distance, 1),
        "phone": tags.get("contact:phone") or tags.get("phone"),
        "source": "openstreetmap",
        "source_url": f"https://www.openstreetmap.org/{element_type}/{element_id}",
    }


def _nearby_providers(
    location: str, kind: str
) -> tuple[list[dict[str, Any]], str]:
    search_lat, search_lon, search_location = _geocode_location(location)
    elements = _get_nearby_elements(search_lat, search_lon)
    providers: list[dict[str, Any]] = []
    seen: set[tuple[str, int, int]] = set()

    for element in elements:
        tags = element.get("tags")
        if not isinstance(tags, dict) or _element_kind(tags) != kind:
            continue
        provider = _make_provider(element, search_lat, search_lon, search_location)
        if provider is None:
            continue
        dedupe_key = (
            _normalize(provider["name"]),
            round(provider["latitude"] * 10000),
            round(provider["longitude"] * 10000),
        )
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        providers.append(provider)

    providers.sort(key=lambda provider: (provider["distance_km"], provider["name"]))
    return providers, search_location


def search_nearby_doctors(query: str, location: str) -> list[dict[str, Any]]:
    specialty, terms = specialty_for_concern(query)
    if not query.strip():
        raise CareSearchError(422, "Enter a health concern or specialty.")

    providers, _ = _nearby_providers(location, "doctor")
    matched = [
        provider
        for provider in providers
        if _specialty_matches(provider["specialty"], terms)
        or any(
            term in _normalize(provider["name"])
            for term in terms
            if len(term) >= 3
        )
    ]
    if matched:
        results = matched
    elif specialty is not None:
        results = [
            provider
            for provider in providers
            if provider["specialty"] == "Specialty not listed"
        ]
    else:
        results = []

    for provider in results:
        provider["specialty_match"] = _specialty_matches(
            provider["specialty"], terms
        )
    return results[:_RESULT_LIMIT]


def search_nearby_hospitals(location: str) -> list[dict[str, Any]]:
    hospitals, _ = _nearby_providers(location, "hospital")
    return hospitals[:_RESULT_LIMIT]
