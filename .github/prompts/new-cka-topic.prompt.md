---
name: new-cka-topic
description: "Scaffolds a complete CKA/CKAD/CKS topic folder following the established structure: main README.md, sub-topic subfolders with READMEs, article files, and organised YAML placeholders."
---

# New CKA Topic

Scaffold a new certification domain topic following the established pattern.

## Input

```
Certification: CKA
Topic number:  [NN]
Topic name:    [TOPIC NAME]
Exam weight:   [NN]%
Sub-topics:    [comma-separated list of sub-topic names]
```

Example:
```
Certification: CKA
Topic number:  03
Topic name:    Services and Networking
Exam weight:   20%
Sub-topics:    Services, NetworkPolicy, Ingress, DNS, CoreDNS
```

---

## Steps

### 1. Load the cka-topic-documentation skill

Read `.github/skills/cka-topic-documentation/SKILL.md` first. All structural decisions follow that skill.

### 2. Create the topic root folder

Path: `[CERTIFICATION]/[NN]-<slug>-[WEIGHT]pct/`  
Slug: lowercase words joined with hyphens from the topic name.

### 3. Create the main README.md

Use this template:

```markdown
# [TOPIC NAME] — [NN]% do Exame CKA

Breve descrição do tópico e por que é importante para o CKA.

## Sub-tópicos

| # | Sub-tópico | Pasta |
|---|-----------|-------|
| 1 | [Sub-topic 1] | [./01-<slug>/](./01-<slug>/) |
| 2 | [Sub-topic 2] | [./02-<slug>/](./02-<slug>/) |

## Comandos Essenciais

<!-- Populate after creating sub-topic READMEs -->

## Armadilhas Comuns

| Erro | Causa | Correção |
|------|-------|----------|
| <!-- fill in → |

## Checklist

<!-- One checkbox per curriculum item — fill in after reviewing the official CKA curriculum PDF -->
```

### 4. Create sub-topic folders

For each sub-topic, create `[NN]-<slug>/README.md` using this template:

```markdown
# [Sub-topic Name]

## Conceito

<!-- Explain the K8s object model and exam relevance -->

## Manifests

<!-- Will be added as YAMLs are created -->

## Comandos úteis

```bash
# Key kubectl commands for this sub-topic
```

## Exercícios

1. <!-- Exercise 1 -->
   ```bash
   # Verificação:
   kubectl get ...
   ```
```

### 5. Create article stubs

Create `article-01-<first-sub-topic-slug>.md` and `article-02-<second-sub-topic-slug>.md` with:

```markdown
# [Article Title]

## TL;DR

- [ coming soon ]

## Conceito e hierarquia

## Configuração passo a passo

## Armadilhas do exame

## Referências
- https://kubernetes.io/docs/...
```

### 6. Update the CKA main README.md

Add the new topic to the **Domínios do Exame** table in `CKA/README.md` if it's not already listed.

### 7. Verify

Run `Get-ChildItem -Recurse` (PowerShell) or `find . -type f` (bash) on the new folder and confirm:
- All folders and README.md files are present
- No stray files at the topic root
- The new folder appears in `CKA/README.md`
