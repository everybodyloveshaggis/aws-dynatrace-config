"""Run mocked application tests with the real ephemeral provider on localhost.

Terraform 1.15 has no mock ephemeral resource support. Only Secrets Manager uses
the real AWS provider; SSM and Dynatrace are mocked in routing.tftest.hcl.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import unittest

from terraform_test_support import without_cloud_backend


ROOT = Path(__file__).resolve().parents[1]
APPLICATION = ROOT / "terraform" / "components" / "application"
ARN = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:test-AbCdEf"


class ApplicationTest(unittest.TestCase):
    def test_account_routing_and_iam_activation(self):
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                requests.append((self.headers.get("X-Amz-Target"), request))
                if requests[-1] != ("secretsmanager.GetSecretValue", {"SecretId": ARN}):
                    self.send_error(400, "Unexpected request")
                    return
                response = json.dumps({
                    "ARN": ARN,
                    "Name": "test",
                    "VersionId": "01234567-89ab-cdef-0123-456789abcdef",
                    "SecretString": json.dumps({
                        "DYNATRACE_ENV_URL": "https://example.apps.dynatrace.com",
                        "DYNATRACE_PLATFORM_TOKEN": "test-only-platform-token",
                        "DYNATRACE_API_TOKEN": "test-only-classic-token",
                    }),
                    "VersionStages": ["AWSCURRENT"],
                    "CreatedDate": 1700000000,
                }).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/x-amz-json-1.1")
                self.end_headers()
                self.wfile.write(response)

        with tempfile.TemporaryDirectory(prefix="dynatrace-application-test-") as directory:
            sandbox = Path(directory)
            work = sandbox / "terraform" / "components" / "application"
            shutil.copytree(APPLICATION, work, ignore=shutil.ignore_patterns(".terraform", "*.tfstate*", "*.tfvars", "*.tfvars.json"))
            shutil.copytree(ROOT / "terraform" / "modules", sandbox / "terraform" / "modules",
                            ignore=shutil.ignore_patterns(".terraform", "*.tfstate*"))
            versions = work / "versions.tf"
            versions.write_text(without_cloud_backend(versions.read_text()))
            env = {key: value for key, value in os.environ.items()
                   if not key.startswith(("AWS_", "TF_", "DYNATRACE_"))}
            env.update({
                "AWS_EC2_METADATA_DISABLED": "true",
                "AWS_CONFIG_FILE": str(sandbox / "empty-config"),
                "AWS_SHARED_CREDENTIALS_FILE": str(sandbox / "empty-credentials"),
            })

            def terraform(*args):
                result = subprocess.run(["terraform", *args, "-no-color"], cwd=work, env=env,
                                        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        timeout=180)
                self.assertEqual(result.returncode, 0, result.stdout)
                return result.stdout

            arguments = ["init", "-backend=false", "-input=false"]
            for cache in (APPLICATION / ".terraform" / "providers", ROOT / ".terraform" / "providers"):
                if cache.is_dir():
                    arguments.append(f"-plugin-dir={cache}")
                    break
            terraform(*arguments)
            server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                routing_test = work / "tests" / "routing.tftest.hcl"
                test_config, replaced = re.subn(
                    r'http://127\.0\.0\.1:1"', f'http://127.0.0.1:{server.server_port}"',
                    routing_test.read_text())
                self.assertEqual(replaced, 1, "Could not set the local Secrets Manager endpoint")
                routing_test.write_text(test_config)
                output = terraform("test", "-filter=tests/routing.tftest.hcl")
                self.assertIn("12 passed, 0 failed", output)
                self.assertGreater(len(requests), 0, "The aliased ephemeral provider did not read the secret")
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == "__main__":
    unittest.main()
