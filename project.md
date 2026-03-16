## ABORDAGEM

**Princípio central:** Construir os tijolos antes da casa, e a casa antes dos cômodos.

```
FASE 0 ─ Projeto + Managers
FASE 1 ─ 4 Componentes reutilizáveis + validação isolada
FASE 2 ─ Sala Principal / Hub de progressão
FASE 3 ─ Sala 1 (COLETE)
FASE 4 ─ Sala 2 (ORGANIZE)
FASE 5 ─ Sala 3 (SOBREVIVA) + Sala Final
FASE 6 ─ Fluxo completo + polimento + Android
```

Cada fase tem checkpoint que impede avançar sem validação.

**Change Level:** N/A (projeto novo)

## REGRAS_APLICAVEIS

| Regra | Aplicação neste projeto |
|-------|------------------------|
| KISS | Componentes fazem uma coisa. Sem abstração prematura |
| SRP | Um script = uma responsabilidade. Controller ≠ componente |
| DRY | Drag, Reveal, Hotspot escritos uma vez, usados em N salas |
| Composição sobre herança | Nós Godot = composição natural |
| Sinais para desacoplamento | Componentes emitem sinais, controllers reagem |
| Protagonista recorrente | A protagonista existe no hub e em todas as salas jogáveis, reaproveitando uma cena/script base |
| Ação por aproximação | Clique define destino; transições, coletas e minigames só disparam quando a protagonista alcança o alvo |
| Animação contextual | `walking` e `idle` são padrão; `interact` só entra nos momentos explicitamente planejados |
| YAGNI | Nada de inventário, save system, ou menu separado complexo |

## NAO_FAZER

- ❌ Criar classe base `RoomBase` (salas são diferentes demais)
- ❌ Mais de 2 Autoloads (GameManager e AudioManager bastam)
- ❌ Lógica de mecânica dentro de scripts de UI
- ❌ Hardcode de paths de cena (usar constantes em GameManager)
- ❌ Polling em `_process` para detecção de click (usar `_input_event` de Area2D)
- ❌ Criar sistemas que só servem uma sala (inline no controller)
- ❌ Disparar troca de sala, coleta ou minigame antes da protagonista alcançar o alvo
- ❌ Usar `interact` como resposta padrão para todo clique ou toda troca de estado
- ❌ Limitar a protagonista com colisão de cenário; os limites de movimento devem vir de margens configuráveis por fase
- ❌ Assets finais antes da mecânica funcionar com placeholders

## PREMISSA_GLOBAL_DA_PROTAGONISTA

- A protagonista aparece na sala principal e em todas as salas jogáveis.
- Clique/toque sempre define um destino para a protagonista dentro das margens da fase.
- Ações contextuais de sala só são executadas quando ela alcança o alvo associado.
- A animação padrão da movimentação é `walking`; parada é `idle`; `interact` fica reservada para beats específicos definidos depois.
- Cada fase define suas margens de navegação (`top`, `bottom`, `left`, `right`) em vez de usar colisão de cenário para travar movimento.

---

## FASES

### FASE 0: Projeto, Config e Managers
**Objetivo:** Projeto funcional com infraestrutura mínima rodando
**Subsistemas cobertos:** Estrutura, GameManager, AudioManager, config Android

#### Tarefa 0.1: Estrutura de Projeto
- **Descricao:** Criar organização de pastas e project.godot configurado
- **Diretorio:** /
- **Micro-Tasks:**
  - [x] MT-0.1.1: Criar projeto Godot 4 com pastas: `scenes/rooms/`, `scenes/ui/`, `scripts/core/`, `scripts/components/`, `scripts/rooms/`, `assets/sprites/`, `assets/audio/`, `assets/fonts/`
  - [X] MT-0.1.2: Configurar `project.godot`: viewport 540x960, stretch mode `canvas_items`, stretch aspect `keep`, orientation portrait
  - [X] MT-0.1.3: Criar `.gitignore` para Godot 4 e commitar estrutura vazia
- **Criterios de Aceitacao:**
  1. Projeto abre no editor sem erros
  2. Preview mostra proporção 9:16 vertical
- **Classificacao:** Confirmado

#### Tarefa 0.2: GameManager
- **Descricao:** Autoload que controla estado do jogo, progressão e transições de cena
- **Diretorio:** /scripts/core/
- **Micro-Tasks:**
  - [X] MT-0.2.1: Criar `game_manager.gd` com `enum State {PLAYING, TRANSITIONING}`, var `current_room: int = 0`, dict `rooms_completed: Dictionary = {}`
  - [X] MT-0.2.2: Criar constante `ROOM_SCENES: Dictionary = {1: "res://scenes/rooms/room_1.tscn", ...}` mapeando id→path
  - [X] MT-0.2.3: Implementar sinais: `room_completed(room_id: int)`, `transition_started`, `transition_finished`
  - [X] MT-0.2.4: Criar `CanvasLayer` filho com `ColorRect` fullscreen preto (para fades), z_index=100
  - [X] MT-0.2.5: Implementar `func transition_to_room(room_id: int)`: valida id, seta state TRANSITIONING, fade to black via Tween no ColorRect, `get_tree().change_scene_to_file()`, fade from black, seta PLAYING
  - [X] MT-0.2.6: Implementar `func complete_room(room_id: int)`: marca dict, emite sinal e centraliza a progressão pós-sala
  - [X] MT-0.2.7: Registrar como Autoload "GameManager" em Project Settings
  - [X] MT-0.2.8: Criar `scripts/core/game_manager_test.gd`, `scenes/ui/test_game_manager_transition.tscn` e `scenes/rooms/room_1.tscn` placeholder mínima. A cena de teste chama `GameManager.transition_to_room(1)` em `_ready` e valida o fade. `room_1.tscn` será expandida em `MT-3.1.1`
  - [X] MT-0.2.9: Refatorar fluxo do `GameManager` para a Sala Principal: adicionar `MAIN_MENU_SCENE_PATH`, `func return_to_hub()`, `func get_next_room_to_unlock() -> int`, `func can_enter_room(room_id: int) -> bool`. Atualizar `complete_room()` para voltar à sala principal quando `room_id < 4` e só ir para `final_screen` ao concluir a sala final
- **Criterios de Aceitacao:**
  1. `GameManager` acessível globalmente
  2. Fade to/from black funciona
  3. Troca de cena via `transition_to_room` funcional
  4. Não permite transição durante outra transição
- **Classificacao:** Confirmado

#### Tarefa 0.3: AudioManager
- **Descricao:** Autoload para BGM com crossfade e SFX one-shot
- **Diretorio:** /scripts/core/
- **Micro-Tasks:**
  - [X] MT-0.3.1: Criar `audio_manager.gd` com 2 filhos `AudioStreamPlayer`: `bgm_player` e `sfx_player`
  - [X] MT-0.3.2: Criar dict `TRACKS: Dictionary = {"main": preload("res://assets/audio/end_of_beginning.ogg"), "finale": preload("res://assets/audio/goo_goo_dolls.ogg")}` — com placeholders se áudio ainda não existe
  - [X] MT-0.3.3: Implementar `func play_bgm(track_key: String)`: se já tocando mesma track ignora; se outra, crossfade (Tween volume down old → swap stream → Tween volume up)
  - [X] MT-0.3.4: Implementar `func play_sfx(sfx: AudioStream)`: seta stream no sfx_player e toca (fire-and-forget)
  - [X] MT-0.3.5: Implementar `func stop_bgm(fade_duration: float = 0.5)` com fade out
  - [X] MT-0.3.6: Registrar como Autoload "AudioManager"
