---
name: sleep
description: Put the Mac to sleep at a time (/sleep 11pm, /sleep 3 for hours) or once every Claude session is done (/sleep), with away rules for every live session; /sleep off cancels. Lashaw runs it; never invoke it yourself.
disable-model-invocation: true
argument-hint: "[hours | 11pm | 23:40 | off]"
---

# Sleep

!`~/.claude/bin/sleep-mode set ${ARGUMENTS} --session ${CLAUDE_SESSION_ID}`

The output above is the result of scheduling. If it says the schedule was cancelled or could not be
read, say so in one line and stop. Otherwise reply with one line saying when the Mac sleeps, then follow
the away rules it printed and keep working on the session's goal. Do not ask questions.
