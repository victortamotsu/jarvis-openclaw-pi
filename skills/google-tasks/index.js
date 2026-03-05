#!/usr/bin/env node

/**
 * Google Tasks MCP Stdio Server
 * 
 * Implements Model Context Protocol (MCP) stdio interface for Google Tasks API.
 * Exposes tools: create_task, list_tasks, update_task, create_subtask, complete_task
 * 
 * Usage: node index.js
 * Communication: JSON-RPC 2.0 over stdin/stdout
 */

import { google } from 'googleapis.js';
import { getAuth } from './auth.js';
import { handleJsonRpc } from './rpc-handler.js';

// ─────────────────────────────────────────────────────────────────────────
// Initialize Google Tasks API client
// ─────────────────────────────────────────────────────────────────────────

let tasksAPI = null;

async function initializeClient() {
  try {
    const auth = await getAuth();
    tasksAPI = google.tasks({
      version: 'v1',
      auth: auth
    });
    console.error('[Google Tasks MCP] Client initialized');
  } catch (err) {
    console.error('[Google Tasks MCP] Failed to initialize client:', err.message);
    process.exit(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tool Implementations
// ─────────────────────────────────────────────────────────────────────────

/**
 * T018: Create a new task in Google Tasks
 * @param {Object} params - Task creation parameters
 * @returns {Promise<Object>} Created task
 */
async function create_task(params) {
  const { title, notes, due_date, parent_task_id } = params;
  
  if (!title) {
    throw new Error('title is required');
  }

  try {
    // Get default task list (first one)
    const lists = await tasksAPI.tasklists.list();
    const defaultListId = lists.data.items?.[0]?.id;
    
    if (!defaultListId) {
      throw new Error('No task lists found');
    }

    // Create task object
    const taskBody = {
      title: title,
      notes: notes || '',
      due: due_date || undefined,
      parent: parent_task_id || undefined,
      status: 'needsAction'
    };

    // Remove undefined fields
    Object.keys(taskBody).forEach(key => 
      taskBody[key] === undefined && delete taskBody[key]
    );

    // Create task via API
    const response = await tasksAPI.tasks.insert({
      tasklist: defaultListId,
      requestBody: taskBody
    });

    return {
      id: response.data.id,
      title: response.data.title,
      status: response.data.status,
      created: new Date().toISOString()
    };
  } catch (err) {
    throw new Error(`Failed to create task: ${err.message}`);
  }
}

/**
 * T018: List tasks from Google Tasks
 * @param {Object} params - List parameters
 * @returns {Promise<Array>} List of tasks
 */
async function list_tasks(params) {
  const { max_results = 10, show_completed = false, due_min, due_max } = params;

  try {
    // Get default task list
    const lists = await tasksAPI.tasklists.list();
    const defaultListId = lists.data.items?.[0]?.id;
    
    if (!defaultListId) {
      throw new Error('No task lists found');
    }

    // List tasks
    const response = await tasksAPI.tasks.list({
      tasklist: defaultListId,
      maxResults: Math.min(max_results, 100),
      showCompleted: show_completed,
      dueMin: due_min,
      dueMax: due_max,
      orderBy: 'dueDate'
    });

    return response.data.items || [];
  } catch (err) {
    throw new Error(`Failed to list tasks: ${err.message}`);
  }
}

/**
 * T018: Update an existing task
 * @param {Object} params - Task update parameters
 * @returns {Promise<Object>} Updated task
 */
async function update_task(params) {
  const { task_id, title, notes, due_date, status } = params;

  if (!task_id) {
    throw new Error('task_id is required');
  }

  try {
    // Get default task list
    const lists = await tasksAPI.tasklists.list();
    const defaultListId = lists.data.items?.[0]?.id;
    
    if (!defaultListId) {
      throw new Error('No task lists found');
    }

    // Build update object
    const updateBody = {
      id: task_id,
      title: title,
      notes: notes,
      due: due_date,
      status: status
    };

    // Remove undefined fields
    Object.keys(updateBody).forEach(key => 
      updateBody[key] === undefined && delete updateBody[key]
    );

    // Update task
    const response = await tasksAPI.tasks.update({
      tasklist: defaultListId,
      task: task_id,
      requestBody: updateBody
    });

    return {
      id: response.data.id,
      title: response.data.title,
      status: response.data.status,
      updated: new Date().toISOString()
    };
  } catch (err) {
    throw new Error(`Failed to update task: ${err.message}`);
  }
}

/**
 * T019: Create a subtask under a parent task
 * @param {Object} params - Subtask parameters
 * @returns {Promise<Object>} Created subtask
 */
async function create_subtask(params) {
  const { parent_id, title, notes } = params;

  if (!parent_id || !title) {
    throw new Error('parent_id and title are required');
  }

  try {
    // Get default task list
    const lists = await tasksAPI.tasklists.list();
    const defaultListId = lists.data.items?.[0]?.id;
    
    if (!defaultListId) {
      throw new Error('No task lists found');
    }

    // Create subtask
    const response = await tasksAPI.tasks.insert({
      tasklist: defaultListId,
      parent: parent_id,
      requestBody: {
        title: title,
        notes: notes || '',
        status: 'needsAction'
      }
    });

    return {
      id: response.data.id,
      parent_id: response.data.parent,
      title: response.data.title,
      status: response.data.status
    };
  } catch (err) {
    throw new Error(`Failed to create subtask: ${err.message}`);
  }
}

/**
 * T018: Complete a task (mark as completed)
 * @param {Object} params - Task completion parameters
 * @returns {Promise<Object>} Completed task
 */
async function complete_task(params) {
  const { task_id } = params;

  if (!task_id) {
    throw new Error('task_id is required');
  }

  try {
    // Get default task list
    const lists = await tasksAPI.tasklists.list();
    const defaultListId = lists.data.items?.[0]?.id;
    
    if (!defaultListId) {
      throw new Error('No task lists found');
    }

    // Update task status to completed
    const response = await tasksAPI.tasks.update({
      tasklist: defaultListId,
      task: task_id,
      requestBody: {
        id: task_id,
        status: 'completed'
      }
    });

    return {
      id: response.data.id,
      status: response.data.status,
      completed: new Date().toISOString()
    };
  } catch (err) {
    throw new Error(`Failed to complete task: ${err.message}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MCP Tool Registry
// ─────────────────────────────────────────────────────────────────────────

const tools = {
  create_task: {
    description: 'Create a new task in Google Tasks with title, optional notes and due date',
    schema: {
      type: 'object',
      properties: {
        title: {
          type: 'string',
          description: 'Task title (required)'
        },
        notes: {
          type: 'string',
          description: 'Task notes or description'
        },
        due_date: {
          type: 'string',
          description: 'Due date in ISO format (YYYY-MM-DD)'
        },
        parent_task_id: {
          type: 'string',
          description: 'Parent task ID for subtasks'
        }
      },
      required: ['title']
    },
    handler: create_task
  },
  
  list_tasks: {
    description: 'List all tasks from Google Tasks with optional filtering',
    schema: {
      type: 'object',
      properties: {
        max_results: {
          type: 'number',
          description: 'Maximum number of tasks to return (default: 10, max: 100)'
        },
        show_completed: {
          type: 'boolean',
          description: 'Include completed tasks in results (default: false)'
        },
        due_min: {
          type: 'string',
          description: 'Minimum due date (ISO format)'
        },
        due_max: {
          type: 'string',
          description: 'Maximum due date (ISO format)'
        }
      }
    },
    handler: list_tasks
  },
  
  update_task: {
    description: 'Update an existing task with new title, notes, or status',
    schema: {
      type: 'object',
      properties: {
        task_id: {
          type: 'string',
          description: 'ID of task to update (required)'
        },
        title: {
          type: 'string',
          description: 'New task title'
        },
        notes: {
          type: 'string',
          description: 'New task notes'
        },
        due_date: {
          type: 'string',
          description: 'New due date (ISO format)'
        },
        status: {
          type: 'string',
          enum: ['needsAction', 'completed'],
          description: 'Task status'
        }
      },
      required: ['task_id']
    },
    handler: update_task
  },
  
  create_subtask: {
    description: 'Create a subtask under a parent task',
    schema: {
      type: 'object',
      properties: {
        parent_id: {
          type: 'string',
          description: 'ID of parent task (required)'
        },
        title: {
          type: 'string',
          description: 'Subtask title (required)'
        },
        notes: {
          type: 'string',
          description: 'Subtask notes'
        }
      },
      required: ['parent_id', 'title']
    },
    handler: create_subtask
  },
  
  complete_task: {
    description: 'Mark a task as completed',
    schema: {
      type: 'object',
      properties: {
        task_id: {
          type: 'string',
          description: 'ID of task to complete (required)'
        }
      },
      required: ['task_id']
    },
    handler: complete_task
  }
};

// ─────────────────────────────────────────────────────────────────────────
// MCP JSON-RPC Handler
// ─────────────────────────────────────────────────────────────────────────

async function handleRequest(request) {
  const { jsonrpc, id, method, params } = request;

  if (jsonrpc !== '2.0') {
    return {
      jsonrpc: '2.0',
      id,
      error: {
        code: -32600,
        message: 'Invalid Request'
      }
    };
  }

  // Handle tool calls
  if (method === 'tools/call') {
    const toolName = params.name;
    const tool = tools[toolName];

    if (!tool) {
      return {
        jsonrpc: '2.0',
        id,
        error: {
          code: -32601,
          message: `Unknown tool: ${toolName}`
        }
      };
    }

    try {
      const result = await tool.handler(params.arguments || {});
      return {
        jsonrpc: '2.0',
        id,
        result: {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2)
            }
          ]
        }
      };
    } catch (err) {
      return {
        jsonrpc: '2.0',
        id,
        error: {
          code: -32603,
          message: err.message
        }
      };
    }
  }

  // Handle tool discovery
  if (method === 'tools/list') {
    return {
      jsonrpc: '2.0',
      id,
      result: {
        tools: Object.entries(tools).map(([name, def]) => ({
          name,
          description: def.description,
          inputSchema: def.schema
        }))
      }
    };
  }

  // Handle initialization
  if (method === 'initialize') {
    return {
      jsonrpc: '2.0',
      id,
      result: {
        protocolVersion: '2024-01-01',
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: 'google-tasks-mcp',
          version: '1.0.0'
        }
      }
    };
  }

  return {
    jsonrpc: '2.0',
    id,
    error: {
      code: -32601,
      message: `Unknown method: ${method}`
    }
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Stdio Interface Setup
// ─────────────────────────────────────────────────────────────────────────

async function main() {
  // Initialize Google Tasks client
  await initializeClient();

  // Setup stdin/stdout handlers for JSON-RPC
  let buffer = '';

  process.stdin.setEncoding('utf-8');
  process.stdin.on('data', async (chunk) => {
    buffer += chunk;

    // Process complete JSON-RPC messages
    let lines = buffer.split('\n');
    buffer = lines.pop() || ''; // Keep incomplete line in buffer

    for (const line of lines) {
      if (line.trim()) {
        try {
          const request = JSON.parse(line);
          const response = await handleRequest(request);
          process.stdout.write(JSON.stringify(response) + '\n');
        } catch (err) {
          console.error('[Google Tasks MCP] Parse error:', err);
          process.stdout.write(JSON.stringify({
            jsonrpc: '2.0',
            id: null,
            error: {
              code: -32700,
              message: 'Parse error',
              data: err.message
            }
          }) + '\n');
        }
      }
    }
  });

  process.stdin.on('end', () => {
    console.error('[Google Tasks MCP] Stdin closed, exiting');
    process.exit(0);
  });

  console.error('[Google Tasks MCP] Server started, awaiting requests...');
}

// Start the server
main().catch(err => {
  console.error('[Google Tasks MCP] Fatal error:', err);
  process.exit(1);
});
