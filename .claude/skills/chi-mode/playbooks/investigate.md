# Investigate playbook

For a question whose answer is a cited explanation, not code: "how does X work", "why is X like this", "what could this break", "is this safe".
Do not edit code. If the answer needs an experiment, run it on a scratch branch or in `/tmp` and delete it after.

1. **Name the question** in one sentence. If it is vague, state your reading and continue. The user can redirect.
2. **Pick the skill.**

   | Question | Skill |
   |---|---|
   | How does it work, where should this live | `how` |
   | Why is it shaped this way, what was decided | `why` |
   | What could this change break | `blast-radius` |
   | What is this PR, should it ship | `understanding-prs` |
   | Production data, logs, or traces | `querying-grafana`, `pulse-traces` |

   Run two in parallel when the question spans them, for example `how` plus `why` before a redesign.
3. **Prove the load-bearing fact.** Find the one fact the answer depends on. Get it to a `file:line`, a query result, or a script that runs the real code (`principle-prove-it-works`).
4. **Answer.** Lead with the answer. Mark each claim as measured, cited, or inferred. Say what you could not check.

**Reply:** the answer first, the evidence, the open questions, and the next skill to run if the user wants to go deeper.
