import unittest
from typing import Any, cast
from unittest import mock

from cis_k8s_unified import CISUnifiedRunner
from modules.cis_level2_remediation import NetworkPolicyTask
from modules.verification_utils import verify_with_retry


class VerificationLoopTest(unittest.TestCase):
    def test_audit_passes_on_third_retry(self):
        attempts = {"count": 0}

        def failing_then_passing():
            attempts["count"] += 1
            if attempts["count"] < 3:
                return "FAIL", f"attempt {attempts['count']}"
            return "PASS", "success"

        with mock.patch("modules.verification_utils.is_component_ready", return_value=True), mock.patch(
            "modules.verification_utils.time.sleep", return_value=None
        ):
            status, reason = verify_with_retry(
                failing_then_passing,
                "test.check",
                component_name="kube-apiserver",
                max_retries=5,
                timeout=100,
                sleep_interval=0,
            )

        self.assertEqual(status, "PASS")
        self.assertEqual(reason, "success")
        self.assertEqual(attempts["count"], 3)


class ExemptionTest(unittest.TestCase):
    def test_exempt_rule_is_skipped(self):
        runner = object.__new__(CISUnifiedRunner)
        runner.stop_requested = False
        runner.excluded_rules = {"1.1.1": "EXEMPT"}
        runner.component_mapping = {}
        runner.remediation_checks_config = {}
        runner.remediation_config = {}
        runner.remediation_env_vars = {}
        runner.variables = {}
        script = {"id": "1.1.1", "role": "master", "level": "L1", "path": "/dev/null"}

        result = runner.run_script(script, mode="audit")

        self.assertIsNotNone(result)
        result = cast(dict[str, Any], result)

        self.assertEqual(result["status"], "IGNORED")
        self.assertIn("Excluded", result["reason"])


class ConfigLogicTest(unittest.TestCase):
    def test_log_only_prevents_perform_call(self):
        config = {"log_only": True}
        task = NetworkPolicyTask(config, kubectl_cmd=["kubectl"])

        with mock.patch.object(NetworkPolicyTask, "apply") as mock_apply:
            task.run()

        mock_apply.assert_not_called()


if __name__ == "__main__":
    unittest.main()
