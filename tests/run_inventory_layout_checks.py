"""Run the real DST inventorybar layout/navigation with lightweight UI stubs."""
from pathlib import Path
import os
import sys

SOURCE = Path(__file__).resolve().parents[1]
ROOT = SOURCE.parent
sys.path.insert(0, str(ROOT / ".tools/lua_test_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
vanilla = Path(os.environ.get("DST_SCRIPTS_PATH", ROOT / "game_scripts_reference/scripts"))
lua.globals().package.path = ";".join(str(path).replace("\\", "/") for path in (
    SOURCE / "scripts/?.lua", vanilla / "?.lua")) + ";" + lua.globals().package.path
lua.execute((SOURCE / "tests/test_inventory_layout.lua").read_text(encoding="utf-8"))
