import re


MODERATION_RULES = {
    "bullying": [
        "stupid",
        "idiot",
        "loser",
        "worthless"
    ],
    "hate_speech": [
        "hate",
        "kill",
        "destroy"
    ],
    "spam": [
        "buy now",
        "click here",
        "free money"
    ]
}


def analyze_content(text: str):
    """
    Basic AI moderation engine.
    Returns detected category and confidence.
    """

    if not text:
        return {
            "flagged": False,
            "category": None,
            "confidence": 0
        }

    content = text.lower()

    for category, keywords in MODERATION_RULES.items():
        for keyword in keywords:
            if keyword in content:
                return {
                    "flagged": True,
                    "category": category,
                    "confidence": 0.85
                }

    return {
        "flagged": False,
        "category": None,
        "confidence": 0.0
    }