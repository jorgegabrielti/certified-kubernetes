# CKS - Trilhas Praticas

Esta pasta concentra simulados praticos para a certificacao CKS.

Referencias:
- Curriculo oficial: `CKS_Curriculum v1.34.pdf`
- Base operacional de prova: https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad

## Como usar

- Execute os cenarios em um cluster descartavel e com privilegios administrativos.
- Trate cada lista como incidente ou tarefa de hardening com prazo curto.
- Quando a ferramenta nao existir no lab, considere a instalacao como parte do exercicio.
- Meta minima: completar ao menos 10 ciclos praticos durante a preparacao.

## Dicas de prova

- O CKS tambem exige resolucao pratica, com foco em seguranca de cluster e workloads.
- Priorize tarefas que reduzam risco rapidamente: isolamento, RBAC, politicas e resposta a incidente.
- Valide sempre antes e depois com comandos objetivos para provar conformidade.
- Automatize o maximo possivel com manifestos e comandos repetiveis.

## Lista 1 - Hardening Basico do Cluster

1. Criar um cluster Kubernetes funcional na versao alvo do lab.
2. Endurecer a configuracao de kube-apiserver, kubelet e container runtime conforme o cenario.
3. Restringir acesso administrativo por RBAC e contas de servico dedicadas.
4. Habilitar ou revisar audit logging do cluster.
5. Validar que componentes continuam saudaveis apos o hardening.
6. Produzir checklist curto com os controles aplicados.

## Lista 2 - RBAC e Minimização de Privilegios

1. Criar namespaces para times distintos.
2. Configurar `Role`, `ClusterRole`, `RoleBinding` e `ClusterRoleBinding` com privilegio minimo.
3. Criar `ServiceAccounts` separadas para CI, operacao e aplicacao.
4. Validar acesso com `kubectl auth can-i`.
5. Corrigir uma permissao excessiva proposital.
6. Bloquear acesso cluster-wide desnecessario.

## Lista 3 - Seguranca de Pods

1. Criar workloads que executem como usuario nao-root.
2. Aplicar `seccompProfile`, `allowPrivilegeEscalation: false` e remocao de capabilities.
3. Bloquear pods privilegiados ou com `hostPath` indevido.
4. Corrigir manifestos inseguros mantendo a aplicacao funcional.
5. Validar que o pod nao consegue executar acoes proibidas.
6. Revisar os eventos e mensagens de admissao para confirmar a politica.

## Lista 4 - Seguranca de Imagens e Supply Chain

1. Escanear imagens com Trivy ou ferramenta equivalente.
2. Identificar e substituir uma imagem com vulnerabilidades criticas.
3. Restringir pull apenas a registries autorizados.
4. Configurar politica de admissao para barrar imagens nao conformes.
5. Validar a rejeicao de um workload inseguro.
6. Atualizar o deployment com imagem aprovada e sem regressao.

## Lista 5 - Segregacao de Rede

1. Criar aplicacoes em namespaces distintos com niveis de confianca diferentes.
2. Definir `NetworkPolicy` default-deny para ingress e egress.
3. Liberar apenas fluxos estritamente necessarios.
4. Validar bloqueios e permissoes com pods de teste.
5. Corrigir uma brecha proposital em uma regra de rede.
6. Confirmar isolamento apos restart dos workloads.

## Lista 6 - Secrets e Protecao de Dados

1. Criar `Secrets` para uma aplicacao e limitar acesso por namespace e `ServiceAccount`.
2. Habilitar ou revisar criptografia de secrets em repouso no ETCD quando o lab permitir.
3. Fazer backup do ETCD com seguranca operacional.
4. Simular exposicao indevida de secret e corrigir a causa.
5. Rotacionar um secret sem downtime relevante.
6. Validar que apenas workloads autorizados conseguem consumir o dado sensivel.

## Lista 7 - Runtime Security e Deteccao

1. Instalar ou validar ferramenta de deteccao runtime, como Falco.
2. Gerar um evento suspeito controlado, como execucao interativa indevida em pod.
3. Detectar o evento por logs, regras ou alertas.
4. Isolar o workload ou o node afetado.
5. Coletar evidencias minimas para analise posterior.
6. Restaurar operacao segura apos contencao.

## Lista 8 - Admission Control e Politicas

1. Configurar politica com Kyverno, Gatekeeper ou mecanismo equivalente.
2. Exigir campos como `runAsNonRoot`, limites de recursos e labels obrigatorias.
3. Testar manifesto conforme e manifesto nao conforme.
4. Corrigir a aplicacao para atender a politica.
5. Criar excecao controlada apenas quando houver justificativa tecnica.
6. Validar que a politica continua efetiva apos rollout.

## Lista 9 - Resposta a Incidente

1. Receber um cenario com pod comprometido ou node suspeito.
2. Identificar rapidamente escopo, namespace e imagem envolvidos.
3. Isolar o problema com `cordon`, `drain`, `delete` ou bloqueio de rede, conforme o caso.
4. Revogar credenciais ou secrets potencialmente expostos.
5. Corrigir a causa raiz e reimplantar a carga de forma segura.
6. Validar que o cluster voltou a estado saudavel e sem o vetor original.

## Lista 10 - Simulado Completo de Seguranca

1. Provisionar um cluster e aplicar baseline de hardening.
2. Implantar aplicacao com controles de pod security, RBAC e network policy.
3. Escanear imagem e barrar artefato nao conforme.
4. Habilitar trilha minima de auditoria e deteccao runtime.
5. Simular incidente e executar contencao, erradicacao e recuperacao.
6. Encerrar validando politicas ativas, workloads conformes e componentes essenciais saudaveis.

## Ritmo recomendado

- Semana 1 a 2: Listas 1 a 3.
- Semana 3 a 4: Listas 4 a 6.
- Semana 5 a 6: Listas 7 e 8.
- Semana 7 em diante: Listas 9 e 10, repetindo o ciclo completo ate 10 execucoes ou mais.