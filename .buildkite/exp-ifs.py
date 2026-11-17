"""Throwaway experiment (do not merge), round 7: which `if:` expressions does the server accept on a notify entry, and when do they fire?

Phase 1: one tiny upload per syntax (a rejected upload fails the whole upload, so they can't share one). The probe steps are skipped, so they never run.
Phase 2: upload steps (ok / fail / parallel with one failing job / skipped) carrying one github_commit_status per accepted expression, then read the statuses from GitHub.
"""
import json
import subprocess

# (id, expression): syntaxes to probe
SYNTAX = [
    ('q', 'step.state == "ignored"'),
    ('unq', 'step.state == ignored'),
    ('sq', "step.state == 'ignored'"),
    ('or', 'step.state == "ignored" || step.state == "finished"'),
    ('inc', '["ignored", "finished"] includes step.state'),
    ('re', 'step.state =~ /ignored|finished/'),
    ('in', 'step.state in ["ignored", "finished"]'),
    ('rev', '"ignored" == step.state'),
    ('par', '(step.state == "ignored") || (step.state == "finished")'),
    ('ne', 'step.state != "running"'),
]
# (id, expression): evaluated for real; the variants below are only added when the probe accepted them
SEMANTIC = [
    ('fin', 'step.state == "finished"'),
    ('fail', 'step.state == "failing"'),
    ('ign', 'step.state == "ignored"'),
    ('ignfin', 'step.state == "ignored" || step.state == "finished"'),
    ('all3', 'step.state == "ignored" || step.state == "finished" || step.state == "failing"'),
]
VARIANTS = ['unq', 'sq', 'inc', 're', 'in', 'rev', 'par', 'ne']
# Round 8: probe only, with the full error text (the regex and `includes` forms were rejected in round 7 and the message was cut)
SYNTAX = [
    ('re1', 'step.state =~ /ignored|finished/'),
    ('re2', 'step.state =~ /^(ignored|finished)$/'),
    ('re3', 'step.state =~ /ignored/'),
    ('nre', 'step.state !~ /running/'),
    ('bre', 'build.branch =~ /^olivier\\//'),
    ('inc2', 'build.pull_request.labels includes "x"'),
    ('str', 'step.state =~ "ignored"'),
    ('not', '!(step.state == "running")'),
    ('and', 'step.state == "finished" && build.branch != "x"'),
    ('arr', 'step.state == ["ignored"]'),
    ('unq2', 'step.state == ignored'),
]
PROBE_ONLY = True
EXPR = dict(SYNTAX + SEMANTIC)


def upload(pipeline):
    p = subprocess.run(['buildkite-agent', 'pipeline', 'upload'], input=json.dumps(pipeline), capture_output=True, encoding='utf-8')
    return p.returncode == 0, ((p.stderr or p.stdout).strip().splitlines() or ['?'])[-1][-500:]


def notify(context, expr=None):
    entry = {'github_commit_status': {'context': context}}
    if expr:
        entry['if'] = expr
    return entry


accepted = []
for pid, expr in SYNTAX:
    ok, why = upload({'steps': [{'label': 'probe %s' % pid, 'command': 'true', 'skip': 'probe only', 'notify': [notify('EXP probe %s' % pid, expr)]}]})
    print('EXP PROBE %-4s %-9s %s %s' % (pid, 'ACCEPTED' if ok else 'REJECTED', expr, '' if ok else '-> ' + why))
    if ok:
        accepted.append(pid)

if PROBE_ONLY:
    raise SystemExit(0)

ids = [i for i, _ in SEMANTIC] + [v for v in VARIANTS if v in accepted]
entries = lambda step: [notify('EXP %s none' % step)] + [notify('EXP %s %s' % (step, i), EXPR[i]) for i in ids]
steps = [
    {'label': 'S-ok: passes', 'command': 'sleep 5', 'notify': entries('ok')},
    {'label': 'S-fail: fails', 'command': 'sleep 5; exit 1', 'notify': entries('fail')},
    # job 0 fails at once while job 1 keeps running: the step is "failing" until job 1 ends
    {'label': 'S-par: one job fails early, the other runs on', 'parallelism': 2,
     'command': 'if [ "$$BUILDKITE_PARALLEL_JOB" = 0 ]; then exit 1; else sleep 45; fi', 'notify': entries('par')},
    {'label': 'S-skip: skipped', 'command': 'true', 'skip': 'experiment', 'notify': entries('skip')},
]
ok, why = upload({'steps': steps})
print('EXP SEMANTIC upload: %s %s' % ('ACCEPTED' if ok else 'REJECTED', '' if ok else why))
print('EXP evaluated ids: ' + ' '.join(ids))
