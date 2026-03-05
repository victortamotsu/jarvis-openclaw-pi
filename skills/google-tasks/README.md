# google-tasks-mcp — MCP Server for Google Tasks

Implements the Model Context Protocol (MCP) interface for Google Tasks API, exposing 5 core tools for task management.

## Tools Exposed

### create_task
Create a new task in Google Tasks.

**Parameters**:
- `title` (string, required): Task title
- `notes` (string, optional): Task description/notes
- `due_date` (string, optional): Due date in ISO format (YYYY-MM-DD)
- `parent_task_id` (string, optional): Parent task ID for subtasks

**Example**:
```json
{
  "title": "Review budget spreadsheet",
  "notes": "Check Q2 expenses for finance review",
  "due_date": "2026-03-15"
}
```

### list_tasks
List tasks from Google Tasks with optional filtering.

**Parameters**:
- `max_results` (number, optional): Max tasks to return (1-100, default: 10)
- `show_completed` (boolean, optional): Include completed tasks (default: false)
- `due_min` (string, optional): Min due date (ISO format)
- `due_max` (string, optional): Max due date (ISO format)

**Example**:
```json
{
  "max_results": 20,
  "show_completed": false,
  "due_min": "2026-03-01",
  "due_max": "2026-03-31"
}
```

### update_task
Update an existing task (title, notes, due date, status).

**Parameters**:
- `task_id` (string, required): Task ID to update
- `title` (string, optional): New title
- `notes` (string, optional): New notes
- `due_date` (string, optional): New due date
- `status` (string, optional): `needsAction` or `completed`

**Example**:
```json
{
  "task_id": "abc123",
  "status": "completed"
}
```

### create_subtask
Create a subtask under a parent task.

**Parameters**:
- `parent_id` (string, required): Parent task ID
- `title` (string, required): Subtask title
- `notes` (string, optional): Subtask notes

**Example**:
```json
{
  "parent_id": "task_abc",
  "title": "Review budget line item",
  "notes": "Check spending against allocation"
}
```

### complete_task
Mark a task as completed.

**Parameters**:
- `task_id` (string, required): Task ID to complete

---

## Installation

```bash
cd skills/google-tasks
npm install
```

## Authentication

Requires Google OAuth 2.0 credentials in `.env`:

```env
GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret
GOOGLE_REFRESH_TOKEN=your_refresh_token
```

To obtain credentials, follow: `docs/PHASE2_OAUTH_SETUP.md`

## Running the Server

```bash
npm start
# or with debug logs:
npm run dev
```

The server listens on stdin/stdout for JSON-RPC 2.0 requests.

## Testing

### Via curl (direct HTTP, requires wrapper):

```bash
# MCP is a stdio protocol, not HTTP
# For testing, use the validate-telegram-bot.sh or invoke via OpenClaw
```

### Via OpenClaw:

The skill is configured in `config/openclaw/openclaw.json` as:
- Type: `mcp_stdio`
- Path: `skills/google-tasks`
- Automatically handles JSON-RPC communication

### Manual Test (stdio):

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | npm start
```

Expected output:
```json
{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"create_task",...}...]}}
```

---

## Integration with Jarvis

This skill is used by User Story 1 (Pendências MVP):

1. **Detection**: Agent receives emails/WhatsApp via Gmail/WhatsApp native skills
2. **Classification**: SOUL.md classifies urgency (INFORMATIVO/ACAO_NECESSARIA/URGENTE/CRITICO)
3. **Deduplication**: Calls `list_tasks` to check for existing task (title+contact 30-day window)
4. **Creation**: If new, calls `create_task` with urgency tags in notes
5. **Alerts**: Telegram notified with classification-specific alert rules (T026)
6. **Completion**: When user replies "ok/feito/resolvido", calls `complete_task` (T061)
7. **Responses**: `/responder <task_id>` handler to suggest replies (T060)

---

## Architecture

```
index.js                  ← Main MCP server, JSON-RPC handler, tool implementations
  ├─ auth.js            ← OAuth2 token refresh
  ├─ package.json       ← Node dependencies
  └─ README.md          ← This file

MCP Protocol Flow:
┌─────────────────────────────────────────────────────┐
│ OpenClaw (client)                                   │
│ ├─ JSONfmt: tools/list → list all 5 tools          │
│ ├─ JSONfmt: tools/call(create_task) → stdin        │
│ └─ Reads: stdout JSON response                      │
└──────────────────┬──────────────────────────────────┘
                   │ (stdin/stdout JSON-RPC 2.0)
┌──────────────────┴──────────────────────────────────┐
│ google-tasks (server)                               │
│ ├─ Parses: tools/call request                       │
│ ├─ Calls: handler(create_task)                      │
│ ├─ OAuth: auto-refreshes token if expired           │
│ ├─ API: POST https://tasks.googleapis.com/tasks/v1  │
│ └─ Outputs: JSON response                           │
└─────────────────────────────────────────────────────┘
```

---

## Error Handling

All tools return structured error responses:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32603,
    "message": "Failed to create task: Invalid credentials"
  }
}
```

Common issues:
- **"Invalid credentials"**: Check GOOGLE_CLIENT_ID/SECRET/REFRESH_TOKEN in .env
- **"No task lists found"**: OAuth token doesn't have Tasks API access
- **"Unknown task"**: Task ID doesn't exist in user's Google Tasks
- **"Token expired"**: OAuth automatically refreshes; if still fails, re-generate token

---

## Performance Notes

- Token refresh: ~500ms per API call (automatic)
- Task creation: ~400-600ms
- Task listing (10 items): ~300-500ms
- Network I/O: Dependent on internet connectivity

For high-volume operations (100+ tasks), batch requests where possible.

---

## Dependencies

- `google-api-nodejs-client@^118.0.0` — Google API client
- `google-auth-library@^9.0.0` — OAuth2 handling
- `dotenv@^16.0.0` — Environment variable loading

---

**Last Updated**: 2026-03-04  
**Status**: Phase 3 (User Story 1 — Pendências MVP)  
**Tasks**: T017-T019, T022-T023
