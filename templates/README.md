# Templates

Arquivos copiados para outros repositórios por `../adopt.sh`.

| Arquivo | Destino no projeto | Copiado por `adopt.sh` |
| --- | --- | --- |
| `AGENTS.project.md` | `AGENTS.md` (raiz) | sim |
| `PROJECT_MEMORY.md` | `.agents/PROJECT_MEMORY.md` | sim |
| `DECISION.md` | `.agents/decisions/NNN-titulo.md` | não, uso manual |

Este arquivo não é copiado para projeto nenhum.

## Espelhamento com o AGENTS.md canônico

`AGENTS.project.md` é intencionalmente autossuficiente: um agente que leia só ele, sem as preferências globais carregadas, ainda precisa se comportar corretamente. O preço disso é duplicação.

As seções abaixo espelham o `../AGENTS.md` e precisam ser atualizadas junto com ele:

| Seção do template | Origem em `../AGENTS.md` |
| --- | --- |
| Working rules (idioma, escopo, segredos, conteúdo não confiável) | Language, Way of working, Environment and safety, Untrusted content |
| Tests and validation | Tests: approval-first workflow for new features |
| Git and CI | Git, commits, push, and CI |
| Project memory | Project memory |

O texto não é idêntico por construção — o canônico fala em primeira pessoa ("me", "my"), o template fala do usuário em terceira pessoa. Comparar por conteúdo, não por diff literal.

Ao mudar uma regra em `../AGENTS.md`, verificar se ela existe aqui. Projetos já adotados não recebem a correção automaticamente: cada `AGENTS.md` de projeto é um arquivo independente a partir da adoção. O `adopt.sh` grava no fim dele o commit do template copiado (`<!-- adopted from templates/AGENTS.project.md @ <hash> -->`), e o `check.sh` avisa quando o template mudou depois desse commit. Projetos adotados antes disso não têm a marca e não são verificados.
