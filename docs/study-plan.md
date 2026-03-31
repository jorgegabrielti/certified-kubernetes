# Plano Guiado de Estudos

Este documento define um passo a passo objetivo para estudar CKA, CKAD e CKS usando este repositório.

## Princípios do plano

- Estude em blocos semanais com meta de entrega clara.
- Trabalhe sempre com cronômetro.
- Faça tudo no terminal, com o mínimo possível de dependência de interface gráfica.
- Ao final de cada semana, registre o que falhou, o que tomou mais tempo e quais comandos precisam virar memória muscular.
- O objetivo não é apenas concluir as listas, mas repeti-las até ganhar velocidade.

## Rotina padrão por sessão

1. Preparar o lab.
2. Executar a lista da semana sem consultar notas por 15 a 30 minutos.
3. Consultar documentação oficial apenas para os pontos travados.
4. Refazer a mesma lista do zero corrigindo os erros.
5. Registrar tempo final, erros e comandos-chave.

## Semana 0 - Preparacao do ambiente

Objetivo: deixar o lab funcional e o fluxo de estudo reproduzivel.

Passo a passo:
1. Ler o [README.md](../README.md) inteiro para entender a estrutura do projeto.
2. Escolher o ambiente principal de treino: AWS via Terraform ou local via Vagrant.
3. Subir um cluster funcional seguindo o quickstart correspondente.
4. Validar `kubectl get nodes`, `kubectl get pods -A` e `cilium status`.
5. Destruir e subir novamente o ambiente para garantir repetibilidade.
6. Definir sua rotina semanal: dias, horário e duração de cada sessão.

Critério de saída:
- Você consegue subir e destruir o lab sem hesitação.
- Você sabe onde estão as trilhas em CKA, CKAD e CKS.

## Semana 1 - Base de CKA

Objetivo: dominar bootstrap do cluster, upgrade e backup de ETCD.

Passo a passo:
1. Executar a Lista 1 da [CKA/README.md](../CKA/README.md).
2. Repetir a Lista 1 no mínimo 3 vezes.
3. Cronometrar especialmente as tarefas de `kubeadm init`, upgrade e snapshot.
4. Criar um pequeno checklist pessoal para backup e restore do ETCD.
5. Encerrar a semana executando a lista inteira sem apoio externo.

Critério de saída:
- Você consegue fazer backup e restore do ETCD sem consultar comandos prontos.
- Você consegue explicar a ordem correta de upgrade do control plane e dos workers.

## Semana 2 - Scheduling, rede e storage no CKA

Objetivo: ganhar confiança operacional em agendamento, conectividade e persistência.

Passo a passo:
1. Executar as Listas 2, 3 e 4 da [CKA/README.md](../CKA/README.md).
2. Repetir a Lista 2 duas vezes com foco em `cordon`, `drain`, `uncordon`, taints e affinity.
3. Repetir a Lista 3 duas vezes com foco em `Service`, DNS, `NetworkPolicy` e troubleshooting de rede.
4. Repetir a Lista 4 duas vezes com foco em PV, PVC e diagnóstico de PVC `Pending`.
5. Fechar a semana com uma execução encadeada de scheduling + rede + storage.

Critério de saída:
- Você identifica rápido problemas de selector, policy, mount e scheduling.
- Você executa tasks de rede e storage sem depender de copiar comandos.

## Semana 3 - Troubleshooting e operacao no CKA

Objetivo: resolver falhas reais de cluster com rapidez.

Passo a passo:
1. Executar as Listas 5, 6 e 7 da [CKA/README.md](../CKA/README.md).
2. Criar falhas propositais em probes, imagens, portas, RBAC e runtime.
3. Resolver tudo usando `describe`, `logs`, `events`, `journalctl` e manifestos.
4. Repetir ao menos 2 cenarios de RBAC e 2 cenarios de rollback.
5. Registrar um fluxo padrão de troubleshooting: sintoma, hipótese, evidência, correção, validação.

Critério de saída:
- Você tem um método consistente de troubleshooting.
- Você sabe quando olhar cluster, node, pod, log ou evento sem perder tempo.

## Semana 4 - Fechamento de CKA

Objetivo: consolidar administração de cluster em modo simulado.

Passo a passo:
1. Executar as Listas 8, 9 e 10 da [CKA/README.md](../CKA/README.md).
2. Fazer um simulado de 2 horas cobrindo ao menos 6 tarefas misturadas.
3. Repetir o simulado corrigindo apenas os pontos fracos.
4. Escolher as 3 tarefas mais lentas e treiná-las isoladamente.
5. Registrar sua primeira baseline de tempo para CKA.

Critério de saída:
- Você completa um simulado coerente dentro do tempo.
- Você sabe quais tópicos ainda precisam de reforço antes de avançar.

## Semana 5 - Base de CKAD

Objetivo: ganhar velocidade criando workloads corretamente.

Passo a passo:
1. Executar as Listas 1, 2 e 3 da [CKAD/README.md](../CKAD/README.md).
2. Repetir criação de `Deployment`, `Service`, `ConfigMap`, `Secret`, `initContainer` e sidecar.
3. Praticar geração de YAML com `kubectl create --dry-run=client -o yaml`.
4. Validar sempre com `kubectl get`, `describe`, `logs` e testes de conectividade.
5. Refazer todos os exercícios reduzindo o tempo da primeira execução.

