"""Exercise the real ephemeral AWS provider against a local Secrets Manager stub.

Run: python3 -m unittest discover -s tests -p 'test_*.py' -v
Requires Terraform and the locked providers (run terraform init first).
No real credentials, cloud backend, or external API calls are used.
"""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[1]
TOKEN = "test-only-dynatrace-token-must-not-persist"
ARN = "arn:aws:secretsmanager:eu-west-2:123456789012:secret:test-AbCdEf"


class SecretHandlingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="dynatrace-secrets-test-")
        cls.work = Path(cls.temp.name)
        cls.payload = None
        cls.received_tokens = []

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                if self.headers.get("X-Amz-Target") == "secretsmanager.GetSecretValue":
                    if json.loads(body)["SecretId"] != ARN:
                        self.send_error(400)
                        return
                    response = json.dumps({
                        "ARN": ARN,
                        "Name": "test",
                        "VersionId": "01234567-89ab-cdef-0123-456789abcdef",
                        "SecretString": cls.payload,
                        "VersionStages": ["AWSCURRENT"],
                        "CreatedDate": 1700000000,
                    }).encode()
                    content_type = "application/x-amz-json-1.1"
                else:
                    cls.received_tokens.append(self.headers.get("X-Amz-Security-Token"))
                    response = b'''<GetCallerIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
                      <GetCallerIdentityResult><Account>123456789012</Account>
                      <Arn>arn:aws:iam::123456789012:user/test</Arn><UserId>test</UserId>
                      </GetCallerIdentityResult></GetCallerIdentityResponse>'''
                    content_type = "text/xml"
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.end_headers()
                self.wfile.write(response)

        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        for name in ("providers.tf", "variables.tf", "locals.tf", "secrets.tf", ".terraform.lock.hcl"):
            shutil.copy2(ROOT / name, cls.work / name)
        providers = (cls.work / "providers.tf").read_text()
        providers, removed = re.subn(r'\n  cloud \{.*?\n  \}\n', "\n", providers, count=1, flags=re.S)
        if removed != 1:
            raise AssertionError("Could not isolate the test from Terraform Cloud")
        (cls.work / "providers.tf").write_text(providers)

        endpoint = f"http://127.0.0.1:{cls.server.server_port}"
        overrides = []
        for alias in (None, "dynatrace_secrets"):
            # Feed the fetched token into an SDK provider, so STS confirms that
            # the ephemeral value reaches provider configuration without needing
            # a live Dynatrace tenant. Production Dynatrace wiring is unchanged.
            identity = '''access_key = local.dynatrace_platform_token
              secret_key = local.dynatrace_platform_token
              token = local.dynatrace_platform_token''' if alias is None else f'alias = "{alias}"'
            overrides.append(f'''provider "aws" {{
              {identity}
              skip_credentials_validation = true
              skip_requesting_account_id = true
              skip_metadata_api_check = true
              endpoints {{
                secretsmanager = "{endpoint}"
                sts = "{endpoint}"
              }}
            }}''')
        (cls.work / "test_override.tf").write_text("\n".join(overrides))
        (cls.work / "main.tf").write_text('''
          data "aws_caller_identity" "test" {}
          output "account_id" { value = data.aws_caller_identity.test.account_id }
          output "secret_arn" { value = var.dynatrace_secret_arn }
        ''')
        (cls.work / "terraform.tfvars.json").write_text(json.dumps({"dynatrace_secret_arn": ARN}))
        cls.env = {k: v for k, v in os.environ.items() if not k.startswith(("AWS_", "TF_", "DYNATRACE_"))}
        cls.env.update({
            "AWS_ACCESS_KEY_ID": "test-only-bootstrap-access-key",
            "AWS_SECRET_ACCESS_KEY": "test-only-bootstrap-secret-key",
            "AWS_EC2_METADATA_DISABLED": "true",
            "AWS_CONFIG_FILE": str(cls.work / "empty-config"),
            "AWS_SHARED_CREDENTIALS_FILE": str(cls.work / "empty-credentials"),
        })
        command = ["init", "-backend=false", "-input=false"]
        cache = ROOT / ".terraform" / "providers"
        if cache.is_dir():
            command.append(f"-plugin-dir={cache}")
        result = cls.run_tf(*command)
        if result.returncode:
            raise AssertionError(result.stdout)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
        cls.temp.cleanup()

    @classmethod
    def run_tf(cls, *args):
        return subprocess.run(["terraform", *args, "-no-color"], cwd=cls.work,
                              env=cls.env, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, timeout=60)

    def test_valid_secret_is_used_but_not_persisted(self):
        type(self).payload = json.dumps({"DYNATRACE_ENV_URL": "https://example.apps.dynatrace.com",
                                        "DYNATRACE_PLATFORM_TOKEN": TOKEN})
        self.received_tokens.clear()
        result = self.run_tf("plan", "-input=false", "-out=test.tfplan")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn(TOKEN, self.received_tokens)
        with ZipFile(self.work / "test.tfplan") as plan:
            artifacts = [plan.read(name) for name in plan.namelist()]
        result = self.run_tf("apply", "-input=false", "test.tfplan")
        self.assertEqual(result.returncode, 0, result.stdout)
        artifacts.append((self.work / "terraform.tfstate").read_bytes())
        for artifact in artifacts:
            for secret in (TOKEN, self.env["AWS_SECRET_ACCESS_KEY"]):
                self.assertNotIn(secret.encode(), artifact)
        state = json.loads((self.work / "terraform.tfstate").read_text())
        self.assertEqual(state["outputs"]["secret_arn"]["value"], ARN)
        self.assertNotIn("aws_secretsmanager_secret_version", [r["type"] for r in state["resources"]])

    def test_invalid_secrets_fail_without_disclosing_values(self):
        valid = {"DYNATRACE_ENV_URL": "https://example.apps.dynatrace.com", "DYNATRACE_PLATFORM_TOKEN": TOKEN}
        for payload in ("not-json", "{}", "[]", json.dumps({**valid, "DYNATRACE_PLATFORM_TOKEN": " "}),
                        json.dumps({**valid, "DYNATRACE_PLATFORM_TOKEN": None}),
                        json.dumps({**valid, "DYNATRACE_PLATFORM_TOKEN": 123}),
                        json.dumps({**valid, "DYNATRACE_ENV_URL": "http://example.com"}),
                        json.dumps({**valid, "DYNATRACE_ENV_URL": "https://example.com/path"})):
            with self.subTest(payload=payload):
                type(self).payload = payload
                result = self.run_tf("plan", "-input=false")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("The Dynatrace secret must be a JSON object", result.stdout)
                self.assertNotIn(TOKEN, result.stdout)


if __name__ == "__main__":
    unittest.main()
