import unittest

import torch

import train_value_net


class TrainValueNetRuntimeConfigTests(unittest.TestCase):
    def test_resolve_device_prefers_explicit_cpu(self):
        device = train_value_net.resolve_device("cpu")
        self.assertEqual(device.type, "cpu")

    def test_resolve_device_auto_matches_cuda_availability(self):
        device = train_value_net.resolve_device("auto")
        expected = "cuda" if torch.cuda.is_available() else "cpu"
        self.assertEqual(device.type, expected)

    def test_build_runtime_config_uses_safe_cpu_defaults(self):
        config = train_value_net.build_runtime_config(
            requested_device="cpu",
            num_threads=1,
            interop_threads=1,
        )
        self.assertEqual(config["device"].type, "cpu")
        self.assertEqual(config["num_threads"], 1)
        self.assertEqual(config["interop_threads"], 1)


if __name__ == "__main__":
    unittest.main()
