import unittest

from app.presentation.schemas import BuilderConfig
from app.presentation.service import DEFAULT_TEMPLATES, _subtopic_names, _topic_names


class PresentationSelectionTests(unittest.TestCase):
    def test_multiple_topics_and_subtopics_are_preserved(self):
        config = BuilderConfig(
            course="Biology",
            topic="Investigative Techniques and Drawing Biological Diagrams",
            subtopic="Safety Measures and Observation",
            topics=["Investigative Techniques", "Drawing Biological Diagrams"],
            topic_ids=[1, 2],
            subtopics=["Safety Measures", "Observation and Scientific Drawing"],
            subtopic_ids=[1, 3],
            template="Teal Modern",
        )

        self.assertEqual(_topic_names(config), config.topics)
        self.assertEqual(_subtopic_names(config), config.subtopics)
        self.assertEqual(config.topic_ids, [1, 2])
        self.assertEqual(config.subtopic_ids, [1, 3])

    def test_gallery_designs_have_backend_templates(self):
        gallery_names = [
            "Ocean Academic",
            "Midnight Aurora",
            "Sage Research",
            "Terracotta Studio",
            "Royal Indigo",
            "Citrus STEM",
            "Rose Clinical",
            "Slate Editorial",
            "Golden Lecture",
            "Teal Modern",
        ]

        self.assertEqual(len(gallery_names), 10)
        self.assertTrue(all(name in DEFAULT_TEMPLATES for name in gallery_names))


if __name__ == "__main__":
    unittest.main()