- **Criterios de Aceitacao:**
  1. BGM toca em loop
  2. Crossfade funciona sem corte
  3. SFX não interrompe BGM
  4. Chamar `play_bgm` com mesma track não reinicia
- **Classificacao:** Confirmado

**Checkpoint FASE 0:** Projeto abre, Autoloads carregam, fade funciona entre duas cenas de teste vazias, áudio placeholder toca.

---

### FASE 1: Componentes Reutilizáveis
**Objetivo:** Construir os 4 tijolos que compõem todas as salas, testados isoladamente
**Subsistemas cobertos:** Hotspot, Draggable, Revealer, EventChain

#### Tarefa 1.1: Hotspot (Área clicável)
- **Descricao:** Nó Area2D que detecta click/touch e emite sinal. Usado em Sala 1 (flores), Sala 2 (louça), Sala 3 (bebê)
- **Diretorio:** /scripts/components/
- **Micro-Tasks:**
  - [X] MT-1.1.1: Criar `hotspot.gd` extends `Area2D` com exports: `hotspot_id: String`, `one_shot: bool = true`, `active: bool = true`
  - [X] MT-1.1.2: Sinal `pressed(hotspot_id: String)`. Em `_input_event`, detectar `InputEventMouseButton` (button_index LEFT, pressed) OU `InputEventScreenTouch` (pressed). Se `active`, emitir sinal. Se `one_shot`, setar `active = false`
  - [X] MT-1.1.3: Adicionar feedback: quando mouse/touch entra na área, modulate do parent levemente (1.1, 1.1, 1.1) para indicar interatividade. Resetar ao sair
  - [X] MT-1.1.4: Criar cena de teste `test_hotspot.tscn` com 3 Hotspots + Label que mostra qual foi clicado. Validar touch e mouse
- **Criterios de Aceitacao:**
  1. Emite `pressed` exatamente uma vez se `one_shot`
  2. Não emite se `active = false`
  3. Funciona com mouse E touch
  4. Feedback visual sutil ao hover/touch
- **Classificacao:** Confirmado

#### Tarefa 1.2: Draggable (Objeto arrastável)
- **Descricao:** Nó que pode ser arrastado pelo jogador e detecta drop em zonas alvo. Usado em Sala 2 (vassoura, roupa) e na Sala Final (puzzle)
- **Diretorio:** /scripts/components/
- **Micro-Tasks:**
  - [X] MT-1.2.1: Criar `draggable.gd` extends `Area2D` com exports: `drag_id: String`, `snap_back: bool = true`, `snap_distance: float = 40.0`, `active: bool = true`
  - [X] MT-1.2.2: Guardar `_origin_position: Vector2` no `_ready`. Implementar estado interno `_dragging: bool`. Em `_input_event`, detectar press → `_dragging = true`. Em `_input(event)`, se `_dragging`: atualizar `global_position` para posição do touch/mouse. Detectar release → `_dragging = false`, chamar `_on_dropped()`
  - [X] MT-1.2.3: Sinais: `drag_started(drag_id)`, `drag_ended(drag_id)`, `dropped_on_target(drag_id, target_area)`. Em `_on_dropped()`: checar overlapping areas. Se alguma pertence ao grupo "drop_target" e distância < `snap_distance`, snap para posição do target e emitir `dropped_on_target`. Senão, se `snap_back`, Tween de volta para `_origin_position`
  - [X] MT-1.2.4: Criar `drop_zone.gd` extends `Area2D` — script mínimo que só adiciona ao grupo "drop_target" no `_ready` e tem export `zone_id: String`
  - [X] MT-1.2.5: Criar cena de teste `test_drag.tscn` com 2 Draggables e 2 DropZones. Validar snap, snap_back, sinais
- **Criterios de Aceitacao:**
  1. Arrasto suave seguindo dedo/mouse
  2. Snap para target quando solto próximo
  3. Volta à origem quando solto fora
  4. Funciona em touch (prioridade) e mouse
  5. Não permite arrastar dois objetos simultaneamente
- **Classificacao:** Confirmado

#### Tarefa 1.3: Revealer (Transição visual escuro → cor)
- **Descricao:** Script que anima a revelação visual de um nó (modulate cinza → branco). Usado em TODAS as salas
- **Diretorio:** /scripts/components/
- **Micro-Tasks:**
  - [x] MT-1.3.1: Criar `revealer.gd` extends `Node` (attachable a qualquer nó visual). Exports: `reveal_duration: float = 0.6`, `hidden_color: Color = Color(0.15, 0.15, 0.15, 1.0)`, `revealed_color: Color = Color.WHITE`, `start_hidden: bool = true`
  - [X] MT-1.3.2: No `_ready`, se `start_hidden`, setar `get_parent().modulate = hidden_color`. Sinal `revealed`. Implementar `func reveal()`: cria Tween, interpola `get_parent().modulate` de atual para `revealed_color` em `reveal_duration`, ao final emite `revealed`
  - [X] MT-1.3.3: Implementar `func hide_visual()` (reverso, para reset) e `func reveal_instant()` (sem animação, para debug/testes)
  - [X] MT-1.3.4: Criar cena de teste com 4 sprites coloridos, cada um com Revealer filho, e botão que chama `reveal()` em cada um sequencialmente
- **Criterios de Aceitacao:**
  1. Sprite começa escuro/cinza
  2. `reveal()` anima suavemente para cor original
  3. Sinal emitido ao completar
  4. Múltiplas chamadas a `reveal()` não quebram (idempotente: ignora se já revelado)
- **Classificacao:** Confirmado

#### Tarefa 1.4: EventChain (Sequência cinematográfica)
- **Descricao:** Sistema para orquestrar série de eventos com delays. Usado no finale de TODAS as salas (som → animação → spawn → fade → etc)
- **Diretorio:** /scripts/components/
- **Micro-Tasks:**
  - [X] MT-1.4.1: Criar `event_chain.gd` extends `Node`. Define classe interna ou dict para steps. Cada step: `{callable: Callable, delay_after: float}`. Array `_steps: Array[Dictionary] = []`
  - [X] MT-1.4.2: Implementar `func add_step(what: Callable, delay_after: float = 0.5) -> EventChain` (retorna self para chaining). Implementar `func clear()`
  - [X] MT-1.4.3: Implementar `func play()`: itera `_steps`, para cada um chama `callable.call()`, depois `await get_tree().create_timer(delay_after).timeout`. Sinal `chain_completed` ao final. Var `_playing: bool` para evitar dupla execução
  - [X] MT-1.4.4: Criar cena de teste com 4 Labels que aparecem em sequência com 0.5s entre cada, usando EventChain para orquestrar
