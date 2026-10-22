"""Check food module behavior against vanilla Perishable, Preserver and Trader."""
from pathlib import Path
import os
import sys

SOURCE = Path(__file__).resolve().parents[1]
ROOT = SOURCE.parent
sys.path.insert(0, str(ROOT / ".tools/lua_test_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
vanilla = Path(os.environ.get("DST_SCRIPTS_PATH", ROOT / "game_scripts_reference/scripts"))
lua.globals().package.path = ";".join(str(p).replace("\\", "/") for p in (
    SOURCE / "scripts/?.lua", vanilla / "?.lua")) + ";" + lua.globals().package.path
lua.execute((SOURCE / "tests/test_foodmodules.lua").read_text(encoding="utf-8"))

# A separate VM exercises real component-action registration and modmain, so
# testing the collector functions in isolation cannot hide overwritten hooks.
registration = LuaRuntime(unpack_returned_tuples=True)
registration.globals().package.path = lua.globals().package.path
registration.globals().MODMAIN_SOURCE = (SOURCE / "modmain.lua").read_text(encoding="utf-8")
registration.execute((SOURCE / "tests/test_action_registration.lua").read_text(encoding="utf-8"))
