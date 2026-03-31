# Plano Guiado de Estudos

Este documento organiza os estudos em 12 semanas, de segunda a sexta, com 1 hora por dia.

## Regras do plano

- Cada sessão dura 60 minutos.
- Estude sempre com cronômetro.
- Trabalhe no terminal sempre que possível.
- Ao final de cada sexta-feira, registre erros, comandos lentos e tópicos inseguros.
- Não avance de semana só porque concluiu uma vez. Avance quando o fluxo estiver previsível.

## Estrutura fixa de 1 hora por dia

Use esta divisão como padrão:

1. 10 min: preparar lab, abrir material e revisar objetivo do dia.
2. 35 min: executar a tarefa principal sem consultar anotações no início.
3. 10 min: corrigir erros, consultar documentação oficial e repetir pontos travados.
4. 5 min: registrar tempo, falhas e comandos importantes.

## Semana 0 - Preparacao do ambiente

Objetivo: deixar o ambiente de treino repetível e pronto para uso diário.

### Segunda-feira

1. Ler o [README.md](../README.md).
2. Entender a estrutura do repositório.
3. Escolher o ambiente principal: AWS ou Vagrant.

### Terça-feira

1. Executar o quickstart do ambiente escolhido.
2. Subir o cluster pela primeira vez.
3. Registrar os comandos necessários para bootstrap.

### Quarta-feira

1. Validar `kubectl get nodes`.
2. Validar `kubectl get pods -A`.
3. Validar `cilium status`.

### Quinta-feira

1. Destruir o ambiente.
2. Subir tudo novamente do zero.
3. Medir o tempo total do processo.

### Sexta-feira

1. Revisar tudo sem consultar o README no início.
2. Confirmar que o ambiente sobe de forma previsível.
3. Definir o horário fixo das próximas semanas.

Critério de saída:
- Você consegue subir, validar e destruir o lab sem hesitação.

## Semana 1 - CKA Cluster Architecture

Objetivo: dominar bootstrap, upgrade kubeadm e backup/restore de ETCD.
Tópico CKA: Cluster Architecture, Installation and Configuration (25%)
Referência de upgrade: [CKA/howto-cluster-upgrade.md](../CKA/howto-cluster-upgrade.md)

### Segunda-feira

1. Ler [01-cluster-architecture-25pct/README.md](../CKA/01-cluster-architecture-25pct/README.md) e o guia de upgrade.
2. Confirmar que o cluster está em `Ready` com `kubectl get nodes`.
3. Anotar a versão atual de kubeadm, kubelet e kubectl com `dpkg -l`.

### Terça-feira

1. Fazer backup do ETCD antes de qualquer mudança.
2. Atualizar o repositório APT para o próximo minor version.
3. Executar o upgrade completo do control plane (fases 2.1 a 2.7 do guia).

### Quarta-feira

1. Executar o upgrade do worker01 (fases 3.1 a 3.4 do guia).
2. Validar que todos os nodes estão `Ready` na nova versão com `kubectl get nodes -o wide`.
3. Se houver mais de um minor version disponível, repetir o processo com novo backup do ETCD.

### Quinta-feira

1. Criar recursos de teste: `Deployment`, `Service` e `ConfigMap`.
2. Fazer snapshot do ETCD no estado atual: `/tmp/cka-snapshot.db`.
3. Validar o snapshot com `etcdctl snapshot status`.

### Sexta-feira

1. Deletar os recursos criados na quinta-feira.
2. Restaurar o ETCD a partir do snapshot.
3. Confirmar que os recursos voltaram e anotar o fluxo completo de memória.

Critério de saída:
- Você executa o ciclo completo (upgrade → backup → destroy → restore) sem depender de consulta contínua.

## Semana 2 - CKA Workloads, Networking e Storage

Objetivo: consolidar scheduling, rede e storage.

### Segunda-feira

1. Executar os exercícios de [02-workloads-scheduling-15pct/](../CKA/02-workloads-scheduling-15pct/).
2. Praticar `cordon`, `drain`, `uncordon`, taints e affinity.

### Terça-feira

1. Repetir os exercícios de workloads e scheduling.
2. Corrigir o que ficou lento no dia anterior.

### Quarta-feira

1. Executar os exercícios de [03-services-networking-20pct/](../CKA/03-services-networking-20pct/).
2. Focar em `Service`, DNS e `NetworkPolicy`.

### Quinta-feira

1. Executar os exercícios de [04-storage-10pct/](../CKA/04-storage-10pct/).
2. Focar em PV, PVC, pod com volume e diagnóstico de PVC `Pending`.