- **Criterios de Aceitacao:**
  1. Steps executam na ordem com delays corretos
  2. `chain_completed` emitido ao final
  3. Chamar `play()` durante execução é ignorado
  4. Funções arbitrárias podem ser steps (Callable genérico)
- **Classificacao:** Confirmado

#### Tarefa 1.5: Protagonista Reutilizável
- **Descricao:** Cena e script base da protagonista para clique-to-move com margens por fase e gatilho de chegada
- **Diretorio:** /scenes/components/ e /scripts/components/
- **Observacao de continuidade:** `protagonist.tscn` ja existe no workspace. O hub ainda usa uma protagonista provisoria hardcoded em `main_menu.tscn` + `main_menu_controller.gd`. Os proximos MTs desta tarefa e os MTs `2.1.6` + `2.2.6` devem convergir o projeto para uma unica protagonista reutilizavel
- **Micro-Tasks:**
  - [x] MT-1.5.1: Criar `protagonist.tscn` como cena reutilizável da protagonista. Root `Node2D`, visual placeholder e suporte às animações `idle`, `walking`, `interact`
  - [X] MT-1.5.2: Criar `protagonist_actor.gd` com API de movimento por clique/toque. Exports mínimos: `move_speed`, `arrival_threshold`, `margin_top`, `margin_bottom`, `margin_left`, `margin_right`
  - [X] MT-1.5.3: Implementar sinal de chegada (`destination_reached` ou equivalente) para que controllers disparem ações somente após a protagonista alcançar o alvo. O destino deve ser clampado pelas margens da fase
  - [X] MT-1.5.4: Criar cena de teste dedicada validando `idle`, `walking`, clamp por margens e a regra de não usar `interact` por padrão
- **Criterios de Aceitacao:**
  1. A protagonista responde a mouse e touch
  2. O movimento respeita margens configuráveis da fase
  3. Controllers conseguem esperar a chegada antes de executar uma ação
  4. `interact` não é disparada automaticamente em toda ação contextual
- **Classificacao:** Confirmado

**Checkpoint FASE 1:** 4 componentes funcionam isoladamente em cenas de teste. Hotspot responde a touch, Draggable faz snap, Revealer anima cor, EventChain orquestra sequência, e a Tarefa 1.5 fecha a base reutilizável da protagonista antes da integração no hub e nas salas.

---

### FASE 2: Sala Principal — Hub/Menu
**Objetivo:** Criar a sala principal antes das salas jogáveis. Ela funciona como menu diegético, gate de progressão e primeira integração real da protagonista
**Subsistemas cobertos:** GameManager + Hotspot + GPUParticles2D + protagonista + fluxo de navegação

#### Tarefa 2.1: Layout da Sala Principal
- **Descricao:** Montar a sala central com 4 saídas cardeais, uma para cada sala do jogo, já prevendo a circulação da protagonista
- **Diretorio:** /scenes/ui/ ou /scenes/rooms/
- **Micro-Tasks:**
  - [X] MT-2.1.1: Criar `main_menu.tscn` como a sala principal. Root `Node2D`. Adicionar fundo/placeholder da sala central
  - [X] MT-2.1.2: Posicionar 4 portas/corredores com leitura espacial fixa: direita = Sala 1 COLETE, baixo = Sala 2 ORGANIZE, esquerda = Sala 3 SOBREVIVA, cima = Sala Final
  - [X] MT-2.1.3: Adicionar `Hotspot` ou `Area2D + CollisionShape2D` para cada porta com ids `door_1`, `door_2`, `door_3`, `door_4`
  - [X] MT-2.1.4: Adicionar partículas de névoa (`GPUParticles2D`) nas portas bloqueadas. Estado inicial: só a porta da direita fica livre; baixo, esquerda e cima começam bloqueadas com névoa
  - [X] MT-2.1.5: Adicionar feedback visual para portas concluídas/passadas (apagada, fechada ou sem destaque), deixando claro que não podem ser reentradas
  - [X] MT-2.1.6: Instanciar `protagonist.tscn` no hub com posição inicial, ordem de render e margens de navegação da sala principal, substituindo o node provisório `CanvasLayer/Protagonist` de `main_menu.tscn`. Não manter duas protagonistas em paralelo
- **Criterios de Aceitacao:**
  1. Cena renderiza em 540x960 sem cortes
  2. A leitura espacial das portas é clara
  3. Só a porta da direita está acessível no início
  4. Toda porta bloqueada exibe névoa visível
  5. A protagonista existe visualmente na sala principal e consegue circular sem depender de colisão de cenário
- **Classificacao:** Confirmado

#### Tarefa 2.2: Controller da Sala Principal
- **Descricao:** Script que lê o progresso salvo no `GameManager`, liga/desliga as portas corretamente e orquestra o movimento da protagonista no hub
- **Diretorio:** /scripts/rooms/
- **Observacao de continuidade:** no estado atual do workspace, `main_menu_controller.gd` concentra lógica provisória de movimento/animação da protagonista do hub. Ao executar `MT-1.5.2`, `MT-1.5.3`, `MT-2.1.6` e `MT-2.2.6`, migrar o hub para usar `protagonist.tscn` + `protagonist_actor.gd`, removendo a duplicação do controller
- **Micro-Tasks:**
  - [X] MT-2.2.1: Criar `main_menu_controller.gd` extends `Node2D`. `@onready` refs para as 4 portas, os 4 emissores de névoa e a protagonista
  - [X] MT-2.2.2: Implementar `_refresh_doors_state()` usando `GameManager.rooms_completed` e `GameManager.get_next_room_to_unlock()`
  - [X] MT-2.2.3: Regra da sala principal: só a próxima sala da sequência pode ser acessada. Salas futuras ficam bloqueadas com névoa. Salas já concluídas ficam inacessíveis e sem reentrada
  - [X] MT-2.2.4: Conectar clique/toque da porta liberada para uma ação contextual de navegação. O controller deve mandar a protagonista caminhar até a porta clicada e só então chamar `GameManager.transition_to_room(target_room_id)`. Clique em porta bloqueada ou já concluída não faz transição
  - [X] MT-2.2.5: Opcional: feedback sutil em porta bloqueada (som abafado, tremida leve ou flash de névoa), sem quebrar a regra de progressão
  - [X] MT-2.2.6: Implementar clique/toque global no chão do hub para mover a protagonista livremente sem trocar de sala. Se o clique for numa porta liberada, a troca de cena continua pendente até a protagonista chegar. Nesta etapa, remover o uso automático de `interact` no hub; o fluxo padrão deve ser `walking -> idle -> troca de cena`
- **Criterios de Aceitacao:**
  1. Início do jogo: apenas Sala 1 disponível
  2. Após concluir Sala 1: Sala 1 não pode mais ser aberta e Sala 2 é desbloqueada
  3. Após concluir Sala 2: Sala 3 é desbloqueada
  4. Após concluir Sala 3: a porta de cima (Sala Final) é desbloqueada
  5. Não existe caminho para entrar em sala futura nem para repetir sala concluída
  6. A troca de sala no hub nunca é instantânea: ela só acontece depois que a protagonista alcança a porta
- **Classificacao:** Confirmado

