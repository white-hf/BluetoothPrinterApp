import sys
import os
import re

file_path = "/Users/whitetang/Desktop/work/print_svr/labelprint/print_svr.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add missing import if it's not there
if "import subprocess" not in content:
    content = "import subprocess
" + content

# This regex finds the main execution block and replaces it with a correctly indented version
# It assumes the block starts with 'if __name__ == "__main__":' and ends after the 'finally' clause.
# This is much safer than line-by-line manipulation.
correct_main_block = """if __name__ == "__main__":
    if _run_cli(sys.argv[1:]):
        sys.exit(0)
    log_runtime_config(prefix="startup-config-main")
    logger.info("[startup] Flask 服务启动于 http://%s:%s (reload=%s)", BIND_HOST, BIND_PORT, APP_RELOAD)
    
    discovery_instance = None
    if not APP_RELOAD:
        discovery_instance = register_service(BIND_PORT)

    try:
        app.run(host=BIND_HOST, port=BIND_PORT, debug=APP_RELOAD)
    finally:
        if discovery_instance:
            logger.info("[mDNS] Stopping discovery...")
            if isinstance(discovery_instance, subprocess.Popen):
                discovery_instance.terminate()
            else:
                discovery_instance.close()"""

# A more robust regex to find the start and replace the whole block to the end of the file.
# This avoids issues with what comes after the finally block.
content = re.sub(r'if __name__ == "__main__":.*', correct_main_block, content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Server script fixed (import and indentation).")
