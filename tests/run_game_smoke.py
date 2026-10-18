"""Run the real DST engine against a new isolated offline world."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import socket

SOURCE = Path(__file__).resolve().parents[1]
GAME = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("D:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together")
MOD = (GAME / "mods/growing_backpack_validation").resolve()
assert MOD.parent == (GAME / "mods").resolve()
assert not MOD.exists(), f"Temporary test mod already exists: {MOD}"
STORAGE = Path(tempfile.mkdtemp(prefix="growingpack_", dir=SOURCE.parent))
CLUSTER = STORAGE / "DoNotStarveTogether/GrowingPackTest"
(CLUSTER / "Master").mkdir(parents=True)
(CLUSTER / "cluster.ini").write_text("""[GAMEPLAY]
game_mode = survival
max_players = 1
pvp = false
pause_when_empty = false
[NETWORK]
cluster_name = Growing Backpack Isolated Validation
offline_cluster = true
lan_only_cluster = true
cluster_password = growingpack-test-only
[MISC]
console_enabled = true
[SHARD]
shard_enabled = false
""", encoding="utf-8")
port = None
for candidate in range(11018, 10997, -1):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        try:
            probe.bind(("0.0.0.0", candidate))
            port = candidate
            break
        except OSError:
            pass
assert port is not None, "No free offline DST port; leave existing games untouched"
(CLUSTER / "Master/server.ini").write_text(f"[NETWORK]\nserver_port = {port}\n[SHARD]\nis_master = true\n[ACCOUNT]\nencode_user_path = false\n", encoding="utf-8")
(CLUSTER / "Master/modoverrides.lua").write_text('return { growing_backpack_validation = { enabled = true } }\n', encoding="utf-8")
(CLUSTER / "Master/worldgenoverride.lua").write_text('return { override_enabled = true, preset = "SURVIVAL_TOGETHER", overrides = { world_size = "small" } }\n', encoding="utf-8")
try:
    MOD.mkdir()
    shutil.copy2(SOURCE / "modinfo.lua", MOD)
    shutil.copytree(SOURCE / "scripts", MOD / "scripts")
    shutil.copy2(SOURCE / "tests/game_smoke.lua", MOD / "scripts/gb_game_smoke.lua")
    main = (SOURCE / "modmain.lua").read_text(encoding="utf-8")
    main += '''
AddSimPostInit(function()
    GLOBAL.TheWorld:DoTaskInTime(1, function()
        local ok, err = GLOBAL.pcall(GLOBAL.require, "gb_game_smoke")
        if not ok then
            print("GROWINGPACK_GAME_FAILURE "..GLOBAL.tostring(err))
            GLOBAL.c_shutdown(false)
        end
    end)
end)
'''
    (MOD / "modmain.lua").write_text(main, encoding="utf-8")
    exe = GAME / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"
    log = STORAGE / "engine_console.log"
    with log.open("wb") as out:
        process = subprocess.Popen([str(exe), "-console", "-offline", "-skip_update_server_mods",
            "-persistent_storage_root", str(STORAGE), "-conf_dir", "DoNotStarveTogether",
            "-cluster", "GrowingPackTest", "-shard", "Master"],
            cwd=exe.parent, stdout=out, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW)
        print(f"Isolated DST test PID {process.pid}; log: {log}", flush=True)
        try:
            process.wait(timeout=240)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=15)
            raise RuntimeError(f"Engine test timeout; see {log}")
    output = log.read_text(encoding="utf-8", errors="replace")
    for line in output.splitlines():
        if "GROWINGPACK_GAME_" in line or "LUA ERROR" in line or "Error" in line:
            print(line)
    assert "GROWINGPACK_GAME_SUCCESS" in output, f"Engine validation failed; see {log}"
finally:
    # Delete only the exact, newly created temporary mod under this game's mods folder.
    if MOD.exists() and MOD.resolve().parent == (GAME / "mods").resolve() and MOD.name == "growing_backpack_validation":
        shutil.rmtree(MOD)