#### Tarefa 2.3: Integração de Progressão
- **Descricao:** Ajustar o fluxo global para que toda conclusão volte para a sala principal antes da próxima porta abrir
- **Diretorio:** /scripts/core/ e /scenes/ui/
- **Micro-Tasks:**
  - [X] MT-2.3.1: Executar a refatoração descrita em `MT-0.2.9` no `GameManager`
  - [X] MT-2.3.2: Fazer `GameManager.complete_room(1..3)` retornar para `main_menu.tscn` após marcar a sala como concluída
  - [X] MT-2.3.3: Manter `GameManager.complete_room(4)` levando para `final_screen.tscn`
  - [x] MT-2.3.4: Criar ou adaptar cena de teste para validar o loop `hub -> sala -> hub`
- **Criterios de Aceitacao:**
  1. O fluxo real do jogo passa sempre pela sala principal entre as salas
  2. A progressão respeita a ordem direita → baixo → esquerda → cima
  3. O estado visual das portas acompanha corretamente `rooms_completed`
- **Classificacao:** Confirmado

**Checkpoint FASE 2:** Sala principal funcional como hub. Progressão e bloqueios estão corretos. Antes de considerar a integração da protagonista do hub encerrada, substituir a implementação provisória por `protagonist.tscn` + `protagonist_actor.gd` e fechar `MT-2.1.6` + `MT-2.2.6`.

---

### FASE 3: Sala 1 — COLETE
**Objetivo:** Primeira sala jogável completa, validando protagonista + Hotspot + Revealer + EventChain em contexto real
**Subsistemas cobertos:** Protagonista + Hotspot + Revealer + EventChain + GameManager

#### Tarefa 3.1: Layout da Cena
- **Descricao:** Montar o jardim com uma arte base única, 4 layers fullscreen de flores recortadas e pontos de ação para a protagonista
- **Diretorio:** /scenes/rooms/
- **Micro-Tasks:**
  - [X] MT-3.1.1: Expandir/substituir o placeholder de `room_1.tscn` com `Node2D` root. Adicionar fundo base do jardim em `TextureRect` fullscreen, no mesmo padrão visual prático adotado no hub
  - [X] MT-3.1.2: Adicionar 4 `TextureRect` fullscreen para as layers de flores (rosa, hibisco, lírio, girassol), cada uma recortada da arte base com o mesmo tamanho do background e transparência fora da região da flor. Cada layer recebe um filho `Revealer` com `start_hidden = true`, usando `modulate` para revelar apenas a flor correspondente
  - [X] MT-3.1.3: Adicionar a protagonista na sala, uma flor-origem central em fila (hibisco -> rosas vermelhas -> lirios -> girassois), com cada flor aparecendo sob demanda no centro. `Presente` comeca invisivel e `Furao` comeca oculto. Nao criar `bolo` separado: o payoff central usa o `Center` e o `Background` ja preparado
  - [X] MT-3.1.4: Adicionar 4 `Hotspot` (Area2D + CollisionShape2D) alinhados exatamente as mascaras das flores recortadas e 4 `Marker2D`/pontos de aproximacao para a protagonista. Configurar `hotspot_id` como "rosa", "hibisco", "lirio", "girassol", `one_shot = true` e deixar somente o hotspot inicial habilitado; os demais ficam sob demanda
  - [X] MT-3.1.5: Em vez de overlay escuro, adicionar 4 highlights sutis de destino, um por flor, invisiveis no inicio e usados somente quando a flor correspondente estiver em transito/na mao da protagonista
- **Criterios de Aceitacao:**
  1. Cena renderiza em 540x960 sem cortes
  2. Flores centrais e `Presente` comecam ocultos; `Furao` comeca oculto; os destinos usam highlights sutis sob demanda
  3. Fundo e 4 layers de flores permanecem alinhados pixel a pixel
  4. 4 hotspots posicionados e com collision shapes
- **Classificacao:** Confirmado

#### Tarefa 3.2: Controller da Sala 1
- **Descricao:** Script que conecta hotspots, protagonista e revealers, orquestrando a lógica de restaurar as flores
- **Diretorio:** /scripts/rooms/
- **Micro-Tasks:**
  - [X] MT-3.2.1: Criar `room_1_controller.gd` extends `Node2D` (root da cena). `@onready` refs para os 4 Hotspots, 4 layers de flores com Revealer, fila central de flores (`FlowerOrigin` + 4 sprites), 4 `ApproachMarker`, 4 destination hints sutis, protagonista, `Center`, `Presente` e `Furao`. Vars minimas: `_flowers_restored: int = 0`, `_current_flower_index: int = 0`
  - [X] MT-3.2.2: No `_ready`, mostrar somente a primeira flor da fila central e habilitar apenas o hotspot correspondente. Ao clicar no hotspot ativo, o controller deve: (1) mostrar o hint sutil do destino correspondente, (2) mandar a protagonista ir primeiro ate a flor central atual, (3) depois ate o `ApproachMarker` do alvo, (4) ao chegar, esconder a flor central atual, desligar o hint, revelar a layer correspondente, tocar SFX via `AudioManager.play_sfx(...)`, incrementar `_flowers_restored` e habilitar/mostrar a proxima flor da fila. Se `_flowers_restored == 4`, chamar `_start_finale()`
  - [X] MT-3.2.3: Implementar `_start_finale()` usando `EventChain`: criar instancia (ou no ja na cena), popular com steps: (1) tocar som suave, (2) rodar `Background` na animacao `surprise` (`GardenSurprise`), (3) ocultar `Center` para expor o payoff central do fundo, (4) fazer `Presente` aparecer com fade no ponto mais baixo configurado, (5) setar `Furao.visible = true` com scale de 0→1, (6) chamar `GameManager.complete_room(1)`. Conectar `chain_completed` se necessario
  - [X] MT-3.2.4: Testar fluxo completo: primeira flor aparece no centro → hotspot correspondente eh o unico ativo → protagonista vai ao centro → protagonista leva a flor ao alvo com hint sutil ativo → reveal da camada correta → proxima flor aparece → apos 4/4 toca `GardenSurprise`, `Center` some, `Presente` faz fade in e retorna para a sala principal
- **Criterios de Aceitacao:**
  1. Cada hotspot revela somente a layer da flor correspondente e so fica ativo no seu turno
  2. Cada restauracao so acontece depois que a protagonista completa o trajeto centro -> alvo
  3. A proxima flor so aparece depois que a anterior for entregue corretamente
  4. A sequencia final executa `GardenSurprise`, oculta `Center`, faz `Presente` aparecer com fade e revela `Furao`
  5. Ao final, `GameManager` retorna para a Sala Principal liberando a Sala 2
  6. Hotspots concluidos permanecem desativados apos uso (`one_shot`)
- **Classificacao:** Confirmado

**Checkpoint FASE 3:** Sala 1 jogavel do inicio ao fim. A fila central de flores funciona em ordem, os hotspots/hints acompanham a flor ativa, `GardenSurprise` roda ao concluir 4/4, `Center` some no payoff, `Presente` entra com fade, `Furao` aparece e o retorno ao hub funciona.

---

