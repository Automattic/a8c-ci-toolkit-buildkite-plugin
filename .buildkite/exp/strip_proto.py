"""Three ways to remove the `even-if-skipped` marker from a pipeline, for comparison. Each takes the pipeline text and returns the text to pipe to `buildkite-agent pipeline upload`."""
import json
import re
import subprocess

MARKER = 'even-if-skipped'


def strip_markers(node):
    """Removes the marker wherever it appears in a parsed pipeline (dict/list tree)."""
    if isinstance(node, dict):
        return {k: strip_markers(v) for k, v in node.items() if k != MARKER}
    if isinstance(node, list):
        return [strip_markers(v) for v in node]
    return node


# ---- 1. text only ---------------------------------------------------------------------------------------------------
BLOCK_KEY = re.compile(r'^(\s*)even-if-skipped:\s*true\s*(#.*)?$')
DASH_KEY = re.compile(r'^(\s*)-\s+even-if-skipped:\s*true\s*(#.*)?$')
SCALAR_START = re.compile(r':\s*[|>][+-]?\d*\s*(#.*)?$')
FLOW_AFTER = re.compile(r',\s*even-if-skipped:\s*true(?=\s*[,}\]])')
FLOW_BEFORE = re.compile(r'even-if-skipped:\s*true\s*,\s*')


def strip_text(text):
    lines = text.split('\n')
    out, i, scalar_indent = [], 0, None
    while i < len(lines):
        line = lines[i]
        content = line.rstrip('\r')
        indent = len(content) - len(content.lstrip(' '))
        if scalar_indent is not None:  # inside a `|` or `>` block: leave it alone
            if content.strip() == '' or indent > scalar_indent:
                out.append(line); i += 1; continue
            scalar_indent = None
        if SCALAR_START.search(content):
            key_indent = indent + (2 if content.lstrip(' ').startswith('- ') else 0)
            scalar_indent = key_indent
        m = DASH_KEY.match(content)
        if m and i + 1 < len(lines):  # `- even-if-skipped: true` then the entry's real first key: the dash moves to it
            nxt = lines[i + 1]
            out.append(m.group(1) + '- ' + nxt.lstrip(' '))
            i += 2
            continue
        if BLOCK_KEY.match(content):
            i += 1
            continue
        line = FLOW_BEFORE.sub('', FLOW_AFTER.sub('', line))
        out.append(line)
        i += 1
    return '\n'.join(out)


# ---- 2. JSON, via the agent's own parser ------------------------------------------------------------------------------
def strip_json(text, agent):
    """Asks the agent to turn the YAML into JSON without interpolating it (so `$VAR` and `$$` stay for the real upload)."""
    return json.dumps(strip_markers(agent(text, no_interpolation=True)), ensure_ascii=False)  # ASCII escapes would emit surrogate pairs, which YAML rejects


# ---- 3. PyYAML ------------------------------------------------------------------------------------------------------
def strip_yaml(text):
    import yaml
    return yaml.safe_dump(strip_markers(yaml.safe_load(text)), sort_keys=False, allow_unicode=True)
