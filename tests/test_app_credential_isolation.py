import ast
import contextlib
import importlib
import io
import os
from pathlib import Path
import sys
import unittest
from unittest import mock


APP_PATH = Path(__file__).resolve().parents[1] / "app.py"
CREDENTIAL_ENV_VARS = {"GOOGLE_API_KEY", "OPENROUTER_API_KEY"}


class AppCredentialIsolationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = APP_PATH.read_text(encoding="utf-8")
        cls.tree = ast.parse(cls.source, filename=str(APP_PATH))

    def test_app_does_not_assign_api_keys_to_os_environ(self):
        writes = []

        for node in ast.walk(self.tree):
            if isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                for target in targets:
                    env_var = self._os_environ_subscript_key(target)
                    if env_var in CREDENTIAL_ENV_VARS:
                        writes.append((env_var, node.lineno))

        self.assertEqual([], writes)

    def test_app_does_not_mutate_api_keys_through_os_calls(self):
        mutations = []

        for node in ast.walk(self.tree):
            if not isinstance(node, ast.Call):
                continue

            if self._is_os_putenv_call(node) and self._first_constant_arg(node) in CREDENTIAL_ENV_VARS:
                mutations.append(("os.putenv", node.lineno))

            if self._is_os_environ_setitem_call(node) and self._first_constant_arg(node) in CREDENTIAL_ENV_VARS:
                mutations.append(("os.environ.__setitem__", node.lineno))

        self.assertEqual([], mutations)

    def test_no_apply_keys_callback_remains(self):
        function_names = {
            node.name
            for node in ast.walk(self.tree)
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        }
        self.assertNotIn("apply_keys", function_names)
        self.assertNotIn("Apply Keys", self._string_constants())

        click_bindings = []
        for node in ast.walk(self.tree):
            if not isinstance(node, ast.Call):
                continue
            if not isinstance(node.func, ast.Attribute) or node.func.attr != "click":
                continue
            if node.args and isinstance(node.args[0], ast.Name) and node.args[0].id == "apply_keys":
                click_bindings.append(node.lineno)

        self.assertEqual([], click_bindings)

    def test_no_api_key_password_textboxes_remain(self):
        key_textboxes = []

        for node in ast.walk(self.tree):
            if not isinstance(node, ast.Call) or not self._is_gradio_constructor(node, "Textbox"):
                continue
            keywords = {keyword.arg: keyword.value for keyword in node.keywords}
            textbox_type = self._constant_value(keywords.get("type"))
            label = self._constant_value(keywords.get("label"))
            if textbox_type == "password" and isinstance(label, str) and "API Key" in label:
                key_textboxes.append((label, node.lineno))

        self.assertEqual([], key_textboxes)

    def test_api_key_reads_are_not_bound_to_gradio_component_values(self):
        leaks = []

        for node in ast.walk(self.tree):
            if not isinstance(node, ast.Call) or not self._is_gradio_constructor_call(node):
                continue
            for keyword in node.keywords:
                if keyword.arg != "value":
                    continue
                env_var = self._credential_get_config_env_var(keyword.value)
                if env_var in CREDENTIAL_ENV_VARS:
                    leaks.append((node.func.attr, env_var, node.lineno))

        self.assertEqual([], leaks)

    def test_runtime_ui_config_does_not_render_sentinel_api_keys(self):
        sentinels = {
            "OPENROUTER_API_KEY": "sentinel-openrouter-key-credential-isolation",
            "GOOGLE_API_KEY": "sentinel-google-key-credential-isolation",
        }

        stdout = io.StringIO()
        stderr = io.StringIO()
        self._clear_app_modules()
        try:
            with (
                mock.patch.dict(os.environ, sentinels, clear=False),
                mock.patch("shutil.copy2"),
                mock.patch("google.genai.Client"),
                mock.patch("openai.AsyncOpenAI"),
                mock.patch("anthropic.AsyncAnthropic"),
                contextlib.redirect_stdout(stdout),
                contextlib.redirect_stderr(stderr),
            ):
                app_module = importlib.import_module("app")
                interface = app_module.build_app()
                config_text = str(interface.get_config_file())
        finally:
            self._clear_app_modules()

        captured = "\n".join([stdout.getvalue(), stderr.getvalue(), config_text])
        for secret in sentinels.values():
            self.assertNotIn(secret, captured)

    @staticmethod
    def _clear_app_modules():
        for module_name in list(sys.modules):
            if (
                module_name == "app"
                or module_name == "agents"
                or module_name.startswith("agents.")
                or module_name == "utils"
                or module_name.startswith("utils.")
            ):
                sys.modules.pop(module_name, None)

    def _string_constants(self):
        return {
            node.value
            for node in ast.walk(self.tree)
            if isinstance(node, ast.Constant) and isinstance(node.value, str)
        }

    @staticmethod
    def _constant_value(node):
        if isinstance(node, ast.Constant):
            return node.value
        return None

    @classmethod
    def _first_constant_arg(cls, node):
        if not node.args:
            return None
        return cls._constant_value(node.args[0])

    @staticmethod
    def _is_gradio_constructor(node, name):
        return (
            isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "gr"
            and node.func.attr == name
        )

    @staticmethod
    def _is_gradio_constructor_call(node):
        return (
            isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "gr"
        )

    @classmethod
    def _credential_get_config_env_var(cls, node):
        if not (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "get_config_val"
            and len(node.args) >= 3
        ):
            return None
        return cls._constant_value(node.args[2])

    @classmethod
    def _os_environ_subscript_key(cls, target):
        if not isinstance(target, ast.Subscript):
            return None
        if not (
            isinstance(target.value, ast.Attribute)
            and isinstance(target.value.value, ast.Name)
            and target.value.value.id == "os"
            and target.value.attr == "environ"
        ):
            return None
        return cls._constant_value(target.slice)

    @staticmethod
    def _is_os_putenv_call(node):
        return (
            isinstance(node.func, ast.Attribute)
            and isinstance(node.func.value, ast.Name)
            and node.func.value.id == "os"
            and node.func.attr == "putenv"
        )

    @staticmethod
    def _is_os_environ_setitem_call(node):
        return (
            isinstance(node.func, ast.Attribute)
            and node.func.attr == "__setitem__"
            and isinstance(node.func.value, ast.Attribute)
            and isinstance(node.func.value.value, ast.Name)
            and node.func.value.value.id == "os"
            and node.func.value.attr == "environ"
        )


if __name__ == "__main__":
    unittest.main()