### Sexta-feira

1. Encadear um mini-simulado com tarefas dos três domínios.
2. Medir tempo e pontos de falha.

Critério de saída:
- Você resolve scheduling, rede e storage sem copiar comandos prontos.

## Semana 3 - CKA Troubleshooting e RBAC

Objetivo: ficar rápido em troubleshooting, RBAC e operação.

### Segunda-feira

1. Executar os exercícios de [05-troubleshooting-30pct/](../CKA/05-troubleshooting-30pct/).
2. Criar falhas propositais em probes, imagem e portas.

### Terça-feira

1. Repetir os exercícios de troubleshooting.
2. Resolver usando `describe`, `logs`, eventos e `journalctl`.

### Quarta-feira

1. Executar os exercícios de RBAC em [01-cluster-architecture-25pct/](../CKA/01-cluster-architecture-25pct/).
2. Focar em `ServiceAccount`, `Role`, `RoleBinding` e `kubectl auth can-i`.

### Quinta-feira

1. Executar os exercícios de workloads e scheduling restantes.
2. Focar em probes, rollout, rollback e análise operacional.

### Sexta-feira

1. Fazer uma sessão só de troubleshooting misto.
2. Resolver pelo menos 3 falhas diferentes em 1 hora.

Critério de saída:
- Você tem um fluxo claro de diagnóstico e validação.

## Semana 4 - CKA Simulado Final

Objetivo: fechar a trilha de CKA em modo simulado.

### Segunda-feira

1. Executar exercícios de namespaces, quotas e isolamento (domínios 01 e 02).
2. Focar em criação rápida de recursos via `kubectl`.

### Terça-feira

1. Executar exercícios de manutenção de cluster em [01-cluster-architecture-25pct/](../CKA/01-cluster-architecture-25pct/).
2. Focar em join token, adição e remoção de worker.

### Quarta-feira

1. Cobrir os domínios de maior peso: Troubleshooting (30%) e Cluster Architecture (25%).
2. Treinar o fluxo completo de administração de cluster.

### Quinta-feira

1. Repetir as tarefas mais lentas das sessões anteriores.
2. Refinar sequência e tempo.

### Sexta-feira

1. Fazer um simulado completo de CKA em 1 hora cobrindo todos os domínios.
2. Registrar baseline de tempo da certificação.

Critério de saída:
- Você encerra a trilha CKA com visão clara dos pontos fortes e fracos.

## Semana 5 - CKAD Listas 1, 2 e 3

Objetivo: ganhar velocidade em manifestos e workloads básicos.

### Segunda-feira

1. Executar a Lista 1 em [CKAD/README.md](../CKAD/README.md).
2. Focar em `Deployment`, `Service`, labels e probes.

### Terça-feira

1. Repetir a Lista 1.
2. Gerar YAML com `kubectl create --dry-run=client -o yaml`.

### Quarta-feira

1. Executar a Lista 2.
2. Focar em `ConfigMap`, `Secret`, env e volume.

### Quinta-feira

1. Executar a Lista 3.
2. Focar em sidecar, `initContainer` e compartilhamento de volume.

### Sexta-feira

1. Refazer as 3 listas em sequência reduzindo o tempo da primeira execução.

Critério de saída:
- Você cria manifestos básicos de aplicação com fluidez.

## Semana 6 - CKAD Listas 4, 5 e 6

Objetivo: dominar rollout, Jobs, CronJobs e exposição.

### Segunda-feira

1. Executar a Lista 4.
2. Focar em rollout, rollback e HPA.

### Terça-feira

1. Repetir a Lista 4.
2. Medir tempo de correção de rollout ruim.

### Quarta-feira

1. Executar a Lista 5.
2. Focar em `Job`, `CronJob`, retries e limpeza.

### Quinta-feira

1. Executar a Lista 6.
2. Focar em `Service`, `Ingress` e `NetworkPolicy`.

### Sexta-feira

1. Fazer mini-simulado de entrega e rollback.
2. Validar tudo com comandos curtos e objetivos.

Critério de saída:
- Você entrega e corrige workloads rapidamente.

## Semana 7 - CKAD Listas 7, 8, 9 e 10

Objetivo: fechar a trilha de CKAD com simulado prático.

### Segunda-feira

1. Executar a Lista 7.
2. Focar em persistência e estado.

### Terça-feira

1. Executar a Lista 8.
2. Focar em `securityContext` e acesso mínimo.

### Quarta-feira

1. Executar a Lista 9.
2. Focar em debug de aplicação.

### Quinta-feira

1. Executar a Lista 10.
2. Montar uma aplicação completa de ponta a ponta.

