# CKAD - Trilhas Praticas

Esta pasta concentra simulados praticos para a certificacao CKAD.

Referencias:
- Curriculo oficial: `CKAD_Curriculum_v1.35.pdf`
- Dicas oficiais de prova: https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad

## Como usar

- Trabalhe cada lista com foco em velocidade de entrega e precisao de manifestos.
- Priorize `kubectl`, `kustomize`, `yq`, probes, rollout, debug e configuracao de aplicacoes.
- Cronometre cada lista e registre os atalhos que mais economizam tempo.
- Meta minima: executar pelo menos 10 ciclos completos ao longo da preparacao.

## Dicas de prova

- A prova e inteiramente pratica, com tarefas curtas e foco em entrega de recursos aplicacionais.
- Leia primeiro todas as tarefas e resolva cedo as de baixo custo e alta certeza.
- Prefira comandos geradores como `kubectl create ... --dry-run=client -o yaml` quando acelerarem a escrita.
- Valide sempre com `kubectl get`, `describe`, `logs` e testes funcionais simples.

## Lista 1 - Pods, Deployments e Services

1. Criar um namespace de aplicacao.
2. Criar um `Deployment` com imagem publica, 3 replicas e `Service` `ClusterIP`.
3. Adicionar `labels`, `annotations` e `selectors` corretos.
4. Configurar `readinessProbe` e `livenessProbe`.
5. Expor a aplicacao para outro pod de teste no mesmo namespace.
6. Validar rollout e conectividade fim a fim.

## Lista 2 - ConfigMaps, Secrets e Environment

1. Criar um `ConfigMap` a partir de literais e arquivo.
2. Criar um `Secret` para credenciais de aplicacao.
3. Injetar configuracoes via `env`, `envFrom` e volume.
4. Atualizar a configuracao sem recriar manualmente todos os recursos.
5. Garantir que a aplicacao le o valor esperado em runtime.
6. Corrigir um erro de chave ou mount path propositalmente inserido.

## Lista 3 - Multi-Container Pods

1. Criar um pod com container principal e sidecar de logs.
2. Adicionar um `initContainer` para preparar configuracao ou artefatos.
3. Compartilhar dados entre containers usando volume apropriado.
4. Validar ordem de inicializacao e dependencia entre containers.
5. Simular falha no sidecar e ajustar a estrategia de observabilidade.
6. Converter o pod em `Deployment` mantendo o comportamento esperado.

## Lista 4 - Rollout, Rollback e Escalonamento

1. Criar um `Deployment` com estrategia `RollingUpdate`.
2. Atualizar a imagem para uma versao nova e acompanhar `rollout status`.
3. Introduzir uma versao quebrada e executar rollback.
4. Configurar `HorizontalPodAutoscaler` baseado em CPU quando o lab suportar metrics.
5. Ajustar `requests` e `limits` para estabilizar o autoscaling.
6. Validar zero downtime funcional durante a atualizacao.

## Lista 5 - Jobs e CronJobs

1. Criar um `Job` que execute uma tarefa finita e gere artefato de log.
2. Configurar `backoffLimit` e `completions` adequados.
3. Criar um `CronJob` com agenda previsivel e historico limitado.
4. Forcar uma falha e analisar status, retries e eventos.
5. Suspender e reativar o `CronJob`.
6. Limpar os recursos mantendo apenas o YAML validado.

## Lista 6 - NetworkPolicy e Exposicao

1. Criar duas aplicacoes em namespaces distintos.
2. Expor uma aplicacao com `Service` e outra com `Ingress` quando houver controller.
3. Restringir trafego com `NetworkPolicy` para permitir apenas o fluxo necessario.
4. Validar acesso permitido e bloqueado a partir de pods de teste.
5. Corrigir um seletor de policy ou service propositalmente incorreto.
6. Documentar o caminho de trafego esperado.

## Lista 7 - Persistencia e Estado

1. Criar um `PersistentVolumeClaim` para uma aplicacao stateful simples.
2. Montar o volume em um `Deployment` ou `StatefulSet`.
3. Popular dados iniciais por `initContainer` ou script de bootstrap.
4. Reiniciar os pods e comprovar persistencia.
5. Corrigir um problema de permissao ou mount path.
6. Validar integridade dos dados apos redeploy.

## Lista 8 - Seguranca de Aplicacao

1. Criar workloads com `securityContext` nao-root.
2. Remover capacidades desnecessarias e habilitar filesystem read-only quando possivel.
3. Restringir acesso a secrets somente a pods autorizados.
4. Definir `serviceAccount` especifico para a aplicacao.
5. Corrigir uma configuracao insegura proposital em um manifesto.
6. Validar o comportamento final sem regressao funcional.

## Lista 9 - Debug e Observabilidade de Aplicacoes

1. Receber uma aplicacao com erro de startup, probe ou configuracao.
2. Usar `kubectl logs`, `describe`, `exec` e eventos para localizar a falha.
3. Corrigir imagem, comando, args, porta ou env var conforme necessario.
4. Criar pod temporario para testar conectividade e DNS.
5. Validar disponibilidade com endpoints e readiness.
6. Fazer cleanup mantendo apenas a versao correta do manifesto.

## Lista 10 - Simulado Completo de Entrega

1. Criar namespace, `ConfigMap`, `Secret`, `Deployment`, `Service` e `Ingress` de uma aplicacao.
2. Adicionar probes, recursos, `securityContext` e escalonamento.
3. Incluir um `Job` auxiliar para carga inicial ou migracao.
4. Aplicar policy de rede e persistencia quando exigido.
5. Simular erro de rollout e recuperar com rollback.
6. Validar a aplicacao ponta a ponta com testes simples via terminal.

## Ritmo recomendado

- Semana 1 a 2: Listas 1 a 3.
- Semana 3 a 4: Listas 4 a 6.
- Semana 5 a 6: Listas 7 a 9.
- Semana 7 em diante: Lista 10 e repeticao do ciclo completo ate 10 execucoes ou mais.