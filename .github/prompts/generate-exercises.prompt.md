---
name: generate-exercises
description: "Generate CKA/CKAD/CKS practice exercises for a specific sub-topic. Produces exam-style tasks with manifests, solutions, and kubectl verification commands."
---

# Generate Practice Exercises

Generate realistic CKA exam-style exercises for a sub-topic.

## Input

```
Sub-topic folder: [PATH]
Topic:            [HUMAN-READABLE TOPIC NAME]
Difficulty:       [easy | intermediate | hard | mixed]
Count:            [NUMBER — default 5]
```

Example:
```
Sub-topic folder: CKA/03-services-networking-20pct/01-services/
Topic:            Kubernetes Services (ClusterIP, NodePort, LoadBalancer)
Difficulty:       mixed
Count:            5
```

---

## Steps

### 1. Load required skills

Read these files first:
- `.github/skills/k8s-yaml-exercises/SKILL.md` — for valid YAML patterns
- `.github/skills/cka-topic-documentation/SKILL.md` — for exercise format

### 2. Read existing content

Read `[PATH]/README.md` to understand what is already documented and avoid duplicating existing exercises.

### 3. Generate exercises

Use the **exercise-generator agent** format (see `.github/agents/exercise-generator.agent.md`). Each exercise must have:

- `### Exercício N — <Short Title>`
- **Cenário** — cluster starting state
- **Tarefa** — what to do (imperative, CKA-exam wording)
- **Verificação** — kubectl command + expected output
- **Solução** — complete YAML + apply commands

For `mixed` difficulty: 2 easy, 2 intermediate, 1 hard.

### 4. Dry-run validate every YAML

For each generated YAML, run:
```bash
kubectl apply --dry-run=server -f -
```
Fix any validation errors before including the exercise.

### 5. Append to README.md

Add the exercises to the **Exercícios** section of `[PATH]/README.md`.  
If the section already has exercises, append after the last one (renumber if needed).

### 6. Confirm

Report:
- N exercises added
- YAML validation results
- Any exercises that need cluster-specific resources (e.g., metrics-server for HPA) — call these out as prerequisites
