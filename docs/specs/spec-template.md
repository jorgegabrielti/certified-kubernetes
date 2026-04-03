# Spec Template — CKA/CKAD/CKS Study Content

> Copy this file to `docs/specs/feature-<name>.md` and fill in every section.
> Implementation begins **only after** numbered acceptance criteria are defined.

---

## Metadata

| Field | Value |
|-------|-------|
| Spec ID | `feature-<name>` |
| Certification | CKA / CKAD / CKS |
| Topic | e.g. "Services and Networking" |
| Domain weight | e.g. 20% |
| Status | Draft / Review / Approved / Implemented |
| Author | <!-- GitHub handle --> |
| Created | <!-- YYYY-MM-DD --> |
| Last updated | <!-- YYYY-MM-DD --> |

---

## 1. Overview

One paragraph: what is being added, why it is needed, and which CKA curriculum section it maps to.

> Example: "Add complete study documentation for the Storage domain (10% of CKA). Covers PersistentVolumes, PersistentVolumeClaims, StorageClasses, and volume mounting patterns as defined in CKA_Curriculum_v1.35.pdf section 4."

---

## 2. Motivation

- What gap does this fill?
- Is there an existing exam objective not yet covered?
- Reference the curriculum section: `CKA_Curriculum_v1.35.pdf → Section N`

---

## 3. Scope

### In scope
- [ ] Sub-topic 1 — short description
- [ ] Sub-topic 2 — short description
- [ ] YAML exercises for each sub-topic
- [ ] Article files for major concepts

### Out of scope
- List anything explicitly NOT included (e.g., "StorageClass dynamic provisioning on cloud — only hostPath for kind")

---

## 4. Folder Structure

```
CKA/<NN>-<slug>-<weight>pct/           ← NEW
├── README.md
├── article-01-<slug>.md
├── 01-<sub-topic>/
│   ├── README.md
│   └── *.yaml
└── ...
```

---

## 5. Acceptance Criteria

> Each criterion maps to at least one test/exercise. Number them — they will be referenced in commit messages.

**AC-01:** Topic root folder exists with all required files (README.md, at least one article, sub-topic folders).

**AC-02:** Main README.md sub-topics table uses folder links (`./NN-slug/`), not anchor links.

**AC-03:** Each sub-topic folder has a README.md with Conceito, Manifests, Comandos úteis, and Exercícios sections.

**AC-04:** Every YAML file passes `kubectl apply --dry-run=server` without errors.

**AC-05:** Every sub-topic has a minimum of 4 exercises with verification commands.

**AC-06:** Main README.md checklist covers all CKA curriculum items for the domain.

**AC-07:** [Add domain-specific criteria here]

---

## 6. Sub-topic Breakdown

| # | Sub-topic | Key K8s objects | Article needed? |
|---|-----------|----------------|----------------|
| 1 | <!-- name --> | <!-- e.g. PV, PVC --> | Yes / No |
| 2 | | | |

---

## 7. Dependencies

- [ ] kind cluster running (for YAML dry-run validation)
- [ ] Prerequisite topics documented (links)
- [ ] Any special cluster setup needed (metrics-server, Ingress controller, etc.)

---

## 8. Definition of Done

- [ ] All acceptance criteria (AC-01 through AC-NN) met
- [ ] `cka-content-review` agent run with zero blocking issues
- [ ] All YAML files dry-run validated
- [ ] Checklist in main README.md updated
- [ ] `docs/architecture.md` updated if new study pattern introduced
- [ ] ADR created if this introduces a structural breaking change
