import base64
import json
import unittest

from collect_hazard_benchmark import MARKER, collect


class CollectorTest(unittest.TestCase):
    def setUp(self):
        self.payload = {"case": "village-eight", "label": "そば屋", "cpu": 142.5}
        encoded = base64.b64encode(json.dumps(self.payload, ensure_ascii=False).encode()).decode()
        self.chunks = [{"id": "run-1", "part": i + 1, "total": 2, "data": part}
                       for i, part in enumerate([encoded[:24], encoded[24:]])]

    def lines(self, chunks):
        return ["[stdout] flutter: " + MARKER + json.dumps(chunk) for chunk in chunks]

    def test_reordered_duplicate_and_unicode(self):
        lines = self.lines([self.chunks[1], self.chunks[0], self.chunks[1]])
        self.assertEqual(collect(["truncated legacy log", *lines]), {"run-1": self.payload})

    def test_missing_chunk(self):
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            collect(self.lines(self.chunks[:1]))

    def test_conflicting_duplicate(self):
        with self.assertRaisesRegex(ValueError, "Conflicting part"):
            collect(self.lines([*self.chunks, {**self.chunks[0], "data": "AAAA"}]))

    def test_conflicting_total(self):
        with self.assertRaisesRegex(ValueError, "Conflicting total"):
            collect(self.lines([self.chunks[0], {**self.chunks[1], "total": 3}]))

    def test_bad_base64(self):
        with self.assertRaises(ValueError):
            collect(self.lines([{**self.chunks[0], "total": 1, "data": "!"}]))

    def test_id_cannot_escape_output_directory(self):
        with self.assertRaisesRegex(ValueError, "Invalid chunk id"):
            collect(self.lines([{**self.chunks[0], "id": "../escape"}]))

    def test_no_chunks_is_not_a_success(self):
        with self.assertRaisesRegex(ValueError, "No benchmark"):
            collect([])


if __name__ == "__main__":
    unittest.main()
