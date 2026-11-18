import unittest

from backend.specialties import normalize_specialty


class SpecialtyNormalizationTests(unittest.TestCase):
    def test_normalizes_canonical_name_case_and_whitespace(self):
        self.assertEqual(normalize_specialty("  cArDiOlOgY "), "Cardiology")

    def test_normalizes_specialty_title(self):
        self.assertEqual(normalize_specialty("Cardiologist"), "Cardiology")

    def test_rejects_unapproved_specialty(self):
        self.assertIsNone(normalize_specialty("Surgeon"))


if __name__ == "__main__":
    unittest.main()
