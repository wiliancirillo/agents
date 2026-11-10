# Métrica de uso por prompt (tokens, custo, tempo) — proposta

Status: proposta, não implementada. Decisão pendente na seção 7.
Local previsto da ferramenta: `~/Projects/agents/tools/usage/`.

## 1. Objetivo

Medir, por prompt, quanto um agente de código consumiu em um projeto: tokens, modelo, custo em USD e tempo de processamento.

Requisitos:

- A ferramenta é versionada e funciona em qualquer máquina.
- Ela é instalada em projetos que já estão em andamento. A medição começa na instalação. O passado do projeto não entra.
- Ela é offline e reprodutível: a mesma entrada gera o mesmo resultado em qualquer máquina.

## 2. O que foi verificado no ccusage (v20.0.38, em 2026-10-27)

- O ccusage não serve como biblioteca. O pacote npm traz só `src/cli.js`, que chama um binário nativo (`@ccusage/ccusage-linux-x64`). Não há `exports` nem API para importar. A única integração possível é chamar a CLI e ler o `--json`.
- O ccusage não dá o custo de cada chamada. `ccusage claude session --json --id <sessão>` lista as chamadas (1099 na sessão testada do gesher), todas com `costUSD: 0.0`. Isso vale nos modos `auto` e `calculate`. Só o `totalCost` da sessão vem preenchido.
- O total do ccusage diverge do Claude Code. Na sessão `39716dab-6d31-433d-a956-2db9b9224c9e` do gesher, o ccusage dá $59.34. A entrada `cost-state` do próprio Claude Code dá $82.21 e inclui `claude-haiku-5-5`, que não aparece nas chamadas listadas pelo ccusage. Hipótese não verificada: o ccusage não lê os logs de subagentes guardados em `<sessão>/`.
- O `--since` do ccusage aceita só data (`YYYYMMDD`), não hora. Ele não aplica um corte exato no momento da instalação.

Conclusão: o ccusage serve como checagem cruzada, não como motor da métrica.

## 3. O que o log do Claude Code oferece

Os logs ficam em `~/.claude/projects/<slug>/<session-uuid>.jsonl`. O `<slug>` é o caminho do projeto com `/` trocado por `-`.

- Cada prompt humano é uma entrada `user` com `promptId` único. Na sessão testada: 33 prompts, 33 `promptId` distintos.
- Cada chamada à API é uma entrada `assistant` com `message.model` e `message.usage`. O `usage` traz `input_tokens`, `output_tokens`, `cache_creation_input_tokens` e `cache_read_input_tokens`. A entrada também tem `timestamp`, `parentUuid`, `requestId` e `cwd`.
- Para atribuir uma chamada ao prompt, siga a cadeia `parentUuid` até a entrada `user` de origem. A alternativa é usar a janela de tempo entre um prompt e o seguinte.
- `cost-state` aparece uma vez por sessão, em geral no fim. Ele traz `totalCostUSD`, `totalAPIDuration`, `totalToolDuration`, `totalDuration` e `modelUsage`, com o custo por modelo. É o número oficial do Claude Code para a sessão.
- Entradas `system` têm `pendingBackgroundAgentCount`. Logo, subagentes em background podem terminar depois que o prompt acaba.
- Para o tempo de subagentes, pareie o início e a conclusão de cada chamada `Task`/`Agent`. O método está na skill `agent-usage-analytics`, em `references/jsonl-duration-derivation.md`.

## 4. Desenho

### 4.1 Instalação por projeto

```
~/Projects/agents/tools/usage/install.sh <projeto>
```

- O script é idempotente, como o `adopt.sh`. A adesão é opcional e separada do `adopt.sh`.
- Ele cria `.agents/usage.json` no projeto, que é versionado:

  ```json
  {
    "since": "2026-10-27T15:04:05Z",
    "toolVersion": "<commit do agents>"
  }
  ```

- `since` é o momento da instalação, em UTC. Toda máquina que clonar o projeto usa o mesmo corte. Reinstalar nunca altera `since`.
- Ele adiciona o hook `Stop` ao `.claude/settings.json` do projeto, que também é versionado. Mesclar esse JSON exige ferramenta própria (python3 ou jq), porque o `adopt.sh` é Bash puro e só cria o arquivo quando ele não existe.
- Ele avisa se o git ignora `.agents/usage.json` ou `.claude/settings.json`.

### 4.2 Captura por hook, a cada prompt

