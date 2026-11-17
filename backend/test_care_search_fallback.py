import unittest
from unittest.mock import Mock, patch

from backend.main import (
    _search_directory_doctors,
    search_nearby_doctors_endpoint,
)
from backend.osm_care_search import CareSearchError


class DirectoryFallbackTests(unittest.TestCase):
    def test_fever_search_maps_to_local_general_physician(self):
        cursor = Mock()
        cursor.fetchall.return_value = [
            (7, "Dr. Jahangir Alam", "General Physician", "Rajshahi", 500, True)
        ]
        connection = Mock()
        connection.cursor.return_value = cursor

        with patch("backend.main.get_db_connection", return_value=connection):
            results = _search_directory_doctors("Fever", "Rajshahi")

        self.assertEqual(results[0]["name"], "Dr. Jahangir Alam")
        self.assertTrue(results[0]["specialty_match"])
        self.assertEqual(results[0]["source"], "local_directory")
        query, parameters = cursor.execute.call_args.args
        self.assertIn("location ILIKE %s", query)
        self.assertIn("%general physician%", parameters)

    def test_kadirganj_uses_city_level_rajshahi_doctor_entries(self):
        cursor = Mock()
        cursor.fetchall.return_value = [
            (1, "Dr. Abdul Mannan", "Cardiologist", "Rajshahi", 1000, True)
        ]
        connection = Mock()
        connection.cursor.return_value = cursor

        with patch("backend.main.get_db_connection", return_value=connection):
            results = _search_directory_doctors("heart care", "Kadirganj")

        self.assertEqual(results[0]["location"], "Rajshahi")
        self.assertTrue(results[0]["specialty_match"])
        self.assertIn("%Kadirganj%", cursor.execute.call_args.args[1])
        self.assertIn("%Rajshahi%", cursor.execute.call_args.args[1])

    def test_uses_local_directory_when_openstreetmap_is_unavailable(self):
        directory_results = [
            {"name": "Dr. Jahangir Alam", "source": "local_directory"}
        ]
        with (
            patch(
                "backend.main.search_nearby_doctors",
                side_effect=CareSearchError(
                    503, "OpenStreetMap search is temporarily unavailable."
                ),
            ),
            patch(
                "backend.main._search_directory_doctors",
                return_value=directory_results,
            ),
        ):
            results = search_nearby_doctors_endpoint("fever", "Rajshahi")

        self.assertEqual(results, directory_results)

    def test_doctor_search_defaults_missing_location_to_rajshahi(self):
        map_results = [{"name": "Nearby Doctor"}]
        with patch(
            "backend.main.search_nearby_doctors", return_value=map_results
        ) as search:
            results = search_nearby_doctors_endpoint("cardiologist")

        self.assertEqual(results, map_results)
        search.assert_called_once_with("cardiologist", "Rajshahi")

    def test_doctor_search_defaults_blank_location_to_rajshahi(self):
        map_results = [{"name": "Nearby Doctor"}]
        with patch(
            "backend.main.search_nearby_doctors", return_value=map_results
        ) as search:
            results = search_nearby_doctors_endpoint("cardiologist", "  ")

        self.assertEqual(results, map_results)
        search.assert_called_once_with("cardiologist", "Rajshahi")


if __name__ == "__main__":
    unittest.main()
