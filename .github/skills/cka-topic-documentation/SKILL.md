---
name: cka-topic-documentation
description: "Use this skill when creating, updating, or restructuring CKA/CKAD/CKS topic documentation — README files, article files, sub-topic folder structure. Covers the established folder pattern, content conventions, YAML organisation, and exercise format."
---

# Skill: cka-topic-documentation

## When this skill applies

Trigger phrases: **topic documentation**, **sub-topic folder**, **article**, **README**, **CKA topic**, **CKAD topic**, **checklist**, **exercício**, **subtopic**, any mention of adding a new certification domain section.

---

## Canonical Folder Structure

```
CKA/<NN>-<slug>-<weight>pct/                   ← topic root
├── README.md                                   ← navigation index (see §README below)
├── article-01-<sub-slug>.md                    ← in-depth article
├── article-02-<sub-slug>.md
├── article-NN-<sub-slug>.md
├── 01-<sub-topic-slug>/
│   ├── README.md                               ← sub-topic content (see §Sub-topic README)
│   └── *.yaml                                  ← practice manifests
├── 02-<sub-topic-slug>/
│   ├── README.md
│   └── *.yaml
└── ...
```

**Rule:** YAML files live inside the sub-topic folder they belong to — never at the topic root.

---

## Topic Root README.md

Required sections in order:

1. `# <Topic Name>` with exam weight badge
2. Short paragraph: what the topic covers and why it matters for the CKA
3. **Sub-topics table** — links to `./NN-<slug>/` (folder paths, not `#anchors`)
4. **Key commands cheatsheet** — grouped by sub-topic
5. **Armadilhas (Common Pitfalls)** — table with `Erro`, `Causa`, `Correção` columns
6. **Checklist** — one checkbox per concrete skill from the official curriculum

### Sub-topics table format

```markdown
| # | Sub-tópico | Pasta |
|---|-----------|-------|
| 1 | Deployments e Rolling Updates | [01-deployments-rolling-updates/](./01-deployments-rolling-updates/) |
| 2 | ConfigMaps e Secrets | [02-configmaps-secrets/](./02-configmaps-secrets/) |
```

---

## Sub-topic README.md

Required sections in order:

1. `# <Sub-topic Name>`
2. **Conceito** — 1–3 paragraphs with K8s object hierarchy and exam relevance
3. **Manifests** — fenced `yaml` blocks for every YAML file in the folder (full content, not excerpts)
4. **Comandos úteis** — kubectl commands relevant to this sub-topic
5. **Exercícios** — numbered list, 4–6 exercises with:
   - Task description
   - Expected outcome or verification command (`kubectl get`, `kubectl describe`, etc.)
6. **Refs** — links to official Kubernetes docs and CKA curriculum section

---

## Article Files

Articles are deep-dives with production context. Required sections:

1. `# <Title>` (more descriptive than the sub-topic name)
2. **TL;DR** — 3–5 bullet summary
3. **Conceito e hierarquia** — object model explained with diagram (ASCII or Mermaid)
4. **Configuração passo a passo** — manifests with inline explanation comments
5. **Armadilhas do exame** — table of real errors seen + corrections
6. **Referências** — Kubernetes docs links

---

## Naming Conventions

| Item | Pattern | Example |
|------|---------|---------|
| Topic folder | `NN-<slug>-<weight>pct` | `02-workloads-scheduling-15pct` |
| Sub-topic folder | `NN-<slug>` | `02-configmaps-secrets` |
| Article file | `article-NN-<slug>.md` | `article-02-configmaps-secrets.md` |
| YAML manifest | `<resource-type>.yaml` or `<descriptor>.yaml` | `deploy.yaml`, `configMap.yaml` |

---

## YAML Organisation Rules

- One conceptual resource per YAML file (don't mix Deployment + Service in same file unless tightly coupled)
- File names use camelCase for multi-word K8s objects (`configMap.yaml`, `replicaSet.yaml`)
- Every YAML file in a sub-topic folder is referenced in that sub-topic's README.md under **Manifests**
- Backup/scratch files: prefix with `bkp-` — they are informational only and should have a comment at top explaining purpose

---

## Checklist Before Marking a Topic Complete

- [ ] Main README.md has all 6 sections
- [ ] Sub-topics table uses folder links (`./NN-slug/`), not `#anchor` links
- [ ] Every sub-topic has a folder with README.md
- [ ] Every YAML is referenced in its sub-topic README.md
- [ ] At least one article file exists per topic
- [ ] Checklist in main README.md covers all CKA curriculum items for the domain
- [ ] No YAML files at topic root (all moved into sub-topic folders)
