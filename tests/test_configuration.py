import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from support import REPO


class ConfigurationTests(unittest.TestCase):
    def test_lf_previewer_parses_and_preserves_text_preview(self):
        previewer = REPO / "Configs/config/.config/lf/previewer/previewer.sh"
        parsed = subprocess.run(["bash", "-n", str(previewer)], capture_output=True, text=True)
        self.assertEqual(parsed.returncode, 0, parsed.stderr)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            document = root / "file with spaces.txt"
            document.write_text("preview content\n")
            bat = root / "bat"
            bat.write_text('#!/usr/bin/env bash\ncat -- "${@: -1}"\n')
            bat.chmod(0o755)
            result = subprocess.run(
                ["bash", str(previewer), str(document), "0", "0", "0", "0"],
                env={**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"]},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "preview content\n")

    @unittest.skipUnless(shutil.which("nvim"), "Neovim/LuaJIT is required for Lua import verification")
    def test_hyprland_module_execution_order(self):
        modules = ["env", "vars", "execs", "general", "rules", "colors", "keybinds", "input", "looks", "sonitor"]
        expected = "{" + ",".join('"hyprland.' + name + '"' for name in modules) + "}"
        script = '''
local expected = EXPECTED
local loaded = {}
for _, name in ipairs(expected) do
  package.preload[name] = function()
    table.insert(loaded, name)
    return true
  end
end
dofile(vim.env.DOTS_HYPR_ENTRY)
if not vim.deep_equal(loaded, expected) then
  error(vim.inspect(loaded))
end
'''.replace("EXPECTED", expected)
        script = 'local ok, err = pcall(function()\n' + script + '\nend)\nif not ok then print(err); vim.cmd("cquit") end'
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                ["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-n", "--cmd", "lua " + script, "+q"],
                env={**os.environ, "HOME": temporary, "NVIM_LOG_FILE": "/dev/null", "DOTS_HYPR_ENTRY": str(REPO / "Configs/config/.config/hypr/hyprland.lua")},
                capture_output=True, text=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("Error", result.stderr)
