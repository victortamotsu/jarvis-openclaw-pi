# Phase 3 — User Story 1 Handlers (T026, T060, T061)

Complete documentation for Pendências advanced features.

## T026: Notification Grouping Rules

Implementation of urgency-based alert filtering and batching.

### Rule Table

| Urgency | Behavior | Example | Telegram Marker |
|---------|----------|---------|-----------------|
| INFORMATIVO | Daily digest 22h (grouped) | "SELIC caiu para 10%" | 📰 No push |
| ACAO_NECESSARIA | Individual alert, direct | "Lembrete: reuni&#227;o amanh&#227;" | 🔔 Direct |
| URGENTE | Immediate alert | "Confirma at&#233; hoje?" | ⚠️ Immediate |
| CRITICO | Immediate + repeat 15min | "Erro import&#227;&#227;o de fatura" | 🚨 + 📢 every 15m |

### Implementation

```
Store INFORMATIVO in temporary queue with timestamp
At 22:00 UTC:
  - Compile all INFORMATIVO items
  - Format as markdown bullet list
  - Send single digest message to Victor
  - Clear queue

For ACAO_NECESSARIA/URGENTE:
  - Send immediately via Telegram
  - Remove from INFORMATIVO queue if present

For CRITICO:
  - Send immediately
  - Schedule recurring reminder (cron) every 15 minutes
  - Stop repetition when Victor replies "confirmado" / "entendido" / "recebido"
```

### Detection of CRITICO Acknowledgment

Monitor incoming messages for keywords:
- "confirmado"
- "entendido"
- "recebido"
- "ok cr&#237;tico"

When detected:
1. Copy task ID from most recent CRITICO alert
2. Lookup original task
3. Mark as acknowledged (add note: "[acknowledged] TIMESTAMP")
4. Cancel scheduler for this alert

---

## T061: Auto-Complete Detection

Automatically mark tasks as completed when user sends confirmatory messages.

### Trigger Keywords

```
"ok"           → casual confirmation
"feito"        → completed actions
"resolvido"    → problem solved
"confirmado"   → formal confirmation
"tá ok"        → casual approval
"pode ser"     → agreement/approval
"beleza"       → Brazilian: OK
```

### Algorithm

```
1. Process new message from Victor
2. Detect keyword from list above
3. Extract context:
   - Message subject/topic
   - Sender/contact if reply
   - Time of message
4. Find matching open task:
   - list_tasks(show_completed=false)
   - Search by: title contains topic + notes mentions contact
   - Match confidence: high if exact subject match
5. If match found with high confidence:
   - Call complete_task(task_id)
   - Set status "completed"
   - Add note: "[AUTO-COMPLETED] TIMESTAMP: User said 'KEYWORD'"
   - Send feedback to Victor: ✅ Task closed: "TITLE"
6. If match found with LOW confidence:
   - Ask Victor: "Complete task 'XYZ'?" (yes/no buttons)
   - Wait for confirmation before calling complete_task
```

### Example

```
Timeline:

14:30 → Agent sends task: "Confirmar reunião segunda | @Maria" (ACAO_NECESSARIA)
14:32 → Victor replies in Telegram: "ok, confirmado"
14:33 → Agent detects "ok" + "confirmado" 
       → Searches: tasks with "reunião" + "Maria"
       → Finds task "Confirmar reunião segunda | @Maria"
       → Calls complete_task
       → Sends: ✅ Reunião segunda com Maria - CONFIRMADA
```

---

## T060: Suggestion Handler (`/responder`)

Advanced handler to generate intelligent response suggestions via Telegram.

### Command Format

```
/responder <task_id>
/responder 12345abc
```

### Workflow

