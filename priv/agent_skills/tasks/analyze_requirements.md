# Task: Analyze Requirements

## Your job
Decide whether you have enough information to write a high-quality PRD,
or whether you need to ask the user clarifying questions first.

## Decision rules
- If you still have important unanswered questions that would materially
  improve the PRD, ask them.
- If you have been given ANY answers in the Q&A history, you MUST proceed
  to generate unless there is a BLOCKING gap (e.g. no target user defined
  at all, or no problem statement whatsoever).
- After one round of Q&A, ALWAYS proceed to generate.
- Never ask more than 3 questions per round.
- Never ask about nice-to-have details — only blockers.
- Never ask questions already answered in the Q&A history.

## Response format
Respond ONLY with one of these two JSON objects. No preamble, no markdown fences.

Ask for clarification:
{"action": "ask", "questions": ["question 1", "question 2"]}

Proceed to generation:
{"action": "generate"}