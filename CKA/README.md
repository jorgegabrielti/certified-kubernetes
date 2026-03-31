# CKA - Trilhas Praticas

Esta pasta concentra simulados praticos para a certificacao CKA.

Referencias:
- Curriculo oficial: `CKA_Curriculum_v1.35.pdf`
- Dicas oficiais de prova: https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad

## Como usar

- Execute cada lista em modo cronometrado, idealmente com 2 horas.
- Registre tempo total, comandos-chave, erros e correcoes.
- Priorize terminal, `kubectl`, `kubeadm`, `etcdctl`, `systemctl`, `journalctl` e YAML.
- Meta minima: completar pelo menos 10 ciclos de treino ao longo da preparacao.
- Se o seu lab estiver em uma versao anterior, adapte a versao-alvo mantendo a logica da tarefa.

## Dicas de prova

- A prova e hands-on e costuma trazer de 15 a 20 tarefas em 2 horas.
- Trabalhe sempre no host indicado na tarefa e volte ao host base ao finalizar cada item.
- Use `sudo -i` cedo quando a tarefa exigir privilegios administrativos.
- Aproveite `kubectl` com alias `k`, autocompletion e `yq` quando disponivel.
- Nao reinicie o host base do ambiente de prova.

## Lista 1 - Ciclo de Vida do Cluster e ETCD

1. Criar um cluster Kubernetes com pelo menos 1 worker node e 1 control plane na versao 1.34.
2. Fazer o upgrade do cluster para a versao 1.35.
3. Criar no cluster um `Deployment`, um `Service` e um `ConfigMap` para uma aplicacao de teste.
4. Fazer o backup do ETCD para o path `/tmp/cka-snapshot.db`.
5. Deletar os recursos criados na tarefa 3.
6. Fazer o restore do cluster e garantir que os recursos criados na tarefa 3 reaparecam.

## Lista 2 - Scheduling, Drain e Disponibilidade

1. Criar um cluster com 1 control plane e 2 workers.
2. Aplicar labels e taints nos nodes para separar workloads criticas e workloads batch.
3. Criar workloads usando `nodeSelector`, `nodeAffinity` e `tolerations`.
4. Fazer `cordon` e `drain` de um worker sem interromper a aplicacao critica.
5. Criar um `PodDisruptionBudget` para proteger uma aplicacao replicada.
6. Reabilitar o node com `uncordon` e validar o re-agendamento.

## Lista 3 - Networking e Service Discovery

1. Criar um namespace dedicado para testes de rede.
2. Subir dois `Deployments` que conversem entre si via `ClusterIP`.
3. Expor uma aplicacao com `NodePort` e outra com `LoadBalancer` simulado ou `Ingress` local.
4. Validar DNS interno com `nslookup` ou `dig` a partir de um pod temporario.
5. Criar uma `NetworkPolicy` que permita trafego apenas entre namespaces definidos.
6. Identificar e corrigir um problema proposital de conectividade entre pods.

## Lista 4 - Storage

1. Criar um `StorageClass` apropriado ao lab em uso.
2. Criar um `PersistentVolume` e um `PersistentVolumeClaim`.
3. Subir um pod que escreva dados persistentes no volume.
4. Simular a perda do pod e comprovar a persistencia dos dados.
5. Expandir o `PersistentVolumeClaim` quando o provisioner suportar resize.
6. Diagnosticar um PVC em estado `Pending` e corrigir a causa.

## Lista 5 - Troubleshooting de Cluster

1. Quebrar propositalmente um manifesto do kubelet, do scheduler ou de um workload.
2. Localizar a causa raiz usando `kubectl describe`, `kubectl logs`, `journalctl` e eventos.
3. Corrigir um problema de imagem, porta ou `readinessProbe` em um `Deployment`.
4. Corrigir um node `NotReady` causado por configuracao de runtime ou rede.
5. Restaurar a saude de um componente do control plane.
6. Documentar os sinais que levaram ao diagnostico.

## Lista 6 - Seguranca e RBAC

1. Criar um `ServiceAccount` especifico para uma aplicacao.
2. Criar `Role` e `RoleBinding` com privilegios minimos em um namespace.
3. Criar `ClusterRole` e `ClusterRoleBinding` apenas quando o escopo cluster-wide for necessario.
4. Validar o acesso com `kubectl auth can-i`.
5. Bloquear a execucao privilegiada de um pod usando politicas disponiveis no lab.
6. Corrigir uma permissao excessiva sem quebrar a aplicacao.

## Lista 7 - Observabilidade e Operacoes

1. Criar workloads com `livenessProbe`, `readinessProbe` e `startupProbe`.
2. Coletar logs de aplicacoes e eventos do cluster para diagnosticar uma falha.
3. Identificar consumo anormal de CPU ou memoria via `kubectl top` quando metrics-server estiver disponivel.
4. Ajustar `requests` e `limits` de recursos para estabilizar a aplicacao.
5. Executar rollout controlado e acompanhar `rollout status`.
6. Fazer rollback de uma versao defeituosa.

## Lista 8 - Namespaces e Multi-Tenancy

1. Criar tres namespaces com quotas e `LimitRange` distintas.
2. Implantar workloads com limites diferentes por namespace.
3. Restringir comunicacao entre namespaces com `NetworkPolicy`.
4. Delegar acesso administrativo de namespace via RBAC.
5. Validar isolamento de recursos e consumo.
6. Corrigir um namespace que excedeu a quota e ficou bloqueado.

## Lista 9 - Manutencao e Recuperacao

1. Simular manutencao de um node worker e planejar a evacuacao de cargas.
2. Renovar token de join do cluster.
3. Adicionar um novo worker ao cluster.
4. Remover um worker com seguranca e limpar o estado residual.
5. Gerar novo backup de ETCD e testar integridade do snapshot.
6. Validar que o cluster voltou ao estado esperado apos a manutencao.

## Lista 10 - Simulado Completo

1. Provisionar um cluster funcional com control plane e workers.
2. Atualizar uma parte do cluster para a versao alvo sem indisponibilidade desnecessaria.
3. Criar workloads, storage, RBAC e politicas de rede em um unico fluxo.
4. Executar backup do ETCD e de manifestos criticos.
5. Introduzir e corrigir pelo menos duas falhas operacionais no cluster.
6. Encerrar validando nodes `Ready`, pods essenciais `Running` e persistencia restaurada.

## Ritmo recomendado

- Semana 1 a 3: Listas 1 a 4.
- Semana 4 a 6: Listas 5 a 8.
- Semana 7 em diante: Listas 9 e 10 em modo simulado.
- Repita o ciclo completo ate atingir no minimo 10 execuções totais.