### FASE 4: Sala 2 — ORGANIZE
**Objetivo:** Implementar uma Sala 2 simplificada usando os assets já prontos, substituindo 3 minigames separados por 3 interações rápidas integradas à própria cena
**Subsistemas cobertos:** Protagonista + Hotspot + Draggable + DropZone + Revealer + EventChain + AnimatedSprite2D

#### Tarefa 4.1: Cena Base e Controller da Sala 2
- **Descricao:** Montar a casa bagunçada usando `Room2BackGround.png`, `Room2Masc.png` e `Room2Objects.png`, com um controller único que orquestra as 3 tarefas de organização e o gating por aproximação da protagonista
- **Diretorio:** /scenes/rooms/ e /scripts/rooms/
- **Micro-Tasks:**
  - [X] MT-4.1.1: Criar `room_2.tscn` com root `Node2D`, protagonista, fundo limpo usando `res://assets/sprites/Room2BackGround.png`, overlay de sujeira usando `res://assets/sprites/Room2Masc.png`, layers/recortes de `res://assets/sprites/Room2Objects.png` para os estados antes/depois de louça, roupa e cadeira, 3 zonas clicáveis (`dishes`, `clothes`, `sweep`) e 3 `Marker2D` de aproximação
  - [X] MT-4.1.2: Criar `room_2_controller.gd` com `var _tasks_done: Dictionary = {"dishes": false, "clothes": false, "sweep": false}` e `var _active_task: String = ""`. Ao clicar numa zona livre, a protagonista vai até o marker correspondente e só então a tarefa daquela zona é habilitada
  - [X] MT-4.1.3: Implementar no controller a trava de tarefa ativa, a conclusão de cada tarefa, a troca visual "sujo -> limpo" via `Room2Objects.png`, e o gatilho `_start_transformation()` quando `dishes`, `clothes` e `sweep` estiverem concluídas
- **Criterios de Aceitacao:**
  1. Cena renderiza corretamente com os assets finais da Room 2
  2. Controller rastreia o progresso das 3 tarefas
  3. As tarefas podem ser feitas em qualquer ordem
  4. Nenhuma tarefa abre instantaneamente no clique; sempre espera a chegada da protagonista
  5. Só existe uma tarefa ativa por vez
- **Classificacao:** Confirmado (correção de escopo)

#### Tarefa 4.2: Interação Louça
- **Descricao:** Limpeza curta da louça integrada à própria cena, sem minigame separado, usando os itens já prontos em `Room2Items.png`
- **Diretorio:** /scenes/rooms/ e /scripts/rooms/
- **Micro-Tasks:**
  - [X] MT-4.2.1: Após a protagonista alcançar a zona da pia, habilitar a interação de louça usando `res://assets/sprites/Room2Items.png`: prato, overlay de sujeira e esponja. A limpeza deve remover a sujeira do prato sem criar cena ou script exclusivo em `/scripts/rooms/room_2/`
  - [X] MT-4.2.2: Ao concluir a interação, atualizar o estado visual de "louça suja" para "louça" em `Room2Objects.png`, marcar `_tasks_done["dishes"] = true` e impedir repetição
- **Criterios de Aceitacao:**
  1. A louça só pode ser limpa depois da aproximação da protagonista
  2. A interação usa apenas os assets já prontos da Room 2
  3. Ao concluir, o estado visual da pia muda de sujo para limpo
- **Classificacao:** Confirmado (correção de escopo)

#### Tarefa 4.3: Interação Roupa
- **Descricao:** Organização rápida de roupas integrada à cena, reaproveitando `Draggable` e `DropZone` em vez de um minigame dedicado
- **Diretorio:** /scenes/rooms/ e /scripts/rooms/
- **Micro-Tasks:**
  - [X] MT-4.3.1: Após a protagonista alcançar a zona de roupa, instanciar/ativar 3 roupas a partir de `res://assets/sprites/Room2Items.png` como `Draggable` e 1 cesto como `DropZone`, sem criar script exclusivo de minigame
  - [X] MT-4.3.2: Conectar os drops bem-sucedidos no `room_2_controller.gd`; quando 3/3 roupas entrarem no cesto, atualizar o estado visual de "roupa suja" para "roupa" em `Room2Objects.png`, marcar `_tasks_done["clothes"] = true` e impedir repetição
- **Criterios de Aceitacao:**
  1. A roupa só pode ser organizada depois da aproximação da protagonista
  2. As roupas usam `Draggable`/`DropZone` existentes
  3. Ao concluir, o estado visual muda de roupa suja para roupa organizada
  4. Soltar fora do cesto continua respeitando o snap back do componente reutilizável
- **Classificacao:** Confirmado (correção de escopo)

#### Tarefa 4.4: Interação Vassoura
- **Descricao:** Limpeza contínua dos 4 cantos sujos usando a máscara pronta da Room 2, sem construir um terceiro minigame dedicado
- **Diretorio:** /scenes/rooms/ e /scripts/rooms/
- **Micro-Tasks:**
  - [X] MT-4.4.1: Após a protagonista alcançar a zona de varrer, ativar a vassoura de `res://assets/sprites/Room2Items.png` e usar `res://assets/sprites/Room2Masc.png` como sujeira dos 4 cantos, reduzindo a máscara conforme a limpeza
  - [X] MT-4.4.2: Quando os 4 cantos estiverem limpos, ocultar a máscara de sujeira, atualizar a cadeira para a versão organizada em `Room2Objects.png`, marcar `_tasks_done["sweep"] = true` e impedir repetição
- **Criterios de Aceitacao:**
  1. A vassoura só é ativada depois da aproximação da protagonista
  2. A sujeira dos 4 cantos é removida usando `Room2Masc.png`
  3. Ao concluir, a cadeira muda para o estado organizado
- **Classificacao:** Confirmado (correção de escopo)

#### Tarefa 4.5: Transformação Final da Sala 2
- **Descricao:** Depois das 3 tarefas concluídas, tocar a animação pronta de transformação e entrar no loop final antes de retornar ao hub
- **Diretorio:** /scenes/rooms/ e /scripts/rooms/
- **Micro-Tasks:**
  - [X] MT-4.5.1: Preparar na cena a animação única de transformação com `res://assets/sprites/Room2Transition1024x1536_7C3L.png` em `AnimatedSprite2D` ou estrutura equivalente, configurada como spritesheet 7 colunas x 3 linhas e executada uma única vez quando `_start_transformation()` for chamado
  - [X] MT-4.5.2: Ao terminar a transição, trocar para o loop `res://assets/sprites/Room2Loop1024x1536_11C2L_S01.png` (11 colunas x 2 linhas), manter o estado final organizado visível por um breve beat emocional e então chamar `GameManager.complete_room(2)`
- **Criterios de Aceitacao:**
  1. A transição usa os assets finais já produzidos para a Room 2
  2. O loop final entra automaticamente após a animação única
  3. Ao final, retorno ao hub desbloqueando a Sala 3
- **Classificacao:** Confirmado (correção de escopo)

**Checkpoint FASE 4:** Sala 2 jogável com 3 tarefas rápidas integradas à mesma cena, todas iniciadas por aproximação da protagonista, usando os assets finais da Room 2, e a transição animada executa completamente antes de liberar a próxima porta no hub.

