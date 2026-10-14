runbook:
  version: 1
  title: "MCP Gateway Orchestrator — Runbook"
  owner: "Nexus Protocol DAO"
  repository: "fuzzystoddme/Nexus-Protocal-Token"
  file: ".mcp/agents.yaml"
  purpose: >
    Provide human-operable runbook for validating, troubleshooting, and
    remediating the MCP gateway orchestration manifests and related CI artifacts.
    This file is intentionally non-executable: it documents procedures, checks,
    and escalation steps for operators and maintainers.
  scope: >
    Applies to changes under .mcp/, GitHub workflow files that affect agent orchestration,
    and any orchestration artifacts produced by CI or manual runs.

prerequisites:
  - Local tools: git, python 3.11+, yamllint, jq, gh (GitHub CLI)
  - Optional: virtualenv / poetry for reproducible python deps
  - Access: repository read/write (for creating issues or commits), CI artifact access
  - Files of interest: .mcp/agents.yaml, .mcp/test_mcp_gateway_orchestration.py, .github/workflows/

triggers:
  - Manual: operator-initiated validation (recommended after any .mcp changes)
  - On-change: push to branches that modify .mcp/ or .github/workflows/
  - Scheduled: weekly manifest sanity check (recommended)

quick_checks:
  - "Verify file presence: ls -la .mcp/agents.yaml"
  - "YAML syntax: yamllint .mcp/agents.yaml"
  - "Basic schema: python -m .mcp.scripts.validate_agents (see examples below)"
  - "Run unit tests: pytest nexus/test_mcp_gateway_orchestration.py -q"

validation_steps:
  1: name: "Checkout & environment"
     actions: |
       git fetch --prune
       git checkout <branch>
       python -m venv .venv && source .venv/bin/activate
       pip install -r requirements-dev.txt || pip install pyyaml yamllint
  2: name: "YAML syntax & lint"
     commands: |
       yamllint .mcp/agents.yaml || (echo "Fix YAML syntax" && exit 1)
       python -c "import yaml,sys;yaml.safe_load(open('.mcp/agents.yaml')) or sys.exit(0)"
  3: name: "Schema sanity checks"
     description: "Ensure required top-level keys and agent fields exist"
     script: |
       python - <<'PY'
       import sys, yaml
       data = yaml.safe_load(open('.mcp/agents.yaml'))
       if 'agents' not in data or not isinstance(data['agents'], list):
           print('Missing or invalid "agents" array'); sys.exit(2)
       required_agent_keys = {'id','name','responsibilities','permissions','entrypoints'}
       missing = []
       for a in data['agents']:
           if not required_agent_keys.issubset(set(a.keys())):
               missing.append((a.get('id','<no-id>'), list(required_agent_keys - set(a.keys()))))
       if missing:
           print('Agents with missing keys:', missing); sys.exit(3)
       print('Schema sanity checks passed')
       PY
  4: name: "Run tests & linters"
     commands: |
       pytest -q || (echo "Tests failing — inspect and fix"; exit 1)
       flake8 || echo "flake8 warnings (optional)"
  5: name: "Verify CI/workflow compatibility"
     checks: |
       - Confirm .github/workflows only reference allowed entrypoints found in agents.yaml
       - Confirm workflow secrets / permissions align with least privilege
  6: name: "Collect artifacts for triage"
     commands: |
       # If CI produced artifacts, download or reference them from the run
       # Use GitHub UI or gh cli: gh run download <run-id> --dir diagnostics

diagnostics:
  - "Collect YAML lint output and attach to issue/PR"
  - "Collect pytest output + --maxfail=1 for fail-fast"
  - "Collect CI artifact names and upload locations (artifact names often: mcp-gateway-status)"
  - "If solidity changes present, run: slither contracts/ or mythx/third-party scanner"

common_errors_and_fix_guidance:
  yaml_syntax_error:
    detection: "yamllint or yaml.safe_load throws errors"
    fix: "Fix indentation, stray tabs, non-UTF8 characters; re-run yamllint"
  missing_agents_section:
    detection: "Schema check exits with code 2"
    fix: "Restore agents: section or revert to last working commit"
  agent_missing_keys:
    detection: "Schema check lists missing keys"
    fix: "Add required fields (id,name,responsibilities,permissions,entrypoints)"
  tests_failing:
    detection: "pytest returns non-zero"
    fix: "Open failing test logs, run locally, add minimal failing test reproduction"
  permission_mismatch:
    detection: "Workflow or agent requires broader permissions than manifest declares"
    fix: "Reduce permissions in workflow, update manifest only with documented rationale and governance approval"

remediation_playbook:
  - step: "If YAML invalid"
    action: "Revert to previous good commit: git checkout <sha> -- .mcp/agents.yaml"
  - step: "If schema issues in a PR"
    action: "Post a PR review comment with missing fields and set label: mcp-lint"
  - step: "If on-main a scheduled check fails"
    action: "Create issue: label 'mcp-failure' and notify mcp-ops via channel"
  - step: "If critical contract safety issue found"
    action: "Open security issue, notify security-ops, and initiate freeze/rollback plan"

escalation:
  - priority: "P0 - critical"
    contact:
      - name: "Owner (FuzzysTodd)"
        github: "FuzzysTodd"
        notify: "owner@dao.email or Pager (on-call)"
      - name: "security-ops"
        github_team: "security-ops"
  - priority: "P1 - high"
    contact:
      - name: "mcp-ops"
        github_team: "mcp-ops"
      - name: "frontend-ops"
        github_team: "frontend-ops"
  - labels_to_apply:
      - "mcp-failure"
      - "security"
      - "workflow-drift"

artifact_and_logs:
  artifacts:
    - ".mcp/agents.yaml"
    - ".mcp/orchestration-summary.txt"
    - "pytest-logs/*.xml"
    - "ci/artifacts/mcp-gateway-status.zip"
  retention: "Store artifacts in CI for 30 days; critical artifacts archived per DAO policy"

commands_and_snippets:
  validate_yaml: |
    yamllint .mcp/agents.yaml
  quick_python_schema_check: |
    python - <<'PY'
    import yaml,sys
    d = yaml.safe_load(open('.mcp/agents.yaml'))
    print('Agents:', len(d.get('agents') or []))
    PY
  open_issue_with_gh: |
    gh issue create --title "MCP manifest failure: <short>" --body "Failure details: <paste>" --label mcp-failure
  download_ci_artifact: |
    gh run list --workflow=mcp-gateway-orchestrator.yml
    gh run view <run-id> --log
    gh run download <run-id> --name mcp-gateway-status --dir ./diagnostics

security_and_permissions:
  - "Do not store long-lived private keys in .mcp/ files."
  - "Use GitHub Secrets for tokens, and ensure workflows reference secrets with least privilege."
  - "When escalating, redact any private keys or sensitive endpoints in logs before sharing."

postmortem_and_follow_up:
  - "When an incident closes, record: incident id, root cause, timeline, mitigations, action items"
  - "Assign owners and due dates for fixes; track in repository project or issue board"

maintenance:
  - "Weekly: run yamllint and basic schema check (can be scheduled)"
  - "Monthly: review agent permissions and entrypoint lists"
  - "Annually: full security review of agents and orchestration processes"

change_history:
  - "v1: Initial runbook-style document (non-executable)."

notes:
  - "This runbook is intended to be easily consumable by maintainers and used as an operational checklist."
  - "If you later want this converted into a small GitHub Actions 'sanity-check' workflow, copy the quick checks and the python schema script into a workflow job."