Critério de saída:
- Você cria manifestos básicos rápido e com poucos erros.
- Você sabe transformar pod simples em deployment sem perder comportamento.

## Semana 6 - Entrega e rollout no CKAD

Objetivo: dominar atualizações, escalonamento e execução agendada.

Passo a passo:
1. Executar as Listas 4, 5 e 6 da [CKAD/README.md](../CKAD/README.md).
2. Treinar rollout, rollback, HPA, Jobs, CronJobs, exposição e `NetworkPolicy`.
3. Simular uma entrega ruim e recuperar via rollback.
4. Validar cada alteração com status e testes simples.
5. Repetir os cenarios mais lentos ate que virem rotina.

Critério de saída:
- Você faz rollout e rollback sem hesitar.
- Você sabe depurar falhas de Jobs, Services e Ingress rapidamente.

## Semana 7 - Fechamento de CKAD

Objetivo: consolidar configuração aplicacional e debug.

Passo a passo:
1. Executar as Listas 7, 8, 9 e 10 da [CKAD/README.md](../CKAD/README.md).
2. Fazer um simulado de 2 horas com foco em construir e corrigir workloads.
3. Repetir o simulado tentando usar menos tempo de consulta.
4. Refinar um checklist de validação final: pods, services, env, volumes, securityContext, rollout.
5. Registrar a segunda baseline de tempo, agora para CKAD.

Critério de saída:
- Você consegue montar uma aplicação inteira de ponta a ponta sob pressão.
- Você encontra e corrige erros de manifesto com rapidez.

## Semana 8 - Base de CKS

Objetivo: iniciar a trilha de segurança com controles essenciais.

Passo a passo:
1. Executar as Listas 1, 2 e 3 da [CKS/README.md](../CKS/README.md).
2. Praticar RBAC mínimo, `securityContext`, seccomp e redução de privilégios.
3. Validar que workloads inseguros são corrigidos sem quebrar a aplicação.
4. Registrar quais controles você consegue aplicar de memória.
5. Repetir os cenarios até que virem padrão operacional.

Critério de saída:
- Você reconhece rapidamente manifestos inseguros.
- Você corrige RBAC e pod security com confiança.

## Semana 9 - Supply chain, rede e dados no CKS

Objetivo: ampliar sua cobertura de segurança para imagens, tráfego e secrets.

Passo a passo:
1. Executar as Listas 4, 5 e 6 da [CKS/README.md](../CKS/README.md).
2. Treinar scan de imagem, políticas de admissão, `NetworkPolicy` default-deny e proteção de secrets.
3. Simular imagem vulnerável, regra de rede aberta demais e secret exposto.
4. Corrigir cada cenário e provar a correção com comandos objetivos.
5. Repetir os cenarios até reduzir tempo e erros.

Critério de saída:
- Você sabe validar conformidade, não só aplicar configuração.
- Você consegue explicar o risco mitigado em cada ação.

## Semana 10 - Fechamento de CKS

Objetivo: terminar a trilha de segurança em modo incidente e simulado.

Passo a passo:
1. Executar as Listas 7, 8, 9 e 10 da [CKS/README.md](../CKS/README.md).
2. Rodar um simulado com incidente, contenção e recuperação.
3. Repetir o simulado buscando decisões mais rápidas e menos retrabalho.
4. Montar um checklist final de hardening e resposta a incidente.
5. Registrar a terceira baseline de tempo, agora para CKS.

Critério de saída:
- Você consegue conter e corrigir incidentes sem se perder na sequência.
- Você fecha um simulado de segurança com validação final objetiva.

## Semana 11 - Integracao entre certificacoes

Objetivo: cruzar administração, desenvolvimento e segurança no mesmo ambiente.

Passo a passo:
1. Montar um lab do zero.
2. Executar uma lista de CKA, uma de CKAD e uma de CKS na mesma semana.
3. Priorizar tarefas onde um domínio afeta o outro, como rollout seguro, RBAC de aplicação e troubleshooting de policy.
4. Registrar quais conhecimentos se repetem entre as três provas.
5. Fazer um simulado híbrido de 2 horas.

Critério de saída:
- Você começa a enxergar Kubernetes como sistema único, não como provas isoladas.

## Semana 12 - Revisao final e repeticao intensiva

Objetivo: transformar pontos fracos em rotina.

Passo a passo:
1. Revisar todas as anotações de erro acumuladas desde a Semana 0.
2. Separar os 10 cenarios mais lentos ou mais propensos a falha.
3. Reexecutar esses 10 cenarios em bloco.
4. Fazer pelo menos um simulado final por certificação.
5. Definir se o foco inicial da prova será CKA, CKAD ou CKS com base no seu desempenho real.

Critério de saída:
- Você tem clareza objetiva sobre a certificação mais madura para tentar primeiro.

## Meta de repeticao

- CKA: repetir o ciclo completo pelo menos 10 vezes ao longo da preparação.
- CKAD: repetir o ciclo completo pelo menos 10 vezes ao longo da preparação.
- CKS: repetir o ciclo completo pelo menos 10 vezes ao longo da preparação.

## Regra de ouro

Se uma tarefa levou tempo demais, não marque como concluída apenas porque funcionou uma vez. Refaça até que o caminho fique previsível e rápido.