---

### FASE 5: Sala 3 — SOBREVIVA + Sala Final
**Objetivo:** Implementar a sala de tensão, retornar ao hub, e concluir com a última sala e a cena final, sempre usando a protagonista como agente das ações
**Subsistemas cobertos:** Protagonista + BulletHell + BabyInteraction (Hotspot reutilizado) + Puzzle + Finale

#### Tarefa 5.1: Sala 3 Parte 1 — Bullet Hell
- **Descricao:** Mecânica de desvio de projéteis médicos por tempo limitado. A protagonista é quem sofre as colisões e sobrevive ao bullet hell
- **Diretorio:** /scripts/rooms/room_3/ e /scenes/rooms/
- **Micro-Tasks:**
  - [X] MT-5.1.1: Criar `room_3.tscn` com fundo hospitalar escuro. Instanciar a protagonista como avatar controlado da fase e criar `Timer` de sobrevivência (15s, export var para ajuste)
  - [X] MT-5.1.2: Criar `player_dodge.gd` como script especializado da protagonista no bullet hell: segue touch/mouse, clampa posição dentro das margens da fase e emite sinal `hit` ao detectar overlap com grupo "projectile"
  - [X] MT-5.1.3: Criar `projectile.tscn`: `Area2D` no grupo "projectile" com sprite (seringa/placeholder), script `projectile.gd` com export `speed: float` e `direction: Vector2`. Move em `_process`. Se sair da tela (`VisibleOnScreenNotifier2D`), `queue_free()`
  - [x] MT-5.1.4: Criar `bullet_spawner.gd`: Timer de spawn (0.4s-0.8s). Instancia `projectile.tscn` em posições aleatórias nas bordas com direção para dentro. Export `spawn_rate_range: Vector2` para variação
  - [X] MT-5.1.5: No controller `room_3_controller.gd`: ao script da protagonista emitir `hit`, flash vermelho (Tween modulate) + breve invencibilidade (0.5s). NÃO é game over. Quando timer de sobrevivência acaba, spawner para, projéteis restantes fazem fade out e chama `_transition_to_nursery()`
- **Criterios de Aceitacao:**
  1. Player segue dedo responsivamente
  2. Projéteis vêm de bordas variadas
  3. Hit = feedback visual, NÃO morte
  4. Após 15s (configurável), fase termina automaticamente
  5. Sem memory leak de projéteis
- **Classificacao:** Confirmado

#### Tarefa 5.2: Sala 3 Parte 2 — Quarto do Ravi
- **Descricao:** Transição emocional para interação suave com o bebê. A interação só começa quando a protagonista alcança o Ravi
- **Diretorio:** /scripts/rooms/room_3/
- **Micro-Tasks:**
  - [X] MT-5.2.1: Implementar `_transition_to_nursery()` usando EventChain: (1) fade out elementos hospitalares, (2) trocar fundo para quarto do bebê, (3) mudar tom musical (AudioManager — mesma track mas volume ajustado ou track alternativa mais calma), (4) revelar sprite do Ravi no centro
  - [X] MT-5.2.2: Criar `baby_interaction.gd`: clique/toque no Ravi primeiro move a protagonista até o bebê. Só quando ela chega a interação fica ativa. Cada `pressed` válido gera `Sprite2D` de coração na posição do toque com Tween (sobe + fade out em 1s, depois `queue_free`), toca SFX fofo (varia entre 2-3 sons aleatórios) e incrementa `_touch_count: int`. Após 5+ toques, mostrar botão/indicador sutil de "→" (próxima)
  - [X] MT-5.2.3: Botão de próximo chama `GameManager.complete_room(3)`. Garantir que não aparece antes de 5 toques para que jogador interaja minimamente
- **Criterios de Aceitacao:**
  1. Contraste emocional brutal: tensão → paz
  2. Corações sobem e somem suavemente
  3. Sons fofos não repetitivos (rodar entre variações)
  4. Saída disponível após interação mínima mas sem pressa
  5. Ao concluir, retorno ao hub desbloqueando a porta de cima
- **Classificacao:** Confirmado (mecânica de saída: Assuncao — botão após 5 toques)

#### Tarefa 5.3: Sala Final — Puzzle do Coração
- **Descricao:** Última sala do hub. A protagonista coleta as peças espalhadas, leva o coração ao centro e só então o minigame de montagem é aberto
- **Diretorio:** /scripts/rooms/room_4/ e /scenes/rooms/
- **Micro-Tasks:**
  - [X] MT-5.3.1: Criar `room_4.tscn` com fundo escuro, protagonista, sprite do garoto chorando no centro-baixo e a área central onde o coração será montado. Posicionar 5-7 peças do coração proceduralmente espalhadas pelo cenário como alvos de coleta
  - [X] MT-5.3.2: Implementar a etapa de coleta: ao clicar numa peça, a protagonista vai até ela, coleta a peça e atualiza o progresso. Depois que todas forem coletadas, clicar/acionar a área central faz a protagonista levar o coração procedural ao centro 
  - [X] MT-5.3.3: Criar `room_4_controller.gd`: rastrear `_pieces_collected: int`, reagir à coleta de peças e, quando todas tiverem sido recolhidas, abrir o minigame de montagem apenas quando a protagonista alcançar a área central, o minigame tem o coração preto no fundo mostrando o molde, e as peças procedural pra arrastar e preencher. 
  - [X] MT-5.3.4: Dentro do minigame de montagem, usar `DropZone` com `accepted_id` para que cada peça encaixe apenas no slot correto (procedural). Se `accepted_id != ""` e `drag_id` não corresponde, rejeitar o drop (snap back), se for difícil implementar, pode ser apenas esferas brilhantes que arrastando vai enchendo sem tanta rigidez.
- **Criterios de Aceitacao:**
  1. A protagonista precisa realmente se mover até as peças para coletá-las
  2. O minigame de montagem só abre depois que a protagonista chega ao centro com o coração
  3. Peças encaixam apenas nos slots corretos
  4. Garoto reage progressivamente
  5. Todas peças montadas = finale
- **Classificacao:** Confirmado

#### Tarefa 5.4: Final do Jogo
- **Descricao:** Sequência emotiva que encerra o jogo. EventChain mais longa
- **Diretorio:** /scripts/rooms/room_4/ e /scenes/ui/
- **Micro-Tasks:**
  - [ ] MT-5.4.1: Implementar `_trigger_finale()` no room_4_controller usando EventChain: (1) garoto para de chorar (sprite muda), (2) fade out cenário escuro, (3) `AudioManager.play_bgm("finale")` (crossfade para Goo Goo Dolls), (4) fade in cenário do passeio, (5) spawnar os dois personagens, (6) animação de "tirar foto" (Tween sutil), (7) flash branco (ColorRect alpha 0→1→0 rápido), (8) freeze 1.5s, (9) transição para tela final
  - [ ] MT-5.4.2: Tocar GooGoooDools, Imagem/foto final (fade in lento, 2s). Música continua. Texto cômico no final: Vale pizza / fundo preto (Label com fonte pixel, fade in após imagem). Nenhum botão intrusivo - após 5s faz fade to black)
