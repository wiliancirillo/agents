# Agents :: Diretrizes padrão para IAs e agentes

Minha base pessoal para trabalhar com assistentes de IA e agentes de código.

Aqui eu concentro três coisas:
- minhas preferências canônicas de trabalho
- templates para adotar esse padrão em outros repositórios
- material de referência para manter tudo consistente

Não é um repositório pensado como produto ou framework para comunidade.
É mais um espaço pessoal, público por transparência, que eu uso para organizar como quero que agentes trabalhem comigo e dentro dos meus projetos.

## O que tem aqui

```text
agents/
├── AGENTS.md
├── wire.sh
├── adopt.sh
├── check.sh
├── test-check.sh
├── templates/
│   ├── README.md
│   ├── AGENTS.project.md
│   ├── PROJECT_MEMORY.md
│   └── DECISION.md
└── reference/
    ├── DEVELOPMENT-GUIDELINES.md
    ├── SECURITY-AND-PRIVACY.md
    ├── AI-ECOSYSTEM-NOTES.md
    └── PROJECT-MEMORY-POLICY.md
```

## Como eu uso

### 1. Fiação global

```bash
./wire.sh
```

Esse script conecta o `AGENTS.md` canônico deste repositório aos arquivos globais lidos por ferramentas como Claude Code, Codex CLI, Gemini CLI e Hermes.

A ideia é simples: manter um único ponto de verdade para minhas preferências pessoais.

### 2. Adoção por projeto

```bash
./adopt.sh <caminho-do-projeto>
```

Esse script prepara um repositório para seguir a mesma estrutura, criando:
- `AGENTS.md` na raiz
- `CLAUDE.md` apontando para ele
- `.agents/PROJECT_MEMORY.md`
- `.agents/decisions/`

Sem sobrescrever o que já existe.

### 3. Verificação

```bash
./check.sh <caminho-do-projeto>
```

Confere um projeto adotado contra a política: estrutura no lugar, placeholders do template já preenchidos, entradas de memória dentro do limite de forma, decisões cruzadas com a memória (sem órfãs nem links quebrados), baseline de teste com data, template sem mudanças desde a adoção, e nenhuma string com cara de credencial nos arquivos de instrução.

Somente leitura — reporta, nunca edita. Sai com 1 em erro, 0 em aviso. Os limites de tamanho podem ser ajustados: `MEM_WARN=400 MEM_FAIL=1200 ./check.sh <projeto>`.

```bash
./test-check.sh
```

Cada caso monta um projeto de mentira, quebra exatamente uma coisa e exige que o `check.sh` reporte — mais um caso que não quebra nada e exige silêncio. Um check que para de ler continua imprimindo `ok`, e isso é indistinguível de um check que funciona.

Verificado em 2026-09-23, bash 5.3: `./test-check.sh` (21 casos, todos passando); `shellcheck` limpo em `wire.sh`, `adopt.sh`, `check.sh` e `test-check.sh`; `./check.sh .` passa sem avisos desde que este repositório adotou o próprio padrão. Nos projetos adotados, em 2026-08-31: `nightjar` passa (23 avisos de forma) e `astr` falha (8 entradas acima do limite, a maior com 6.339 caracteres).

## Prioridade das instruções

Quando houver conflito:
1. pedido explícito e atual do usuário
2. regras específicas do projeto
3. preferências pessoais deste repositório
4. convenções da ferramenta

## Idioma

Cada camada tem um idioma fixo:

- **Português**: este `README.md` e `reference/`. São material meu e para leitura humana.
- **Inglês**: `AGENTS.md` e `templates/`. São artefatos que vivem dentro de repositórios de código, junto com commits, identificadores e documentação técnica.

A regra que os agentes seguem é a mesma: falam comigo em português, escrevem código e artefatos técnicos em inglês.

## Escopo

Este repositório não é memória de projeto.
Ele não deve guardar credenciais, tokens, segredos, fatos temporários ou contexto específico de um único repositório.

## Futuro

Com o tempo, quero evoluir este espaço com calma:
- melhorar os templates
- refinar as regras com base no uso real
- manter decisões e memória de projeto mais organizadas
- reduzir atrito entre ferramentas diferentes

Um tijolo por vez.
