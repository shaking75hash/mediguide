APPROVED_SPECIALTIES = {
    "General Practice",
    "Cardiology",
    "Neurology",
    "Dermatology",
    "Pediatrics",
    "Orthopedics",
    "Gynecology",
    "Psychiatry",
}

_SPECIALTY_ALIASES = {
    "general physician": "General Practice",
    "general practitioner": "General Practice",
    "cardiologist": "Cardiology",
    "neurologist": "Neurology",
    "dermatologist": "Dermatology",
    "pediatrician": "Pediatrics",
    "orthopedist": "Orthopedics",
    "orthopaedist": "Orthopedics",
    "gynecologist": "Gynecology",
    "gynaecologist": "Gynecology",
    "psychiatrist": "Psychiatry",
}

_CANONICAL_SPECIALTIES = {
    specialty.casefold(): specialty for specialty in APPROVED_SPECIALTIES
}


def normalize_specialty(value: str) -> str | None:
    normalized = " ".join(value.split()).casefold()
    return _CANONICAL_SPECIALTIES.get(normalized) or _SPECIALTY_ALIASES.get(
        normalized
    )