- **Criterios de Aceitacao:**
  1. Crossfade musical sincronizado
  2. "Flash da foto" é satisfatório
  3. Imagem final é o payoff emocional
  4. Nenhuma UI estraga o momento
  5. Jogo tem encerramento digno
- **Classificacao:** Confirmado

#### Tarefa 5.5: Polimento
- **Descricao:** Obedeça às orientações do usuário até o jogo estar completamente polido
- **Micro-Tasks:**
  - [ ] MT-5.5.1: Obedeça o usuário
- **Criterios de Aceitacao:**
  1. Jogo Completo
- **Classificacao:** Confirmado

**Checkpoint FASE 5:** Todas as salas periféricas jogáveis. A sequência hub → 1 → hub → 2 → hub → 3 → hub → final funciona, com a protagonista como agente de movimento, colisão, coleta e abertura das ações finais.

---


---

## ARQUIVOS_AFETADOS

### /scripts/core/:
- CRIAR | `game_manager.gd` | Estado, progressão, transições de cena, fade
- CRIAR | `game_manager_test.gd` | Script da cena mínima de teste do GameManager
- CRIAR | `audio_manager.gd` | BGM crossfade, SFX

### /scripts/components/:
- CRIAR | `hotspot.gd` | Área clicável genérica (touch+mouse)
- CRIAR | `draggable.gd` | Objeto arrastável genérico
- CRIAR | `drop_zone.gd` | Zona alvo para drag-and-drop
- CRIAR | `revealer.gd` | Transição escuro→cor
- CRIAR | `event_chain.gd` | Sequenciador de eventos timed
- CRIAR | `protagonist_actor.gd` | Movimento reutilizável da protagonista, margens por fase e gatilho de chegada

### /scripts/rooms/:
- CRIAR | `main_menu_controller.gd` | Controller da sala principal / hub de progressão
- CRIAR | `room_1_controller.gd` | Orquestrador Sala 1
- CRIAR | `room_2_controller.gd` | Orquestrador Sala 2
- CRIAR | `room_3_controller.gd` | Orquestrador Sala 3
- CRIAR | `room_4_controller.gd` | Orquestrador da Sala Final

### /scripts/rooms/room_2/:
- NAO_CRIAR | scripts dedicados da versão antiga (`sweep_brush.gd`, `dust_spot.gd`, `minigame_sweep.gd`, `dish.gd`, `minigame_dishes.gd`, `minigame_clothes.gd`) | Na Fase 4 simplificada, a lógica fica centralizada em `room_2_controller.gd` e reaproveita componentes já existentes

### /scripts/rooms/room_3/:
- CRIAR | `player_dodge.gd` | Script especializado da protagonista no bullet hell
- CRIAR | `projectile.gd` | Projétil médico
- CRIAR | `bullet_spawner.gd` | Spawner de projéteis
- CRIAR | `baby_interaction.gd` | Interação de carinho

### /scripts/rooms/room_4/:
- CRIAR | `final_screen.gd` | Lógica da tela final

### /scenes/rooms/:
- CRIAR | `room_1.tscn` | Placeholder mínimo na Fase 0, expandido para Jardim das flores na Fase 3
- CRIAR | `room_2.tscn` | Casa bagunçada
- CRIAR | `room_3.tscn` | Hospital → quarto
- CRIAR | `room_4.tscn` | Sala Final / puzzle do coração

### /scenes/ui/:
- CRIAR | `main_menu.tscn` | Sala principal / hub de progressão
- CRIAR | `test_game_manager_transition.tscn` | Cena de teste do fluxo de transição e retorno ao hub
- CRIAR | `final_screen.tscn` | Tela final com foto
- CRIAR | `test_protagonist.tscn` | Cena de teste do clique-to-move da protagonista e das margens

### /scenes/components/:
- CRIAR | `projectile.tscn` | Cena do projétil (instanciável)
- CRIAR | `protagonist.tscn` | Cena reutilizável da protagonista
### /assets/:
- CRIAR | `sprites/` | Placeholder sprites para todas salas
- CRIAR | `audio/` | Tracks musicais e SFX

---

## INVARIANTES

| ID | Invariante | Origem | Violação detectável por |
|----|------------|--------|-------------------------|
| INV-1 | `GameManager.current_room` sempre reflete a sala visível; valor `0` representa a sala principal | Fluxo de jogo | Assert em `transition_to_room` e no retorno ao hub |
| INV-2 | BGM nunca para abruptamente — sempre crossfade | UX emocional | AudioManager.play_bgm sempre usa Tween |
| INV-3 | Todo estado de jogo tem caminho para avançar (zero dead-ends) | Game design | Cada controller tem path garantido para `complete_room`; no hub existe exatamente uma próxima porta válida |
| INV-4 | Componentes reutilizáveis não conhecem salas — zero referências a room_* em scripts de /components/ | Arquitetura | Inspeção: nenhum import/ref a rooms em components |
| INV-5 | Input funciona em touch E mouse para todo componente interativo | Plataforma Android + dev | Hotspot e Draggable tratam ambos InputEvent types |
| INV-6 | Projéteis são sempre destruídos ao sair da tela | Performance | VisibleOnScreenNotifier2D + queue_free |
| INV-7 | Portas bloqueadas da sala principal sempre exibem névoa; a porta liberada nunca exibe névoa | UX / progressão | `_refresh_doors_state()` no controller do hub |
| INV-8 | Ações contextuais só disparam depois que a protagonista alcança o alvo associado | Fluxo diegético | Controllers aguardam sinal de chegada antes de trocar de sala, coletar, iniciar minigame ou abrir puzzle |
| INV-9 | O movimento da protagonista é limitado por margens da fase, não por colisão de cenário | Navegação | Destino e/ou posição final sempre são clampados por `margin_top/bottom/left/right` |

## PRECONDICOES

| Operação | Condição | Verificação | Se falsa |
|----------|----------|-------------|----------|
| `transition_to_room(id)` | `id` entre 1-4 E `state != TRANSITIONING` E (`can_enter_room(id)` quando origem for o hub) | Guard no início da função | Ignora chamada, loga warning |
| `complete_room(id)` | `id == current_room` E room não já completa | Checar `rooms_completed` | Ignora chamada duplicada |
| `play_bgm(track_key)` | `track_key` existe em `TRACKS` dict | `TRACKS.has(track_key)` | Loga warning, mantém track atual |
| `Draggable._on_dropped()` | `_dragging == true` | Checado antes do processing | Não processa drop |
| `EventChain.play()` | `_playing == false` | Guard no início | Ignora segunda chamada |
| ação contextual de sala | protagonista já alcançou o alvo/marker da ação | controller espera sinal de chegada | ação fica pendente, mas não executa antes |

## POSCONDICOES

