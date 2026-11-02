import json
import os
import shutil
import subprocess
import tempfile
import unittest

from support import REPO


@unittest.skipUnless(shutil.which("nvim"), "Neovim/LuaJIT is required for color extraction checks")
class MpvAccentTests(unittest.TestCase):
    def run_lua(self, body):
        module = REPO / "Configs/config/.config/mpv/script-modules/video-accent.lua"
        script = "local extract = dofile(" + json.dumps(str(module)) + ")\n" + '''
local function frame(r, g, b, padding)
    local row = string.rep(string.char(b, g, r, 0), 32) .. string.rep("x", padding or 0)
    return {format = "bgr0", w = 32, h = 18, stride = #row, data = string.rep(row, 18)}
end
''' + body
        script = 'local ok, err = pcall(function()\n' + script + '\nend)\nif not ok then print(err); vim.cmd("cquit") end'
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.run(
                ["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-n", "--cmd", "lua " + script, "+q"],
                env={**os.environ, "HOME": temporary, "NVIM_LOG_FILE": "/dev/null"},
                capture_output=True, text=True, timeout=10,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Error", result.stderr)

    def test_video_color_and_handle_match_with_padded_rows(self):
        self.run_lua('''
for _, rgb in ipairs({{220, 60, 40}, {50, 110, 220}, {80, 190, 90}}) do
    local palette = extract(frame(rgb[1], rgb[2], rgb[3], 12))
    assert(palette.seekbarfg_color == string.format("#%02X%02X%02X", unpack(rgb)))
    assert(palette.seek_handle_color == palette.seekbarfg_color)
    assert(palette.seekbarbg_color ~= palette.seekbarfg_color)
end
''')

    def test_letterboxing_does_not_outweigh_video_color(self):
        self.run_lua('''
local image = frame(0, 0, 0)
local blue_row = string.rep(string.char(220, 70, 40, 0), 32)
image.data = image.data:sub(1, 8 * image.stride) .. blue_row .. image.data:sub(9 * image.stride + 1)
assert(extract(image).seekbarfg_color == "#2846DC")
''')

    def test_dark_colors_are_brightened_and_monochrome_stays_neutral(self):
        self.run_lua('''
assert(extract(frame(80, 0, 0)).seekbarfg_color == "#AA0000")
assert(extract(frame(80, 80, 80)).seekbarfg_color == "#AAAAAA")
assert(extract(frame(0, 0, 0)) == nil)
assert(extract(frame(255, 255, 255)) == nil)
''')

    def test_invalid_or_truncated_frames_are_ignored(self):
        self.run_lua('''
assert(extract(nil) == nil)
assert(extract({}) == nil)
local image = frame(220, 60, 40)
image.data = image.data:sub(1, -2)
assert(extract(image) == nil)
image = frame(220, 60, 40)
image.format = "rgba"
assert(extract(image) == nil)
image = frame(220, 60, 40)
image.stride = -image.stride
assert(extract(image) == nil)
''')