```
1. User sends: /responder 12345

2. Agent validates:
   - Task ID exists in Google Tasks
   - Task is still open (status != completed)

3. Extract task context:
   - Title: "Reunião com Maria - segunda?"
   - Contact: @Maria (from notes)
   - History: [timestamps of previous messages]
   - Category/tags: work, meeting, etc.

4. Determine question type:
   IF title contains "?" OR notes have "pergunta"/"help":
      → Question/Request type
      → Call Tavily for current information (time-sensitive data)
      → Generate 2-3 response suggestions
   ELIF title contains date/time:
      → Confirmation type
      → Generate formal/informal confirmation options
   ELIF title mentions "erro"/"problema":
      → Problem/Solution type
      → research solution approaches
      → Generate 2-3 troubleshooting options

5. Generate suggestions (2-3 variants):
   ① Formal/Professional tone
   ② Casual/Friendly tone
   ③ Technical/Detailed (if applicable)

6. Format response for Telegram:
   ```
   Task: "Reunião com Maria - segunda?"
   Contact: Maria
   
   Response suggestions:
   ① Sim, segunda às 14:00 fica ótimo. Confirmo. [Formal]
   ② Opa, segunda tá perfeito, vamo marcar 14h? [Casual]
   ③ Segunda funciona bem para mim. Prefiro às 14h se possível. [Middle ground]
   
   Choose which? (①/②/③ or custom)
   ```

7. Handle Victor's choice:
   IF Victor clicks emoji (①/②/③):
      → Copy selected suggestion to task notes
      → Ask: "Send now?" (yes/no)
      → If yes: send message to Maria
      → If no: save draft in task
      → Mark task as "draft_response_ready"
   ELIF Victor sends custom text:
      → Use that instead
      → Offer same save/send options

8. After sending:
   → Mark task notes: "[RESPONDED] TIMESTAMP: Enviar ..."
   → Keep task open (Victor decides when to close)
   → Or auto-complete if response indicates closure
```

### Example Conversation

```
14:00 Victor: /responder task_xyz
14:01 Jarvis:
   Task: "Como reparar carburador do carro?"
   Type: Problem/Help Request
   
   Suggestions:
   ① "Vou pesquisar e te envio um tutorial. Demora umas 2h?" [Promise timeline]
   ② "De que marca é o carro? Já tive problema Similar." [Seek clarification]
   ③ "Melhor chamar o mecânico, não sou expert em motor" [Honest admission]
   
   Choose? (①/②/③ or type your own)

14:02 Victor: ③ mas muda pra "Preciso chamar o mecânico, dá ruim tentar sozinho"
14:03 Jarvis:
   Draft saved: "Preciso chamar o mecânico, dá ruim tentar sozinho"
   
   Send to [contact] now? (yes/no)
14:04 Victor: yes
14:05 Jarvis: ✅ Message sent! Task remains open for follow-up.
```

---

## Integration with Skill 1 Workflow

These handlers enhance the base Skill 1 (Pendências) flow:

```
Incoming message (email/WhatsApp)
  ↓
T022: Classify urgency
  ↓
T023: Deduplicate (list_tasks, fuzzy match)
  ↓
Create/Update task
  ↓
T026: Send alert based on urgency level
      - If INFORMATIVO: queue for 22h digest
      - If ACAO/URGENTE/CRITICO: send immediately
      - If CRITICO: schedule 15min rechecks
  ↓
T061: Monitor for auto-completion triggers
      - If user says "ok"/"feito": complete_task automatically
  ↓
T060: On demand, user can request suggestions:
      - /responder <id> → Generate intelligent reply options
```

---

## Testing (T027: E2E Validation)

Full end-to-end test scenario:

```
Scenario 1: INFORMATIVO + Digest
  1. Send 3 emails with generic info (news, data)
  2. Verify: No push alerts received
  3. At 22:00: Receive single digest with 3 items
  ✅ Pass

Scenario 2: ACAO_NECESSARIA + Direct Alert
  1. Send email: "Can we reschedule for Friday?"
  2. Task created: "Reschedule for Friday | @Sender"
  3. Alert received immediately: 🔔 Reschedule for Friday
  ✅ Pass

Scenario 3: URGENTE + Confirmation
  1. Send: "Confirm by noon?"
  2. Task created with due_date = today 12:00
  3. Alert: ⚠️ Confirm by noon
  4. Victor replies: "ok, confirmado"
  5. Task auto-completed
  6. Feedback: ✅ Task closed
  ✅ Pass

Scenario 4: CRITICO + Repetition
  1. Trigger error alert: CRITICO "Import failed"
  2. Alert sent: 🚨 CRITICAL: Import failed
  3. Wait 15 minutes
  4. Receive 2nd alert (📢 reminder)
  5. Victor replies: "entendido"
  6. Repetition stops
  ✅ Pass

Scenario 5: /responder Handler
  1. Open task: "Reunião com Maria - segunda?" (task_123)
  2. Send: /responder task_123
  3. Receive 3 suggestion options
  4. Choose option ①
  5. Draft saved
  6. Confirm send
  7. Message delivered to Maria
  ✅ Pass
```

---

**Status**: Phase 3 (User Story 1)  
**Tasks**: T026, T060, T061, T027  
**Last Updated**: 2026-03-04
