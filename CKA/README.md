# CKA - Trilhas Praticas

Esta pasta concentra o material de estudo pratico para a certificacao CKA, organizado por dominio do exame.

Referencias:
- Curriculo oficial: [CKA_Curriculum_v1.35.pdf](./CKA_Curriculum_v1.35.pdf)
- Dicas oficiais de prova: https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad
- Guia de upgrade: [howto-cluster-upgrade.md](./howto-cluster-upgrade.md)

## Dominios do Exame

| Dominio | Peso | Diretorio |
|---------|------|-----------|
| Cluster Architecture, Installation and Configuration | 25% | [01-cluster-architecture-25pct/](./01-cluster-architecture-25pct/) |
| Workloads and Scheduling | 15% | [02-workloads-scheduling-15pct/](./02-workloads-scheduling-15pct/) |
| Services and Networking | 20% | [03-services-networking-20pct/](./03-services-networking-20pct/) |
| Storage | 10% | [04-storage-10pct/](./04-storage-10pct/) |
| Troubleshooting | 30% | [05-troubleshooting-30pct/](./05-troubleshooting-30pct/) |

## Como usar

- Estude um dominio por vez, comecando pelo de maior peso (Troubleshooting 30%).
- Cada diretorio tem sub-topicos alinhados ao curriculo oficial, exercicios praticos e um checklist.
- Execute os exercicios no lab Vagrant (ver [IAC/Vagrant/](../IAC/Vagrant/)).
- Registre tempo, comandos-chave, erros e correcoes em cada sessao.
- Meta: completar todos os checklists ao menos 2 vezes antes da prova.

## Dicas de prova

- A prova e hands-on e costuma trazer de 15 a 20 tarefas em 2 horas.
- Trabalhe sempre no host indicado na tarefa e volte ao host base ao finalizar cada item.
- Use `sudo -i` cedo quando a tarefa exigir privilegios administrativos.
- Aproveite `kubectl` com alias `k`, autocompletion e `yq` quando disponivel.
- Nao reinicie o host base do ambiente de prova.