- O hook `Stop` chama `agents-usage capture`. O comando é procurado no PATH. O `wire.sh` instala o comando em cada máquina. Assim, o settings versionado não guarda um caminho absoluto de uma máquina.
- O hook recebe do Claude Code `session_id` e `transcript_path` (campos da documentação; confirmar na implementação).
- A cada execução, o hook relê a sessão a partir de `since` e grava um registro por `promptId`. Se o registro já existe, ele é atualizado. Assim, um subagente em background que termina depois do `Stop` corrige o registro do prompt anterior na próxima execução.
- O hook nunca bloqueia nem quebra a sessão. Se `agents-usage` não existir na máquina, ou se der erro, ele sai com 0 e não imprime nada na sessão. O erro vai para um arquivo de diagnóstico local.
- Motivo para capturar por hook em vez de varrer depois: segundo a documentação, o Claude Code apaga transcripts depois de `cleanupPeriodDays` (padrão: 30 dias). O hook guarda os números antes da limpeza.

### 4.3 Conteúdo do registro

Um registro por prompt:

- `promptId`, `sessionId`
- início, fim e duração ativa do prompt
- tempo somado dos subagentes. É soma por chamada: subagentes paralelos se sobrepõem, então essa soma não é tempo de relógio.
- número de chamadas à API
- tokens por modelo, nos 4 tipos
- custo em USD por modelo e total
- máquina, versão da ferramenta e versão da tabela de preço

O texto do prompt nunca entra no registro. No gesher, prompts podem conter dados de paciente, e isso cai na LGPD.

Antes de somar, elimine chamadas repetidas por `requestId`/`message.id`. Elimine também notificações de conclusão repetidas por `tool-use-id`.

### 4.4 Preço

- `tools/usage/pricing.json` é versionado e guarda o preço por modelo nos 4 tipos de token.
- Modelo sem preço na tabela gera aviso explícito. O custo desse modelo nunca vira 0 em silêncio.
- O relatório compara a soma dos prompts de cada sessão com o `totalCostUSD` do `cost-state`, quando ele existe. Uma diferença acima do limite gera aviso. Assim, preço errado ou modelo novo aparecem na hora.

### 4.5 Relatório

```
agents-usage report <projeto> [--json|--csv] [--since ...] [--until ...]
```

- Saída: uma linha por prompt, mais totais por sessão, por dia e por modelo.
- O relatório nunca conta nada anterior a `since`.

### 4.6 Papel do ccusage

O ccusage fica como checagem cruzada de tokens por sessão, fixado em uma versão (`bunx ccusage@20.0.38 ...`). Ele não exige instalação global e não entra no cálculo.

### 4.7 Outras ferramentas

Para incluir o Codex no futuro, crie um leitor próprio para o formato de log dele, com o mesmo formato de registro. Confirmar antes se o Codex tem um ponto de hook equivalente ao `Stop`.

## 5. Alternativa considerada: statusline

A statusline do Claude Code recebe o custo acumulado da sessão (`cost.total_cost_usd`, segundo a documentação; não verificado nesta versão). Gravar esse valor a cada prompt daria o custo exato pelo cálculo do Claude Code. Mas a statusline é configurada por máquina e ocupa a statusline do usuário. Por isso ela serve de complemento, não de base.

## 6. Limites

- A medição cobre só sessões que rodam com o hook ativo. Uma máquina sem `agents-usage` no PATH não registra nada.
- Não há registro antes da instalação.
- O custo é estimado pela tabela de preço versionada, conferida com o `cost-state`. Não é a fatura da Anthropic.
- O padrão de subagente assíncrono (`Agent` + `queue-operation`/`task-notification`) foi validado só nos logs do gesher. Os outros projetos precisam de confirmação.

## 7. Decisão pendente: onde fica o registro de uso

a) Local, fora do repo: `~/.local/share/agents-usage/<projeto>.jsonl`
   - O repo fica limpo.
   - O total entre máquinas exige exportar e juntar com `report --merge`.

b) No projeto, versionado: `.agents/usage/<máquina>.jsonl`, um arquivo por máquina, sem conflito de merge
   - O total entre máquinas vem pelo git, sem passo manual.
   - Em troca, o working tree fica sujo a cada prompt. Em projetos onde o agente faz commits sozinho (gesher), isso atrapalha.
   - Também esbarra na regra "never version logs" do `AGENTS.md`.

Recomendação: (a). Escolha (b) só se o histórico consolidado sem passo manual valer o custo.

## 8. Próximos passos, depois da decisão

1. Criar `tools/usage/` no repo agents com `install.sh`, `agents-usage` (`capture` e `report`) e `pricing.json`.
2. Instalar o comando no PATH pelo `wire.sh`.
3. Instalar em um projeto piloto e validar manualmente. Compare a soma dos prompts com o `cost-state` de uma sessão nova.
4. Escrever os testes depois da validação manual aprovada.
5. Registrar a decisão em `~/Projects/agents/.agents/decisions/` e atualizar o README.
