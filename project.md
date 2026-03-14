## ABORDAGEM

**Princípio central:** Construir os tijolos antes da casa.

```
FASE 0 ─ Projeto + Managers
FASE 1 ─ 4 Componentes reutilizáveis + validação isolada
FASE 2 ─ Sala 1 (composição: Hotspot + Revealer + EventChain)
FASE 3 ─ Sala 2 (composição: Draggable + Hotspot + Revealer + EventChain)
FASE 4 ─ Salas 3 e 4 (mecânicas específicas + componentes já prontos)
FASE 5 ─ Fluxo completo + polimento + Android
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
| YAGNI | Nada de inventário, save system, menu complexo |

## NAO_FAZER

- ❌ Criar classe base `RoomBase` (salas são diferentes demais)
- ❌ Mais de 2 Autoloads (GameManager e AudioManager bastam)
- ❌ Lógica de mecânica dentro de scripts de UI
- ❌ Hardcode de paths de cena (usar constantes em GameManager)
- ❌ Polling em `_process` para detecção de click (usar `_input_event` de Area2D)
- ❌ Criar sistemas que só servem uma sala (inline no controller)
- ❌ Assets finais antes da mecânica funcionar com placeholders

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
  - [X] MT-0.1.2: Configurar `project.godot`: viewport 540x960, stretch mode `canvas_items`, stretch aspect `keep_width`, orientation portrait
  - [ ] MT-0.1.3: Criar `.gitignore` para Godot 4 e commitar estrutura vazia
- **Criterios de Aceitacao:**
  1. Projeto abre no editor sem erros
  2. Preview mostra proporção 9:16 vertical
- **Classificacao:** Confirmado

#### Tarefa 0.2: GameManager
- **Descricao:** Autoload que controla estado do jogo, progressão e transições de cena
- **Diretorio:** /scripts/core/
- **Micro-Tasks:**
  - [ ] MT-0.2.1: Criar `game_manager.gd` com `enum State {PLAYING, TRANSITIONING}`, var `current_room: int = 0`, dict `rooms_completed: Dictionary = {}`
  - [ ] MT-0.2.2: Criar constante `ROOM_SCENES: Dictionary = {1: "res://scenes/rooms/room_1.tscn", ...}` mapeando id→path
  - [ ] MT-0.2.3: Implementar sinais: `room_completed(room_id: int)`, `transition_started`, `transition_finished`
  - [ ] MT-0.2.4: Criar `CanvasLayer` filho com `ColorRect` fullscreen preto (para fades), z_index=100
  - [ ] MT-0.2.5: Implementar `func transition_to_room(room_id: int)`: valida id, seta state TRANSITIONING, fade to black via Tween no ColorRect, `get_tree().change_scene_to_file()`, fade from black, seta PLAYING
  - [ ] MT-0.2.6: Implementar `func complete_room(room_id: int)`: marca dict, emite sinal, chama `transition_to_room(room_id + 1)` — ou cena final se room_id == 4
  - [ ] MT-0.2.7: Registrar como Autoload "GameManager" em Project Settings
  - [ ] MT-0.2.8: Criar cena de teste mínima que chama `GameManager.transition_to_room(1)` e verifica fade
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
  - [ ] MT-0.3.1: Criar `audio_manager.gd` com 2 filhos `AudioStreamPlayer`: `bgm_player` e `sfx_player`
  - [ ] MT-0.3.2: Criar dict `TRACKS: Dictionary = {"main": preload("res://assets/audio/end_of_beginning.ogg"), "finale": preload("res://assets/audio/goo_goo_dolls.ogg")}` — com placeholders se áudio ainda não existe
  - [ ] MT-0.3.3: Implementar `func play_bgm(track_key: String)`: se já tocando mesma track ignora; se outra, crossfade (Tween volume down old → swap stream → Tween volume up)
  - [ ] MT-0.3.4: Implementar `func play_sfx(sfx: AudioStream)`: seta stream no sfx_player e toca (fire-and-forget)
  - [ ] MT-0.3.5: Implementar `func stop_bgm(fade_duration: float = 0.5)` com fade out
  - [ ] MT-0.3.6: Registrar como Autoload "AudioManager"
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
  - [ ] MT-1.1.1: Criar `hotspot.gd` extends `Area2D` com exports: `hotspot_id: String`, `one_shot: bool = true`, `active: bool = true`
  - [ ] MT-1.1.2: Sinal `pressed(hotspot_id: String)`. Em `_input_event`, detectar `InputEventMouseButton` (button_index LEFT, pressed) OU `InputEventScreenTouch` (pressed). Se `active`, emitir sinal. Se `one_shot`, setar `active = false`
  - [ ] MT-1.1.3: Adicionar feedback: quando mouse/touch entra na área, modulate do parent levemente (1.1, 1.1, 1.1) para indicar interatividade. Resetar ao sair
  - [ ] MT-1.1.4: Criar cena de teste `test_hotspot.tscn` com 3 Hotspots + Label que mostra qual foi clicado. Validar touch e mouse
- **Criterios de Aceitacao:**
  1. Emite `pressed` exatamente uma vez se `one_shot`
  2. Não emite se `active = false`
  3. Funciona com mouse E touch
  4. Feedback visual sutil ao hover/touch
- **Classificacao:** Confirmado

#### Tarefa 1.2: Draggable (Objeto arrastável)
- **Descricao:** Nó que pode ser arrastado pelo jogador e detecta drop em zonas alvo. Usado em Sala 2 (vassoura, roupa) e Sala 4 (puzzle)
- **Diretorio:** /scripts/components/
- **Micro-Tasks:**
  - [ ] MT-1.2.1: Criar `draggable.gd` extends `Area2D` com exports: `drag_id: String`, `snap_back: bool = true`, `snap_distance: float = 40.0`, `active: bool = true`
  - [ ] MT-1.2.2: Guardar `_origin_position: Vector2` no `_ready`. Implementar estado interno `_dragging: bool`. Em `_input_event`, detectar press → `_dragging = true`. Em `_input(event)`, se `_dragging`: atualizar `global_position` para posição do touch/mouse. Detectar release → `_dragging = false`, chamar `_on_dropped()`
  - [ ] MT-1.2.3: Sinais: `drag_started(drag_id)`, `drag_ended(drag_id)`, `dropped_on_target(drag_id, target_area)`. Em `_on_dropped()`: checar overlapping areas. Se alguma pertence ao grupo "drop_target" e distância < `snap_distance`, snap para posição do target e emitir `dropped_on_target`. Senão, se `snap_back`, Tween de volta para `_origin_position`
  - [ ] MT-1.2.4: Criar `drop_zone.gd` extends `Area2D` — script mínimo que só adiciona ao grupo "drop_target" no `_ready` e tem export `zone_id: String`
  - [ ] MT-1.2.5: Criar cena de teste `test_drag.tscn` com 2 Draggables e 2 DropZones. Validar snap, snap_back, sinais
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
  - [ ] MT-1.3.1: Criar `revealer.gd` extends `Node` (attachable a qualquer nó visual). Exports: `reveal_duration: float = 0.6`, `hidden_color: Color = Color(0.15, 0.15, 0.15, 1.0)`, `revealed_color: Color = Color.WHITE`, `start_hidden: bool = true`
  - [ ] MT-1.3.2: No `_ready`, se `start_hidden`, setar `get_parent().modulate = hidden_color`. Sinal `revealed`. Implementar `func reveal()`: cria Tween, interpola `get_parent().modulate` de atual para `revealed_color` em `reveal_duration`, ao final emite `revealed`
  - [ ] MT-1.3.3: Implementar `func hide_visual()` (reverso, para reset) e `func reveal_instant()` (sem animação, para debug/testes)
  - [ ] MT-1.3.4: Criar cena de teste com 4 sprites coloridos, cada um com Revealer filho, e botão que chama `reveal()` em cada um sequencialmente
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
  - [ ] MT-1.4.1: Criar `event_chain.gd` extends `Node`. Define classe interna ou dict para steps. Cada step: `{callable: Callable, delay_after: float}`. Array `_steps: Array[Dictionary] = []`
  - [ ] MT-1.4.2: Implementar `func add_step(what: Callable, delay_after: float = 0.5) -> EventChain` (retorna self para chaining). Implementar `func clear()`
  - [ ] MT-1.4.3: Implementar `func play()`: itera `_steps`, para cada um chama `callable.call()`, depois `await get_tree().create_timer(delay_after).timeout`. Sinal `chain_completed` ao final. Var `_playing: bool` para evitar dupla execução
  - [ ] MT-1.4.4: Criar cena de teste com 4 Labels que aparecem em sequência com 0.5s entre cada, usando EventChain para orquestrar
- **Criterios de Aceitacao:**
  1. Steps executam na ordem com delays corretos
  2. `chain_completed` emitido ao final
  3. Chamar `play()` durante execução é ignorado
  4. Funções arbitrárias podem ser steps (Callable genérico)
- **Classificacao:** Confirmado

**Checkpoint FASE 1:** 4 componentes funcionam isoladamente em cenas de teste. Hotspot responde a touch, Draggable faz snap, Revealer anima cor, EventChain orquestra sequência. Todos testados antes de montar qualquer sala.

---

### FASE 2: Sala 1 — COLETE
**Objetivo:** Primeira sala completa, valida que a composição de componentes funciona em contexto real
**Subsistemas cobertos:** Hotspot + Revealer + EventChain + GameManager

#### Tarefa 2.1: Layout da Cena
- **Descricao:** Montar cena visual do jardim com elementos posicionados
- **Diretorio:** /scenes/rooms/
- **Micro-Tasks:**
  - [ ] MT-2.1.1: Criar `room_1.tscn` com `Node2D` root. Adicionar sprite de fundo (jardim apagado, placeholder retângulo se necessário). Dividir visualmente em 4 quadrantes para os canteiros
  - [ ] MT-2.1.2: Adicionar 4 `Sprite2D` para canteiros (rosa, hibisco, lírio, girassol), cada um com filho `Revealer` configurado `start_hidden = true`. Posicionar nos quadrantes
  - [ ] MT-2.1.3: Adicionar `Sprite2D` do bolo no centro (incompleto). Adicionar `Sprite2D` do presente no canto (fechado). Adicionar `Sprite2D` do furão (invisível, `visible = false`)
  - [ ] MT-2.1.4: Adicionar 4 `Hotspot` (Area2D + CollisionShape2D) posicionados onde as flores estão escondidas. Configurar `hotspot_id` como "rosa", "hibisco", "lirio", "girassol" e `one_shot = true`
  - [ ] MT-2.1.5: Adicionar overlay escuro opcional (Sprite2D ou ColorRect semi-transparente para névoa)
- **Criterios de Aceitacao:**
  1. Cena renderiza em 540x960 sem cortes
  2. Tudo começa escuro/cinza
  3. 4 hotspots posicionados e com collision shapes
- **Classificacao:** Confirmado

#### Tarefa 2.2: Controller da Sala 1
- **Descricao:** Script que conecta hotspots aos revealers e orquestra conclusão
- **Diretorio:** /scripts/rooms/
- **Micro-Tasks:**
  - [ ] MT-2.2.1: Criar `room_1_controller.gd` extends `Node2D` (root da cena). `@onready` refs para os 4 Hotspots, 4 canteiros com Revealer, bolo, presente, furão. Var `_flowers_collected: int = 0`
  - [ ] MT-2.2.2: No `_ready`, conectar sinal `pressed` de cada Hotspot a `_on_flower_collected(hotspot_id: String)`. Nessa função: encontrar canteiro correspondente, chamar `$Revealer.reveal()`, incrementar `_flowers_collected`, tocar SFX via `AudioManager.play_sfx(...)`. Se `_flowers_collected == 4`, chamar `_start_finale()`
  - [ ] MT-2.2.3: Implementar `_start_finale()` usando `EventChain`: criar instância (ou nó já na cena), popular com steps: (1) tocar som suave, (2) trocar sprite do bolo para decorado, (3) fazer presente tremer (Tween position wiggle), (4) setar furão `visible = true` com scale de 0→1, (5) fade out da névoa, (6) chamar `GameManager.complete_room(1)`. Conectar `chain_completed` se necessário
  - [ ] MT-2.2.4: Testar fluxo completo: clicar 4 hotspots → revelações → finale → transição para próxima sala
- **Criterios de Aceitacao:**
  1. Cada flor revela canteiro correspondente
  2. Só dispara finale quando 4/4 coletadas
  3. Sequência de finale executa na ordem com timings
  4. Ao final, GameManager faz transição para Sala 2
  5. Hotspots desativam após coleta (one_shot)
- **Classificacao:** Confirmado

**Checkpoint FASE 2:** Sala 1 jogável do início ao fim. Composição de Hotspot + Revealer + EventChain validada em contexto real. Transição para cena seguinte funciona.

---

### FASE 3: Sala 2 — ORGANIZE
**Objetivo:** Implementar 3 minigames curtos usando componentes existentes + lógica específica mínima
**Subsistemas cobertos:** Draggable + Hotspot + Revealer + EventChain + lógica de minigame

#### Tarefa 3.1: Cena e Controller da Sala 2
- **Descricao:** Layout da casa bagunçada e controller que gerencia progresso dos 3 minigames
- **Diretorio:** /scenes/rooms/ e /scripts/rooms/
- **Micro-Tasks:**
  - [ ] MT-3.1.1: Criar `room_2.tscn` com fundo de casa bagunçada. Dividir em 3 zonas visuais: área de chão (poeira), pia (louça), canto (roupa). Cada zona tem Revealer para transformação posterior
  - [ ] MT-3.1.2: Criar `room_2_controller.gd` com var `_minigames_done: int = 0`. Implementar `_on_minigame_completed(minigame_id: String)`: incrementa, revela zona correspondente, se 3/3 chama `_start_transformation()`
  - [ ] MT-3.1.3: Criar sinal ou grupo para conectar cada minigame ao controller
- **Criterios de Aceitacao:**
  1. Cena renderiza corretamente
  2. Controller rastreia progresso
  3. Minigames podem ser feitos em qualquer ordem
- **Classificacao:** Confirmado

#### Tarefa 3.2: Minigame Varrer
- **Descricao:** Arrastar vassoura sobre 3 áreas de poeira até sumirem. Usa Draggable adaptado
- **Diretorio:** /scripts/rooms/room_2/
- **Micro-Tasks:**
  - [ ] MT-3.2.1: Criar sprite da vassoura como `Area2D` que segue touch/mouse (similar a Draggable mas sem snap — segue continuamente). Script `sweep_brush.gd`: em `_input`, atualiza `global_position` para posição do toque enquanto pressionado
  - [ ] MT-3.2.2: Criar 3 `Area2D` para manchas de poeira, cada uma com script `dust_spot.gd`: var `_clean_progress: float = 0.0`. Detecta overlap com vassoura via `_on_area_entered`/`_on_area_exited`. Enquanto overlap, incrementa progress em `_process`. Quando `>= 1.0`, fade out com Tween e emite sinal `cleaned`
  - [ ] MT-3.2.3: Criar `minigame_sweep.gd` que conta 3 sinais `cleaned` e emite `completed("sweep")`
- **Criterios de Aceitacao:**
  1. Vassoura segue dedo suavemente
  2. Poeira some gradualmente ao manter vassoura sobre ela
  3. Completa quando 3 manchas limpas
- **Classificacao:** Confirmado

#### Tarefa 3.3: Minigame Louça
- **Descricao:** Clicar rapidamente em louças para lavá-las. Usa Hotspot com one_shot=false
- **Diretorio:** /scripts/rooms/room_2/
- **Micro-Tasks:**
  - [ ] MT-3.3.1: Criar 5-6 Hotspots representando louças sujas, com `one_shot = false`. Script `dish.gd` extends o Hotspot ou é nó irmão: var `_clicks_needed: int = 3`, var `_clicks: int = 0`. A cada `pressed`, incrementa. Quando `_clicks >= _clicks_needed`, troca sprite para "limpo" e desativa
  - [ ] MT-3.3.2: Criar `minigame_dishes.gd` que conta louças limpas e emite `completed("dishes")` quando todas prontas
  - [ ] MT-3.3.3: Adicionar feedback: cada clique faz splash de água (partícula simples ou sprite animado rápido)
- **Criterios de Aceitacao:**
  1. Cada louça requer ~3 cliques
  2. Feedback visual por clique
  3. Total ~10-15 segundos de gameplay
- **Classificacao:** Confirmado

#### Tarefa 3.4: Minigame Roupa
- **Descricao:** Arrastar 3 roupas para o cesto. Usa Draggable + DropZone
- **Diretorio:** /scripts/rooms/room_2/
- **Micro-Tasks:**
  - [ ] MT-3.4.1: Adicionar 3 `Draggable` como roupas espalhadas e 1 `DropZone` como cesto. Configurar `snap_back = true`
  - [ ] MT-3.4.2: Criar `minigame_clothes.gd` que escuta `dropped_on_target` dos 3 Draggables. Ao drop bem-sucedido, esconde roupa com animação. Quando 3 roupas no cesto, emite `completed("clothes")`
- **Criterios de Aceitacao:**
  1. Roupas arrastáveis com snap para cesto
  2. Voltam se soltas fora
  3. Completa quando 3/3 no cesto
- **Classificacao:** Confirmado

#### Tarefa 3.5: Transformação da Sala 2
- **Descricao:** Casa vira campo com cavalo e príncipe via EventChain
- **Diretorio:** /scripts/rooms/
- **Micro-Tasks:**
  - [ ] MT-3.5.1: Implementar `_start_transformation()` no controller usando EventChain: (1) som de vidro quebrando, (2) trocar sprite da janela para "quebrada", (3) spawnar cavalo entrando pela janela (Tween posição de fora para dentro), (4) fade out de todos elementos da casa, (5) fade in de background de campo/grama, (6) spawnar silhueta de príncipe (scale 0→1), (7) delay 2s emocional, (8) `GameManager.complete_room(2)`
  - [ ] MT-3.5.2: Preparar sprites/placeholders: janela_inteira, janela_quebrada, cavalo, campo, príncipe_silhueta
- **Criterios de Aceitacao:**
  1. Sequência fluida sem glitches
  2. Timing permite absorver emocionalmente
  3. Transição para Sala 3 funciona
- **Classificacao:** Confirmado

**Checkpoint FASE 3:** Sala 2 jogável, 3 minigames funcionais em qualquer ordem, transformação executa completamente.

---

### FASE 4: Salas 3 e 4
**Objetivo:** Implementar as duas salas restantes, incluindo a mecânica nova (bullet hell) e a cena final do jogo
**Subsistemas cobertos:** BulletHell, BabyInteraction (Hotspot reutilizado), Puzzle (Draggable reutilizado), Finale

#### Tarefa 4.1: Sala 3 Parte 1 — Bullet Hell
- **Descricao:** Mecânica de desvio de projéteis médicos por tempo limitado. Única mecânica nova do jogo
- **Diretorio:** /scripts/rooms/room_3/ e /scenes/rooms/
- **Micro-Tasks:**
  - [ ] MT-4.1.1: Criar `room_3.tscn` com fundo hospitalar escuro. Criar nó player (`Area2D` com sprite pequeno). Criar `Timer` de sobrevivência (15s, export var para ajuste)
  - [ ] MT-4.1.2: Criar `player_dodge.gd`: segue touch/mouse (como sweep_brush da sala 2 — mesma lógica de seguir dedo). Clampar posição dentro dos limites da tela. Sinal `hit` ao detectar overlap com grupo "projectile"
  - [ ] MT-4.1.3: Criar `projectile.tscn`: `Area2D` no grupo "projectile" com sprite (seringa/placeholder), script `projectile.gd` com export `speed: float` e `direction: Vector2`. Move em `_process`. Se sair da tela (`VisibleOnScreenNotifier2D`), `queue_free()`
  - [ ] MT-4.1.4: Criar `bullet_spawner.gd`: Timer de spawn (0.4s-0.8s). Instancia `projectile.tscn` em posições aleatórias nas bordas com direção para dentro. Export `spawn_rate_range: Vector2` para variação
  - [ ] MT-4.1.5: No controller `room_3_controller.gd`: ao player ser `hit`, flash vermelho (Tween modulate) + breve invencibilidade (0.5s). NÃO é game over. Quando timer de sobrevivência acaba, spawner para, projéteis restantes fazem fade out, chama `_transition_to_nursery()`
- **Criterios de Aceitacao:**
  1. Player segue dedo responsivamente
  2. Projéteis vêm de bordas variadas
  3. Hit = feedback visual, NÃO morte
  4. Após 15s (configurável), fase termina automaticamente
  5. Sem memory leak de projéteis
- **Classificacao:** Confirmado

#### Tarefa 4.2: Sala 3 Parte 2 — Quarto do Ravi
- **Descricao:** Transição emocional para interação suave com bebê. Reutiliza Hotspot
- **Diretorio:** /scripts/rooms/room_3/
- **Micro-Tasks:**
  - [ ] MT-4.2.1: Implementar `_transition_to_nursery()` usando EventChain: (1) fade out elementos hospitalares, (2) trocar fundo para quarto do bebê, (3) mudar tom musical (AudioManager — mesma track mas volume ajustado ou track alternativa mais calma), (4) revelar sprite do Ravi no centro
  - [ ] MT-4.2.2: Criar `baby_interaction.gd`: Hotspot no Ravi com `one_shot = false`. Cada `pressed`: spawnar `Sprite2D` de coração na posição do toque com Tween (sobe + fade out em 1s, depois `queue_free`), tocar SFX fofo (varia entre 2-3 sons aleatórios). Var `_touch_count: int`. Após 5+ toques, mostrar botão/indicador sutil de "→" (próxima)
  - [ ] MT-4.2.3: Botão de próximo chama `GameManager.complete_room(3)`. Garantir que não aparece antes de 5 toques para que jogador interaja minimamente
- **Criterios de Aceitacao:**
  1. Contraste emocional brutal: tensão → paz
  2. Corações sobem e somem suavemente
  3. Sons fofos não repetitivos (rodar entre variações)
  4. Saída disponível após interação mínima mas sem pressa
- **Classificacao:** Confirmado (mecânica de saída: Assuncao — botão após 5 toques)

#### Tarefa 4.3: Sala 4 — Puzzle do Coração
- **Descricao:** Montar coração partido arrastando peças. Reutiliza Draggable + DropZone
- **Diretorio:** /scripts/rooms/room_4/ e /scenes/rooms/
- **Micro-Tasks:**
  - [ ] MT-4.3.1: Criar `room_4.tscn` com fundo escuro. Sprite do garoto chorando no centro-baixo. Moldura/mesa central onde coração será montado. 5-7 `Draggable` como peças do coração espalhadas pelo cenário
  - [ ] MT-4.3.2: Criar `DropZone` para cada peça na moldura central, posicionadas para formar o coração quando todas encaixadas. Cada DropZone aceita apenas o Draggable com `drag_id` correspondente (adicionar validação em `drop_zone.gd`: export `accepted_id: String`, verificar antes de aceitar)
  - [ ] MT-4.3.3: Criar `room_4_controller.gd`: escuta `dropped_on_target` de todas peças. Tracker `_pieces_placed: int`. A cada peça: (garoto chora menos — trocar sprite ou reduzir partículas de lágrima). Quando todas colocadas, `_trigger_finale()`
  - [ ] MT-4.3.4: Atualizar `drop_zone.gd` para suportar `accepted_id` (validação de qual Draggable aceita). Se `accepted_id != ""` e `drag_id` não corresponde, rejeitar o drop (snap back)
- **Criterios de Aceitacao:**
  1. Peças encaixam apenas nos slots corretos
  2. Snap satisfatório
  3. Garoto reage progressivamente
  4. Todas peças = finale
- **Classificacao:** Confirmado

#### Tarefa 4.4: Cena Final do Jogo
- **Descricao:** Sequência emotiva que encerra o jogo. EventChain mais longa
- **Diretorio:** /scripts/rooms/room_4/ e /scenes/ui/
- **Micro-Tasks:**
  - [ ] MT-4.4.1: Implementar `_trigger_finale()` no room_4_controller usando EventChain: (1) garoto para de chorar (sprite muda), (2) fade out cenário escuro, (3) `AudioManager.play_bgm("finale")` (crossfade para Goo Goo Dolls), (4) fade in cenário do passeio, (5) spawnar os dois personagens, (6) animação de "tirar foto" (Tween sutil), (7) flash branco (ColorRect alpha 0→1→0 rápido), (8) freeze 1.5s, (9) transição para tela final
  - [ ] MT-4.4.2: Criar `final_screen.tscn`: CanvasLayer com background preto, `TextureRect` centralizada para a imagem/foto final (fade in lento, 2s). Música continua. Texto de dedicatória opcional (Label com fonte pixel, fade in após imagem). Nenhum botão intrusivo — tap anywhere após 5s faz fade to black e volta ao menu ou fecha
  - [ ] MT-4.4.3: Implementar script `final_screen.gd`: lógica mínima — fade in da imagem, detectar tap para encerrar (com guard de 5s para não encerrar acidentalmente)
- **Criterios de Aceitacao:**
  1. Crossfade musical sincronizado
  2. "Flash da foto" é satisfatório
  3. Imagem final é o payoff emocional
  4. Nenhuma UI estraga o momento
  5. Jogo tem encerramento digno
- **Classificacao:** Confirmado

**Checkpoint FASE 4:** Todas 4 salas jogáveis. Jogo completo do início ao fim.

---

### FASE 5: Fluxo Completo, Polimento e Android
**Objetivo:** Integrar tudo, polir, exportar para Android
**Subsistemas cobertos:** Menu, fluxo, UX, export

#### Tarefa 5.1: Menu Inicial
- **Descricao:** Tela de entrada minimalista
- **Diretorio:** /scenes/ui/
- **Micro-Tasks:**
  - [ ] MT-5.1.1: Criar `main_menu.tscn`: fundo temático (escuro com partículas sutis ou imagem simples), título ou dedicatória sutil, label "toque para começar" com Tween de opacity pulsante
  - [ ] MT-5.1.2: Script `main_menu.gd`: no `_ready`, `AudioManager.play_bgm("main")`. Em `_input`, detectar qualquer touch/click → `GameManager.transition_to_room(1)`
  - [ ] MT-5.1.3: Configurar como cena principal em Project Settings (run on launch)
- **Criterios de Aceitacao:**
  1. Jogo abre nesta tela
  2. Música já toca
  3. Tap inicia jogo
- **Classificacao:** Confirmado

#### Tarefa 5.2: Playtest de Fluxo Completo
- **Descricao:** Jogar menu → sala 1 → sala 2 → sala 3 → sala 4 → final sem bugs
- **Diretorio:** N/A (processo)
- **Micro-Tasks:**
  - [ ] MT-5.2.1: Testar fluxo completo no editor (mouse). Anotar bugs
  - [ ] MT-5.2.2: Corrigir bugs encontrados
  - [ ] MT-5.2.3: Ajustar timings de animações e delays baseado no feel
  - [ ] MT-5.2.4: Verificar que nenhum estado morto existe (sempre há caminho para frente)
- **Criterios de Aceitacao:**
  1. Zero crashes
  2. Zero dead-ends
  3. Fluxo emocional coerente
- **Classificacao:** Confirmado

#### Tarefa 5.3: Export Android
- **Descricao:** Configurar e gerar APK funcional
- **Diretorio:** /
- **Micro-Tasks:**
  - [ ] MT-5.3.1: Instalar export templates Android. Configurar keystore de debug. Criar preset de export com orientação portrait-only
  - [ ] MT-5.3.2: Gerar APK de debug
  - [ ] MT-5.3.3: Instalar em device real. Testar: touch responsivo em todos componentes (hotspot, drag, sweep, tap rápido), aspect ratio, áudio, performance
  - [ ] MT-5.3.4: Ajustes finais baseados no teste em device (tamanhos de hitbox, velocidade de drag, etc)
- **Criterios de Aceitacao:**
  1. APK instala e roda
  2. Touch funciona em todas mecânicas
  3. Sem frame drops perceptíveis
  4. Áudio não corta
- **Classificacao:** Confirmado

**Checkpoint FASE 5:** Jogo completo e jogável em Android. Pronto para presentear.

---

## ARQUIVOS_AFETADOS

### /scripts/core/:
- CRIAR | `game_manager.gd` | Estado, progressão, transições de cena, fade
- CRIAR | `audio_manager.gd` | BGM crossfade, SFX

### /scripts/components/:
- CRIAR | `hotspot.gd` | Área clicável genérica (touch+mouse)
- CRIAR | `draggable.gd` | Objeto arrastável genérico
- CRIAR | `drop_zone.gd` | Zona alvo para drag-and-drop
- CRIAR | `revealer.gd` | Transição escuro→cor
- CRIAR | `event_chain.gd` | Sequenciador de eventos timed

### /scripts/rooms/:
- CRIAR | `room_1_controller.gd` | Orquestrador Sala 1
- CRIAR | `room_2_controller.gd` | Orquestrador Sala 2
- CRIAR | `room_3_controller.gd` | Orquestrador Sala 3
- CRIAR | `room_4_controller.gd` | Orquestrador Sala 4

### /scripts/rooms/room_2/:
- CRIAR | `sweep_brush.gd` | Vassoura que segue touch
- CRIAR | `dust_spot.gd` | Mancha de poeira com progresso
- CRIAR | `minigame_sweep.gd` | Controller do minigame varrer
- CRIAR | `dish.gd` | Louça com clicks para lavar
- CRIAR | `minigame_dishes.gd` | Controller do minigame louça
- CRIAR | `minigame_clothes.gd` | Controller do minigame roupa

### /scripts/rooms/room_3/:
- CRIAR | `player_dodge.gd` | Player do bullet hell
- CRIAR | `projectile.gd` | Projétil médico
- CRIAR | `bullet_spawner.gd` | Spawner de projéteis
- CRIAR | `baby_interaction.gd` | Interação de carinho

### /scripts/rooms/room_4/:
- CRIAR | `final_screen.gd` | Lógica da tela final

### /scenes/rooms/:
- CRIAR | `room_1.tscn` | Jardim das flores
- CRIAR | `room_2.tscn` | Casa bagunçada
- CRIAR | `room_3.tscn` | Hospital → quarto
- CRIAR | `room_4.tscn` | Puzzle do coração

### /scenes/ui/:
- CRIAR | `main_menu.tscn` | Tela de entrada
- CRIAR | `final_screen.tscn` | Tela final com foto

### /scenes/components/:
- CRIAR | `projectile.tscn` | Cena do projétil (instanciável)

### /assets/:
- CRIAR | `sprites/` | Placeholder sprites para todas salas
- CRIAR | `audio/` | Tracks musicais e SFX

---

## INVARIANTES

| ID | Invariante | Origem | Violação detectável por |
|----|------------|--------|-------------------------|
| INV-1 | `GameManager.current_room` sempre reflete a sala visível | Fluxo de jogo | Assert em `transition_to_room` antes de trocar cena |
| INV-2 | BGM nunca para abruptamente — sempre crossfade | UX emocional | AudioManager.play_bgm sempre usa Tween |
| INV-3 | Todo estado de jogo tem caminho para avançar (zero dead-ends) | Game design | Cada controller tem path garantido para `complete_room` |
| INV-4 | Componentes reutilizáveis não conhecem salas — zero referências a room_* em scripts de /components/ | Arquitetura | Inspeção: nenhum import/ref a rooms em components |
| INV-5 | Input funciona em touch E mouse para todo componente interativo | Plataforma Android + dev | Hotspot e Draggable tratam ambos InputEvent types |
| INV-6 | Projéteis são sempre destruídos ao sair da tela | Performance | VisibleOnScreenNotifier2D + queue_free |

## PRECONDICOES

| Operação | Condição | Verificação | Se falsa |
|----------|----------|-------------|----------|
| `transition_to_room(id)` | `id` entre 1-4 E `state != TRANSITIONING` | Guard no início da função | Ignora chamada, loga warning |
| `complete_room(id)` | `id == current_room` E room não já completa | Checar `rooms_completed` | Ignora chamada duplicada |
| `play_bgm(track_key)` | `track_key` existe em `TRACKS` dict | `TRACKS.has(track_key)` | Loga warning, mantém track atual |
| `Draggable._on_dropped()` | `_dragging == true` | Checado antes do processing | Não processa drop |
| `EventChain.play()` | `_playing == false` | Guard no início | Ignora segunda chamada |

## POSCONDICOES

| Operação | Garantia | Verificação |
|----------|----------|-------------|
| `transition_to_room(id)` | Cena nova visível, fade completo, state == PLAYING | Sinal `transition_finished` emitido |
| `complete_room(id)` | Dict atualizado, próxima sala carregada ou final mostrado | `rooms_completed[id] == true` |
| `Revealer.reveal()` | Parent.modulate == revealed_color | Sinal `revealed` emitido |
| `EventChain.play()` | Todos steps executados na ordem | Sinal `chain_completed` emitido |
| Bullet hell timer expira | Spawner parado, projéteis removidos | Zero nós no grupo "projectile" |

## CASOS_DE_BORDA

| Caso | Comportamento Esperado |
|------|------------------------|
| Tap duplo rápido em Hotspot one_shot | Apenas primeira coleta registrada (active=false após primeiro) |
| Soltar Draggable fora de qualquer DropZone | Tween de volta para posição original |
| Soltar Draggable em DropZone errada (Sala 4) | Rejeitado pelo `accepted_id`, snap back |
| Minimizar app durante EventChain | Godot pausa, retoma onde parou (SceneTree.paused) |
| Touch com múltiplos dedos | Draggable trava no primeiro touch_index; ignora outros |
| Clicar durante transição (fade) | GameManager em state TRANSITIONING bloqueia input de salas |
| Projétil spawna quando timer já expirou | Spawner.stop() chamado antes — nenhum novo projétil |
| Chamar reveal() em Revealer já revelado | Idempotente — nada acontece |
| Áudio placeholder inexistente | AudioManager loga warning, jogo continua sem som |

## MODOS_DE_FALHA

| Falha | Resposta |
|-------|----------|
| Cena de sala não encontrada no path | GameManager loga erro, não crasha (guard com `ResourceLoader.exists`) |
| AudioStream null no dict de tracks | AudioManager ignora com warning |
| Projétil stuck dentro da tela (bug de posição) | Auto-destroy por lifetime timer (5s max) como fallback |
| Draggable perde referência do DropZone | snap_back garante retorno à origem |
| EventChain com Callable inválido | try/catch (ou verificar `is_valid()`) antes de call, skip step com warning |
| Touch não detectado em device | Hitboxes generosas (CollisionShape maior que sprite), testável em Tarefa 5.3 |

## CHECKLIST_QUALIDADE

| Eixo | Status | Nota |
|------|--------|------|
| Organização | Atendido | /core para managers, /components para reutilizáveis, /rooms para específicos. SRP por arquivo |
| Design Principles | Atendido | KISS (mecânicas simples), DRY (4 componentes reutilizados em 4 salas), YAGNI (sem save, sem inventário) |
| Modularity | Atendido | Componentes não conhecem salas (INV-4). Comunicação 100% por sinais |
| Patterns | Atendido | Observer (sinais), Composition (nós Godot), Chain of Responsibility (EventChain) |
| Coding | Atendido | Scripts curtos, nomes descritivos, exports para configuração |
| Testability | Atendido | Cada componente tem cena de teste isolada (Fase 1). Managers testáveis independentemente |
| Performance | Atendido | Pooling/destroy de projéteis, sem alocações em loop, Tweens ao invés de _process para animações |
| UI Architecture | Atendido | View (cenas .tscn) separada de logic (scripts), controller por sala |

---

## ENTREGAVEIS

- [ ] Estrutura de projeto criada (Fase 0)
- [ ] GameManager e AudioManager funcionais como Autoload (Fase 0)
- [ ] 4 componentes reutilizáveis testados isoladamente (Fase 1)
- [ ] Sala 1 jogável, validando composição de componentes (Fase 2)
- [ ] Sala 2 com 3 minigames funcionais (Fase 3)
- [ ] Sala 3 com bullet hell + carinho (Fase 4)
- [ ] Sala 4 com puzzle + cena final emotiva (Fase 4)
- [ ] Fluxo completo menu → 4 salas → final sem bugs (Fase 5)
- [ ] APK funcional testado em device Android (Fase 5)
- [ ] INVARIANTES verificáveis no código
- [ ] CASOS_DE_BORDA tratados
- [ ] MODOS_DE_FALHA implementados
- [ ] Estado: Pronto para presentear 🎁

---

## NOTAS_DE_CERTEZA

### Confirmado (explícito no GDD):
- 4 salas: COLETE, ORGANIZE, SOBREVIVA, REPARE
- Mecânicas: coleta, varrer/louça/roupa, bullet hell + carinho, puzzle
- Elementos: flores (rosa/hibisco/lírio/girassol), furão, bolo, cavalo, príncipe, Ravi, coração partido, foto final
- Músicas: End of Beginning 8 bit (principal), Goo Goo Dolls (Sala 4 final)
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
- O garoto da Sala 4 representa alguém específico?
- O furão tem nome?
- Ravi: referência a nome real? Sprite de bebê genérico ou específico?