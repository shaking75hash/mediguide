import unittest
from unittest.mock import patch

from backend.osm_care_search import (
    _geocode_location,
    _element_kind,
    _specialty_matches,
    search_nearby_hospitals,
    search_nearby_doctors,
    specialty_for_concern,
)


class SpecialtySearchTests(unittest.TestCase):
    def test_heart_care_maps_to_cardiology(self):
        specialty, terms = specialty_for_concern("heart care")

        self.assertEqual(specialty, "cardiology")
        self.assertTrue(_specialty_matches("Cardiologist", terms))

    def test_fever_maps_to_general_practice(self):
        specialty, terms = specialty_for_concern("fever")

        self.assertEqual(specialty, "general practice")
        self.assertTrue(_specialty_matches("General Practitioner", terms))

    def test_normal_sickness_maps_to_general_practice(self):
        specialty, _ = specialty_for_concern("normal sickness")

        self.assertEqual(specialty, "general practice")

    def test_unrecognized_query_keeps_its_search_terms(self):
        specialty, terms = specialty_for_concern("dermatologist")

        self.assertEqual(specialty, "dermatology")
        self.assertTrue(_specialty_matches("Dermatology", terms))

    def test_only_doctor_and_hospital_tags_are_classified(self):
        self.assertEqual(_element_kind({"healthcare": "doctor"}), "doctor")
        self.assertEqual(_element_kind({"amenity": "hospital"}), "hospital")
        self.assertIsNone(_element_kind({"healthcare": "clinic"}))

    def test_heart_care_search_returns_tagged_cardiologists(self):
        providers = [
            {"name": "Dr Heart", "specialty": "Cardiology"},
            {"name": "Nearby Doctor", "specialty": "Specialty not listed"},
        ]
        with patch(
            "backend.osm_care_search._nearby_providers",
            return_value=(providers, "Kadirganj"),
        ):
            results = search_nearby_doctors("heart care", "Kadirganj")

        self.assertEqual([result["name"] for result in results], ["Dr Heart"])
        self.assertTrue(results[0]["specialty_match"])

    def test_general_care_falls_back_to_unlisted_nearby_doctors(self):
        providers = [
            {"name": "Nearby Doctor", "specialty": "Specialty not listed"},
        ]
        with patch(
            "backend.osm_care_search._nearby_providers",
            return_value=(providers, "Kadirganj"),
        ):
            results = search_nearby_doctors("fever", "Kadirganj")

        self.assertEqual([result["name"] for result in results], ["Nearby Doctor"])
        self.assertFalse(results[0]["specialty_match"])

    def test_geocoding_is_constrained_to_rajshahi(self):
        response = [
            {
                "lat": "24.374",
                "lon": "88.595",
                "display_name": "Kadirganj, Rajshahi, Bangladesh",
            }
        ]
        with patch(
            "backend.osm_care_search._request_json", return_value=response
        ) as request:
            location = _geocode_location("Kadirganj Test")

        self.assertEqual(location, (24.374, 88.595, "Kadirganj"))
        self.assertIn("Kadirganj+Test%2C+Rajshahi", request.call_args.args[0])

    def test_nearby_search_returns_map_coordinates_and_directions_source(self):
        elements = [
            {
                "type": "node",
                "id": 123,
                "lat": 24.375,
                "lon": 88.596,
                "tags": {
                    "name": "Rajshahi Heart Clinic",
                    "healthcare": "doctor",
                    "healthcare:speciality": "cardiology",
                },
            },
            {
                "type": "node",
                "id": 456,
                "lat": 24.376,
                "lon": 88.597,
                "tags": {"name": "Local Hospital", "amenity": "hospital"},
            },
        ]
        with (
            patch(
                "backend.osm_care_search._geocode_location",
                return_value=(24.374, 88.595, "Kadirganj"),
            ),
            patch(
                "backend.osm_care_search._get_nearby_elements",
                return_value=elements,
            ),
        ):
            results = search_nearby_doctors("heart care", "Kadirganj")

        self.assertEqual([result["name"] for result in results], ["Rajshahi Heart Clinic"])
        self.assertEqual(results[0]["source_url"], "https://www.openstreetmap.org/node/123")
        self.assertIsInstance(results[0]["latitude"], float)
        self.assertGreater(results[0]["distance_km"], 0)

    def test_hospital_search_filters_out_doctors(self):
        providers = [
            {"name": "Local Hospital", "source": "openstreetmap"},
        ]
        with patch(
            "backend.osm_care_search._nearby_providers",
            return_value=(providers, "Kadirganj"),
        ):
            results = search_nearby_hospitals("Kadirganj")

        self.assertEqual(results, providers)


if __name__ == "__main__":
    unittest.main()
