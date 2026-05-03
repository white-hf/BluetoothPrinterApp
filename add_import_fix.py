import sys
import os
import re

file_path = "/Users/whitetang/Desktop/work/print_svr/labelprint/print_svr.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Ensure subprocess is imported
if "import subprocess" not in content:
    # Find the line with 'import sys' and add it after
    content = content.replace("import sys", "import sys
import subprocess")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Server script updated with missing 'import subprocess'.")
