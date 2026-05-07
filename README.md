# JidoPhx

A Phoenix LiveView application demonstrating the [Jido](https://hexdocs.pm/jido) agent framework — signal-based agents integrated with real-time LiveView UI and LLM-powered workflows.

## Features

### Counter (`/counter/:id`)

A real-time counter backed by a `Jido.Agent`. Demonstrates:

- Signal routing (`counter.increment`, `counter.decrement`, `counter.reset`)
- State managed inside the agent, not the LiveView
- Multi-tab sync via Phoenix PubSub

### AI Product Pipeline (`/pipeline`)

A **human-in-the-loop** pipeline that generates a Product Requirements Document (PRD), a Technical Spec, and a cost/effort Estimate from a plain-text requirements description. Uses a three-agent architecture:

```
CoordinatorAgent
  ├── ProductManagerAgent  →  clarifies requirements, generates PRD via LLM
  ├── TechnicalLeadAgent   →  generates Tech Spec via LLM
  └── EstimatorAgent       →  generates cost/effort estimate via LLM
```

**Pipeline state machine:**

```
idle
 └─ pipeline.start ──→ awaiting_clarification
                          └─ clarifications_provided ──→ awaiting_prd
                               └─ prd.review_requested ──→ awaiting_prd_review
                                    ├─ prd.approved ──→ awaiting_spec
                                    │                     └─ spec.review_requested ──→ awaiting_spec_review
                                    │                          ├─ spec.approved ──→ complete
                                    │                          └─ spec.rejected ──→ awaiting_spec (TL revises)
                                    └─ prd.rejected ──→ awaiting_prd (PM revises)
```

Each review step requires explicit user approval or rejection (with feedback). Generated documents are downloadable from the UI.

**Key capabilities:**

- **Clarification flow** — before generating the PRD, the PM agent asks targeted clarifying questions; answers are merged into the requirements context
- **Document / Diff view** — side-by-side tab switcher shows the current document alongside a client-side diff (diff2html + jsdiff) whenever a revision exists
- **Effort estimate** — EstimatorAgent produces a structured cost/effort estimate alongside the spec
- **Run history** — all pipeline runs are persisted to PostgreSQL; a history panel lets you browse past runs and their outputs
- **Semantic memory** — pgvector embeddings (OpenAI `text-embedding-3-small`) index past runs so relevant prior context is surfaced automatically when starting a new pipeline
- **Agent skill prompts** — structured markdown skill files (`priv/agent_skills/`) define role personas and task instructions for the PM, TL, and Estimator agents

## Tech Stack

| Layer | Library |
|---|---|
| Web | Phoenix 1.8, Phoenix LiveView 1.1 |
| Agent framework | Jido 2.0 |
| LLM client | req_llm 1.0 |
| Database | PostgreSQL via Ecto |
| Vector search | pgvector 0.3 |
| Assets | Tailwind CSS, esbuild |
| HTTP server | Bandit |

## Getting Started

```bash
# Install dependencies, create and migrate the database, build assets
mix setup

# Start the server
mix phx.server
# or inside IEx
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

Set `OPENAI_API_KEY` in your environment (required for embeddings and LLM calls).

## Development

```bash
# Run tests
mix test

# Full pre-commit check (compile, unused deps, format, test)
mix precommit
```