| Operação | Garantia | Verificação |
|----------|----------|-------------|
| `transition_to_room(id)` | Cena nova visível, fade completo, state == PLAYING | Sinal `transition_finished` emitido |
| `complete_room(id)` | Dict atualizado, hub recarregado se `id < 4` ou final mostrado se `id == 4` | `rooms_completed[id] == true` |
| `Revealer.reveal()` | Parent.modulate == revealed_color | Sinal `revealed` emitido |
| `EventChain.play()` | Todos steps executados na ordem | Sinal `chain_completed` emitido |
| Bullet hell timer expira | Spawner parado, projéteis removidos | Zero nós no grupo "projectile" |
| comando de movimento da protagonista | destino respeita margens da fase e sinal de chegada é emitido ao final | controller recebe o callback/sinal antes de disparar ação contextual |

## CASOS_DE_BORDA

| Caso | Comportamento Esperado |
|------|------------------------|
| Tap duplo rápido em Hotspot one_shot | Apenas primeira coleta registrada (active=false após primeiro) |
| Tap em porta bloqueada no hub | Nada acontece além do feedback opcional; sem transição |
| Tap em porta já concluída | Sala não reabre; estado permanece bloqueado |
| Soltar Draggable fora de qualquer DropZone | Tween de volta para posição original |
| Soltar Draggable em DropZone errada (Sala Final) | Rejeitado pelo `accepted_id`, snap back |
| Minimizar app durante EventChain | Godot pausa, retoma onde parou (SceneTree.paused) |
| Touch com múltiplos dedos | Draggable trava no primeiro touch_index; ignora outros |
| Clicar durante transição (fade) | GameManager em state TRANSITIONING bloqueia input de salas |
| Retorno ao hub após concluir uma sala | Porta concluída fica inacessível e a próxima porta correta é liberada |
| Clique em porta liberada no hub | A protagonista caminha primeiro; a troca de sala só acontece quando ela chega |
| Clique em alvo contextual de sala | A protagonista caminha primeiro; coleta, revelação ou minigame só começa ao chegar |
| Projétil spawna quando timer já expirou | Spawner.stop() chamado antes — nenhum novo projétil |
| Chamar reveal() em Revealer já revelado | Idempotente — nada acontece |
| Áudio placeholder inexistente | AudioManager loga warning, jogo continua sem som |

## MODOS_DE_FALHA

| Falha | Resposta |
|-------|----------|
| Cena de sala não encontrada no path | GameManager loga erro, não crasha (guard com `ResourceLoader.exists`) |
| `main_menu.tscn` ausente ou inválida | `GameManager.return_to_hub()` loga erro e mantém a cena atual |
| AudioStream null no dict de tracks | AudioManager ignora com warning |
| Projétil stuck dentro da tela (bug de posição) | Auto-destroy por lifetime timer (5s max) como fallback |
| Draggable perde referência do DropZone | snap_back garante retorno à origem |
| EventChain com Callable inválido | try/catch (ou verificar `is_valid()`) antes de call, skip step com warning |
| `rooms_completed` inconsistente | `get_next_room_to_unlock()` cai para a primeira sala não concluída válida |
| Touch não detectado em device | Hitboxes generosas (CollisionShape maior que sprite), testável em Tarefa 6.3 |

## CHECKLIST_QUALIDADE

| Eixo | Status | Nota |
|------|--------|------|
| Organização | Atendido | /core para managers, /components para reutilizáveis, /rooms para específicos. SRP por arquivo |
| Design Principles | Atendido | KISS (mecânicas simples), DRY (4 componentes reutilizados nas salas), YAGNI (sem save, sem inventário) |
| Modularity | Atendido | Componentes não conhecem salas (INV-4). Comunicação 100% por sinais |
| Patterns | Atendido | Observer (sinais), Composition (nós Godot), Chain of Responsibility (EventChain) |
| Coding | Atendido | Scripts curtos, nomes descritivos, exports para configuração |
| Testability | Atendido | Cada componente tem cena de teste isolada (Fase 1). Managers testáveis independentemente |
| Performance | Atendido | Pooling/destroy de projéteis, sem alocações em loop, Tweens ao invés de _process para animações |
| UI Architecture | Atendido | View (cenas .tscn) separada de logic (scripts), controller por sala e para o hub |

---

## ENTREGAVEIS

- [ ] Estrutura de projeto criada (Fase 0)
- [ ] GameManager e AudioManager funcionais como Autoload (Fase 0)
- [ ] 4 componentes reutilizáveis + protagonista base testados isoladamente (Fase 1)
- [ ] Sala principal / hub com portas bloqueadas por progressão e transição dependente da protagonista (Fase 2)
- [ ] Sala 1 jogável, validando protagonista + reveal por modulate (Fase 3)
- [ ] Sala 2 com 3 tarefas rápidas integradas à cena, iniciadas por aproximação da protagonista e concluídas com a transição animada final (Fase 4)
- [ ] Sala 3 com bullet hell na protagonista + carinho (Fase 5)
- [ ] Sala Final com coleta, puzzle e cena final emotiva (Fase 5)
- [ ] Fluxo completo hub → salas → final sem bugs (Fase 6)
- [ ] APK funcional testado em device Android (Fase 6)
- [ ] INVARIANTES verificáveis no código
- [ ] CASOS_DE_BORDA tratados
- [ ] MODOS_DE_FALHA implementados
- [ ] Estado: Pronto para presentear 🎁

---

## NOTAS_DE_CERTEZA

### Confirmado (GDD + alinhamento atual):
- Sala principal funciona como hub/menu do jogo
- Ordem espacial das portas no hub: direita = COLETE, baixo = ORGANIZE, esquerda = SOBREVIVA, cima = FINAL
- Progressão linear: só entra na próxima sala liberada, sem reentrada em salas concluídas
- A protagonista está presente no hub e em todas as salas jogáveis; ações contextuais só disparam por aproximação
- O workspace já possui spritesheets da protagonista em `assets/sprites/` com prefixo `Kay` para `idle`, `walking` e `interact`
- Estado atual do workspace: `protagonist.tscn` existe, mas o hub ainda usa uma protagonista provisória hardcoded em `main_menu.tscn` + `main_menu_controller.gd`; a migração para a cena reutilizável ainda precisa ser concluída
- Mecânicas: coleta, varrer/louça/roupa, bullet hell + carinho, puzzle
- Elementos: flores (rosa/hibisco/lírio/girassol), furão, bolo, cavalo, príncipe, Ravi, coração partido, foto final
- Músicas: End of Beginning 8 bit (principal/hub), Goo Goo Dolls (Sala Final)
- Plataforma: Android, 9:16, GDScript, Godot 4

### Assuncao (inferido com base):
- Resolução 540x960 (bom equilíbrio pixel art + detalhe para mobile)
- Bullet hell sem game over (contexto emocional não combina com punição)
- Saída da cena do bebê via botão sutil após 5 toques (mínimo de interação sem forçar)
- Puzzle do coração com 5-7 peças (suficiente para desafio sem frustrar)
- Timer do bullet hell: 15 segundos (curto, tenso, não cansativo)

### Desconhecido (precisa confirmar):
- Assets de pixel art: já existem ou serão criados? Impacta estimativa de tempo
- Goo Goo Dolls: qual faixa especificamente? "Iris"?
- Há textos/diálogos em algum momento ou é 100% visual?
- O garoto da Sala Final representa alguém específico?
- O furão tem nome?
- Ravi: referência a nome real? Sprite de bebê genérico ou específico?
