"""Oracle for the three strippers: the agent's processed result of the stripped output must equal the agent's processed result of the original minus markers."""
import json
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import strip_proto as sp  # noqa: E402

# A throwaway git repo so that `if_changed` has something to diff
REPO = tempfile.mkdtemp()
run = lambda *a: subprocess.run(a, cwd=REPO, check=True, capture_output=True, text=True).stdout.strip()
run('git', 'init', '-q', '.'); run('git', 'config', 'user.email', 't@t'); run('git', 'config', 'user.name', 't')
open(os.path.join(REPO, 'f'), 'w').write('a'); run('git', 'add', '-A'); run('git', 'commit', '-qm', 'base')
BASE = run('git', 'rev-parse', 'HEAD')
open(os.path.join(REPO, 'src.txt'), 'w').write('b'); run('git', 'add', '-A'); run('git', 'commit', '-qm', 'change')
ENV = dict(os.environ, VAR='hello', SKIPVAR='docs only')
AGENT = ['buildkite-agent', 'pipeline', 'upload', '--dry-run', '--agent-access-token', 'dummy', '--git-diff-base', BASE, '--format', 'json']


def agent(text, no_interpolation=False):
    p = subprocess.run(AGENT + (['--no-interpolation'] if no_interpolation else []), cwd=REPO, env=ENV, input=text, capture_output=True, encoding='utf-8')
    if p.returncode != 0:
        raise RuntimeError('agent: ' + (p.stderr.strip().splitlines() or ['?'])[-1][:120])
    return json.loads(p.stdout)


M = 'even-if-skipped: true'
def step(notify, extra=''):
    return 'steps:\n  - label: a\n    command: x\n' + extra + '    notify:\n' + notify

CASES = {
    'block marker after github_commit_status': step(f'      - github_commit_status: {{ context: "A" }}\n        {M}\n'),
    'block marker after slack (multi-line map)': step(f'      - slack:\n          channels: ["#c"]\n          message: "m"\n        {M}\n'),
    'marker is the first key (dash line)': step(f'      - {M}\n        slack: "#c"\n'),
    'flow style, marker last': step(f'      - {{ github_commit_status: {{ context: "A" }}, {M} }}\n'),
    'flow style, marker first': step(f'      - {{ {M}, slack: "#c" }}\n'),
    'marker between other keys': step(f'      - slack: "#c"\n        {M}\n        if: step.outcome == "passed"\n'),
    'trailing comment on the marker': step(f'      - github_commit_status: {{ context: "A" }}\n        {M} # keep the status\n'),
    'YAML anchor and alias': 'x-notify: &n\n  - github_commit_status: { context: "A" }\n    ' + M + '\nsteps:\n  - label: a\n    command: x\n    notify: *n\n  - label: b\n    command: y\n    notify: *n\n',
    'interpolation, $$ escape, skip from env': 'steps:\n  - label: "build $VAR"\n    command: echo $$KEEP $VAR\n    skip: "$SKIPVAR"\n    notify:\n      - github_commit_status: { context: "A" }\n        ' + M + '\n',
    'if_changed, group, group-level notify': 'steps:\n  - group: G\n    if_changed: ["nomatch/**"]\n    notify:\n      - github_commit_status: { context: "G" }\n        ' + M + '\n    steps:\n      - label: child\n        command: x\n        notify:\n          - github_commit_status: { context: "C" }\n            ' + M + '\n',
    'block scalar that contains the marker text': 'steps:\n  - label: a\n    command: |\n      echo "' + M + '"\n      echo done\n    notify:\n      - github_commit_status: { context: "A" }\n        ' + M + '\n',
    'wait, block, nested wait': 'steps:\n  - wait\n  - wait: ~\n  - block: "ok?"\n  - label: a\n    command: x\n    notify:\n      - github_commit_status: { context: "A" }\n        ' + M + '\n',
    'YAML 1.1 values (on/no/010/date)': 'steps:\n  - label: a\n    command: x\n    env: { ENABLED: on, DEBUG: no, OCTAL: 010, DATE: 2026-11-17 }\n    notify:\n      - github_commit_status: { context: "A" }\n        ' + M + '\n',
    'unicode and emoji': 'steps:\n  - label: "🚀 Café"\n    command: "echo ü"\n    notify:\n      - github_commit_status: { context: "Ç" }\n        ' + M + '\n',
    'CRLF line endings': step('      - github_commit_status: { context: "A" }\n        ' + M + '\n').replace('\n', '\r\n'),
    'long command and numbers': 'steps:\n  - label: a\n    command: "make a && make b"\n    timeout_in_minutes: 10\n    parallelism: 3\n    retry: { automatic: [ { exit_status: -1, limit: 2 } ] }\n    notify:\n      - github_commit_status: { context: "A" }\n        ' + M + '\n',
}


def norm(j):
    return json.dumps(j, sort_keys=True)


def check(name, text, strip):
    try:
        expected = sp.strip_markers(agent(text))
        out = strip(text)
        actual = agent(out)
        if norm(expected) == norm(actual):
            return 'PASS', ''
        e, a = json.loads(norm(expected)), json.loads(norm(actual))
        for i, (se, sa) in enumerate(zip(e['steps'], a['steps'])):
            if se != sa:
                diff = {k: (se.get(k), sa.get(k)) for k in set(se) | set(sa) if se.get(k) != sa.get(k)}
                return 'FAIL', 'step %d differs: %s' % (i, str(diff)[:400])
        return 'FAIL', 'differs (top level)'
    except Exception as exc:
        return 'ERROR', str(exc)[:150]


APPROACHES = [('text', sp.strip_text), ('json', lambda t: sp.strip_json(t, agent)), ('yaml', sp.strip_yaml)]
if __name__ == '__main__':
    verbose = '-v' in sys.argv
    import platform
    print('EXPR python %s, buildkite-agent %s' % (platform.python_version(), subprocess.run(['buildkite-agent', '--version'], capture_output=True, encoding='utf-8').stdout.strip().split('+')[0]))
    print('%-46s %-6s %-6s %-6s' % ('case', 'text', 'json', 'yaml'))
    tally = {n: 0 for n, _ in APPROACHES}
    details = []
    for name, text in CASES.items():
        row = []
        for an, fn in APPROACHES:
            verdict, why = check(name, text, fn)
            tally[an] += verdict == 'PASS'
            row.append(verdict)
            if verdict != 'PASS':
                details.append('  [%s] %s: %s %s' % (an, name, verdict, why))
        print('%-46s %-6s %-6s %-6s' % (name, *row))
    print('%-46s %-6s %-6s %-6s' % ('PASSED (of %d)' % len(CASES), *[tally[n] for n, _ in APPROACHES]))
    if details:
        print('\nfailures:'); print('\n'.join(details))