### Sexta-feira

1. Fazer simulado de CKAD em 1 hora.
2. Registrar baseline de tempo da certificação.

Critério de saída:
- Você consegue construir e corrigir workloads sob pressão.

## Semana 8 - CKS Listas 1, 2 e 3

Objetivo: construir base de hardening, RBAC e pod security.

### Segunda-feira

1. Executar a Lista 1 em [CKS/README.md](../CKS/README.md).
2. Focar em hardening do cluster.

### Terça-feira

1. Executar a Lista 2.
2. Focar em RBAC mínimo e validação com `kubectl auth can-i`.

### Quarta-feira

1. Executar a Lista 3.
2. Focar em `securityContext`, seccomp e capabilities.

### Quinta-feira

1. Repetir as tarefas mais lentas das três listas.
2. Validar se os workloads continuam funcionais.

### Sexta-feira

1. Fazer mini-simulado de hardening.
2. Registrar os controles que você já aplica de memória.

Critério de saída:
- Você reconhece rapidamente configurações inseguras em cluster e pods.

## Semana 9 - CKS Listas 4, 5 e 6

Objetivo: expandir a trilha de segurança para supply chain, rede e dados.

### Segunda-feira

1. Executar a Lista 4.
2. Focar em scan de imagens e política de admissão.

### Terça-feira

1. Executar a Lista 5.
2. Focar em `NetworkPolicy` default-deny e isolamento.

### Quarta-feira

1. Executar a Lista 6.
2. Focar em secrets e proteção de dados.

### Quinta-feira

1. Repetir os cenários mais lentos.
2. Validar a correção com comandos objetivos.

### Sexta-feira

1. Fazer mini-simulado de conformidade e correção.
2. Registrar o risco mitigado em cada cenário.

Critério de saída:
- Você sabe comprovar que a mitigação realmente funcionou.

## Semana 10 - CKS Listas 7, 8, 9 e 10

Objetivo: fechar a trilha de CKS com detecção, políticas e incidentes.

### Segunda-feira

1. Executar a Lista 7.
2. Focar em detecção e contenção runtime.

### Terça-feira

1. Executar a Lista 8.
2. Focar em políticas de admissão.

### Quarta-feira

1. Executar a Lista 9.
2. Focar em resposta a incidente.

### Quinta-feira

1. Executar a Lista 10.
2. Montar um fluxo completo de segurança do cluster.

### Sexta-feira

1. Fazer simulado de CKS em 1 hora.
2. Registrar baseline de tempo da certificação.

Critério de saída:
- Você consegue conter, corrigir e validar incidentes com objetividade.

## Semana 11 - Integracao entre certificacoes

Objetivo: cruzar administração, desenvolvimento e segurança no mesmo lab.

### Segunda-feira

1. Montar um lab do zero.
2. Executar uma tarefa típica de CKA.

### Terça-feira

1. No mesmo lab, executar uma tarefa típica de CKAD.

### Quarta-feira

1. No mesmo lab, executar uma tarefa típica de CKS.

### Quinta-feira

1. Repetir os pontos onde um domínio interfere no outro.
2. Exemplos: rollout seguro, RBAC de aplicação, network policy e troubleshooting.

### Sexta-feira

1. Fazer um simulado híbrido em 1 hora.
2. Registrar conhecimentos que se repetem entre as três provas.

Critério de saída:
- Você enxerga Kubernetes como um sistema único.

## Semana 12 - Revisao final e repeticao intensiva

Objetivo: transformar fraquezas em rotina operacional.

### Segunda-feira

1. Revisar todas as anotações acumuladas.
2. Selecionar os 10 cenários mais lentos.

### Terça-feira

1. Reexecutar 3 cenários lentos.

### Quarta-feira

1. Reexecutar mais 3 cenários lentos.

### Quinta-feira

1. Reexecutar os 4 cenários restantes.

### Sexta-feira

1. Fazer um simulado final da certificação que estiver mais madura.
2. Definir a ordem real de tentativa entre CKA, CKAD e CKS.

Critério de saída:
- Você sabe exatamente qual prova tentar primeiro e por quê.

## Meta de repeticao

- CKA: repetir o ciclo completo pelo menos 10 vezes ao longo da preparação.
- CKAD: repetir o ciclo completo pelo menos 10 vezes ao longo da preparação.
- CKS: repetir o ciclo completo pelo menos 10 vezes ao longo da preparação.

## Regra de ouro

Se uma tarefa levou tempo demais, não considere concluída só porque funcionou uma vez. Refaça até ficar rápida, previsível e defensável.