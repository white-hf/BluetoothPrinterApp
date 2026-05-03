import sys
import os
import re

file_path = "/Users/whitetang/Desktop/work/print_svr/labelprint/print_svr.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add missing import
if "import subprocess" not in content:
    content = "import subprocess
" + content

# Fix indentation within the main block
main_block_pattern = re.compile(r'if __name__ == "__main__":.*?finally:.*?\)', flags=re.DOTALL)
main_block_match = main_block_pattern.search(content)

if main_block_match:
    main_block_text = main_block_match.group(0)
    # Remove leading spaces from each line and then add 4 spaces back
    lines = main_block_text.split('
')
    
    reindented_block = ""
    # The first line "if __name__..." has no indent
    reindented_block += lines[0].strip() + "
"
    
    base_indent = "    "
    for line in lines[1:]:
        stripped_line = line.strip()
        if not stripped_line:
            continue
        
        indent_level = 1
        if "try:" in stripped_line or "finally:" in stripped_line:
            indent_level = 1
        elif "if discovery_instance:" in stripped_line:
            indent_level = 2
        elif "discovery_instance.terminate()" in stripped_line or "discovery_instance.close()" in stripped_line:
            indent_level = 3
        
        # Default to one level of indent inside main
        final_indent = base_indent * indent_level
        reindented_block += final_indent + stripped_line + "
"
        
    # This is too complex and risky. Let's do a full replacement with a known good block.

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

    # This regex is more specific and safer
    content = re.sub(r'if __name__ == "__main__":\s+if _run_cli.*', correct_main_block, content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Server script fixed (import and indentation).")
