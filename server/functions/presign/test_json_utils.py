import sys
import unittest
from decimal import Decimal
from pathlib import Path


MODULE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(MODULE_DIR))

from json_utils import loads_for_dynamodb


class JsonUtilsTests(unittest.TestCase):
    def test_nested_decimal_sensor_rates_are_dynamodb_compatible(self):
        body = loads_for_dynamodb(
            '{"sensor_manifest":{"accelerometer":'
            '{"available":true,"observed_hz":49.75}}}'
        )

        self.assertEqual(
            body["sensor_manifest"]["accelerometer"]["observed_hz"],
            Decimal("49.75"),
        )

    def test_integers_remain_integers(self):
        body = loads_for_dynamodb('{"sample_count":10}')

        self.assertEqual(body["sample_count"], 10)
        self.assertIsInstance(body["sample_count"], int)


if __name__ == "__main__":
    unittest.main()
