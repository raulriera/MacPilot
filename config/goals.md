# MacPilot Improvement Goals

Write your improvement requests here. The meta-agent reads this file on every run
and treats each bullet or section as an independent goal.

<!-- Example goals (uncomment and edit to use):

## Prompts
- Agent X should include more context in its report
- All agents should mention the git commit SHA they ran against

## Schedules
- Run agent Y twice a day instead of once

## General
- Add a new agent that does Z
- Reduce max-turns on a specific agent

-->

## Standing goals (always apply)
- If any agent hit error_max_turns recently, increase its --max-turns by 5
- If any agent shows repeated failures in logs, add a pre-flight guard to fail fast before calling run_agent
- If any agent prompt is vague or missing explicit steps, rewrite it with numbered steps and exact commands
- If an agent's --timeout is too tight for its task (killed before finishing), increase it
- Do not make changes if all agents are running cleanly — write the report noting everything is healthy and stop
