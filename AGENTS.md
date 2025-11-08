# Slack MCP Server - AI Agent Installation Guide

This guide provides comprehensive installation instructions for AI agents installing the Slack MCP server in OI OS (Brain Trust 4) environments, as well as end-user setup instructions.

## Table of Contents

1. [AI Agent Quick Installation](#ai-agent-quick-installation)
2. [Prerequisites](#prerequisites)
3. [Full Installation Steps](#full-installation-steps)
4. [Building the Server](#building-the-server)
5. [Configuring Authentication](#configuring-authentication)
6. [Connecting to OI OS](#connecting-to-oi-os)
7. [Syncing Cache Files](#syncing-cache-files)
8. [Configuring Parameter Extractors](#configuring-parameter-extractors)
9. [Creating Parameter Rules](#creating-parameter-rules)
10. [Creating Intent Mappings](#creating-intent-mappings)
11. [End User Setup](#end-user-setup)
12. [Verification & Testing](#verification--testing)
13. [Troubleshooting](#troubleshooting)
14. [Known Issues & Fixes](#known-issues--fixes)

---

## AI Agent Quick Installation

**⚠️ For AI Agents: Use Direct Calls for Reliability**

AI agents should prefer **direct `brain-trust4 call` commands** over natural language queries for maximum reliability. Natural language commands can timeout or have parameter extraction issues. Direct calls bypass intent mapping and parameter extraction, providing consistent results.

**Example:**
```bash
# ✅ RECOMMENDED for AI agents: Direct call
./brain-trust4 call slack-mcp-server conversations_add_message '{"channel_id": "#dev", "payload": "Hello"}'

# ⚠️ FALLBACK: Natural language (may timeout or fail parameter extraction)
./oi "slack post dev Hello"
```

For AI agents using OI OS, execute the following commands:

```bash
# 1. Clone the repository (if not already installed)
# NOTE: The 'install' command doesn't work well for Go servers that need building
# Manual clone + build is required
git clone https://github.com/OI-OS/slack-mcp-server.git MCP-servers/slack-mcp-server
cd MCP-servers/slack-mcp-server

# 2. Build the server
make build

# 3. Configure authentication in project root .env file
# Add to .env (in project root, not in slack-mcp-server directory):
# SLACK_MCP_XOXC_TOKEN=xoxc-your-token-here
# SLACK_MCP_XOXD_TOKEN=xoxd-your-token-here
# SLACK_MCP_ADD_MESSAGE_TOOL=true

# 4. Connect the server to OI OS
# NOTE: brain-trust4 automatically loads .env file from project root
cd ../../
./brain-trust4 connect slack-mcp-server ./MCP-servers/slack-mcp-server/build/slack-mcp-server

# 5. Sync cache files (required for full functionality)
./MCP-servers/slack-mcp-server/sync-slack-cache.sh

# 6. Create intent mappings and parameter rules (single optimized transaction)
sqlite3 brain-trust4.db << 'SQL'
BEGIN TRANSACTION;

-- Intent mappings (all 21 mappings for 5 tools)
INSERT OR REPLACE INTO intent_mappings (keyword, server_name, tool_name, priority) VALUES 
('slack list channels', 'slack-mcp-server', 'channels_list', 10),
('slack channels', 'slack-mcp-server', 'channels_list', 10),
('slack show channels', 'slack-mcp-server', 'channels_list', 10),
('slack get channels', 'slack-mcp-server', 'channels_list', 10),
('slack channel history', 'slack-mcp-server', 'conversations_history', 10),
('slack get history', 'slack-mcp-server', 'conversations_history', 10),
('slack show history', 'slack-mcp-server', 'conversations_history', 10),
('slack messages', 'slack-mcp-server', 'conversations_history', 10),
('slack recent messages', 'slack-mcp-server', 'conversations_history', 10),
('slack thread replies', 'slack-mcp-server', 'conversations_replies', 10),
('slack get replies', 'slack-mcp-server', 'conversations_replies', 10),
('slack show replies', 'slack-mcp-server', 'conversations_replies', 10),
('slack thread messages', 'slack-mcp-server', 'conversations_replies', 10),
('slack post message', 'slack-mcp-server', 'conversations_add_message', 10),
('slack send message', 'slack-mcp-server', 'conversations_add_message', 10),
('slack write message', 'slack-mcp-server', 'conversations_add_message', 10),
('slack create post', 'slack-mcp-server', 'conversations_add_message', 10),
('slack post', 'slack-mcp-server', 'conversations_add_message', 10),
('slack search messages', 'slack-mcp-server', 'conversations_search_messages', 10),
('slack search', 'slack-mcp-server', 'conversations_search_messages', 10),
('slack find messages', 'slack-mcp-server', 'conversations_search_messages', 10);

-- Parameter rules (all 5 tools)
-- conversations_add_message: channel_id and payload are REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_add_message', 'slack-mcp-server::conversations_add_message', '["channel_id", "payload"]',
'{"channel_id": {"FromQuery": "slack-mcp-server::conversations_add_message.channel_id"}, "payload": {"FromQuery": "slack-mcp-server::conversations_add_message.payload"}, "content_type": {"FromQuery": "slack-mcp-server::conversations_add_message.content_type"}, "thread_ts": {"FromQuery": "thread_ts"}}', '[]');

-- channels_list: channel_types is REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'channels_list', 'slack-mcp-server::channels_list', '["channel_types"]',
'{"channel_types": {"FromQuery": "slack-mcp-server::channels_list.channel_types"}, "limit": {"FromQuery": "slack-mcp-server::channels_list.limit"}, "sort": {"FromQuery": "sort"}, "cursor": {"FromQuery": "cursor"}}', '[]');

-- conversations_history: channel_id is REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_history', 'slack-mcp-server::conversations_history', '["channel_id"]',
'{"channel_id": {"FromQuery": "slack-mcp-server::conversations_history.channel_id"}, "limit": {"FromQuery": "slack-mcp-server::conversations_history.limit"}, "cursor": {"FromQuery": "cursor"}, "include_activity_messages": {"FromQuery": "include_activity_messages"}}', '[]');

-- conversations_replies: channel_id and thread_ts are REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_replies', 'slack-mcp-server::conversations_replies', '["channel_id", "thread_ts"]',
'{"channel_id": {"FromQuery": "slack-mcp-server::conversations_replies.channel_id"}, "thread_ts": {"FromQuery": "slack-mcp-server::conversations_replies.thread_ts"}, "limit": {"FromQuery": "slack-mcp-server::conversations_replies.limit"}, "cursor": {"FromQuery": "cursor"}, "include_activity_messages": {"FromQuery": "include_activity_messages"}}', '[]');

-- conversations_search_messages: no required fields (all optional)
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_search_messages', 'slack-mcp-server::conversations_search_messages', '[]',
'{"search_query": {"FromQuery": "slack-mcp-server::conversations_search_messages.search_query"}, "limit": {"FromQuery": "slack-mcp-server::conversations_search_messages.limit"}, "filter_in_channel": {"FromQuery": "filter_in_channel"}, "filter_users_from": {"FromQuery": "filter_users_from"}, "filter_date_after": {"FromQuery": "filter_date_after"}, "filter_date_before": {"FromQuery": "filter_date_before"}, "cursor": {"FromQuery": "cursor"}}', '[]');

COMMIT;
SQL

# 7. Generate/append parameter extractors to TOML file (REQUIRED for parameter extraction)
# ⚠️ CRITICAL: OI OS loads parameter_extractors.toml.default, not parameter_extractors.toml
# Add patterns to parameter_extractors.toml.default in project root
cat >> parameter_extractors.toml.default << 'SLACK_EXTRACTORS'

# ============================================================================
# SLACK MCP SERVER EXTRACTION PATTERNS
# ============================================================================

# Channel ID - Extract Slack channel ID (Cxxxxxxxxxx), channel name (#general), or bare name (dev)
"channel_id" = "regex:(C[A-Z0-9]{9,}|#[\\w-]+|@[\\w-]+)"
"Extract channel ID from query" = "regex:(C[A-Z0-9]{9,}|#[\\w-]+|@[\\w-]+)"
"slack-mcp-server::conversations_add_message.channel_id" = "regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*([#@]?[\\w-]+|C[A-Z0-9]{9,})"
"slack-mcp-server::conversations_add_message.Extract channel" = "regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*([#@]?[\\w-]+|C[A-Z0-9]{9,})"

# Message payload/text - Extract message content after channel
"payload" = "keyword:after_message"
"Extract message payload from query" = "remove:post,send,message,slack,to,in,channel"
"slack-mcp-server::conversations_add_message.payload" = "transform:regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*(?:[#@]?[\\w-]+|C[A-Z0-9]{9,})\\s+(.+)$|trim"
"slack-mcp-server::conversations_add_message.Extract message text" = "transform:regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*(?:[#@]?[\\w-]+|C[A-Z0-9]{9,})\\s+(.+)$|trim"

# Thread timestamp - Extract Slack thread timestamp (format: 1234567890.123456)
"thread_ts" = "regex:\\d{10}\\.\\d{6}"
"Extract thread timestamp from query" = "regex:\\d{10}\\.\\d{6}"

# Content type - Default to text/markdown
"content_type" = "default:text/markdown"

# Channel types for channels_list
"channel_types" = "regex:(mpim|im|public_channel|private_channel)(?:,(?:mpim|im|public_channel|private_channel))*"
"Extract channel types from query" = "regex:(mpim|im|public_channel|private_channel)(?:,(?:mpim|im|public_channel|private_channel))*"

# Cursor for pagination
"cursor" = "regex:[A-Za-z0-9=]+"
"Extract cursor from query" = "regex:[A-Za-z0-9=]+"

# Limit with defaults (different for different tools)
"slack-mcp-server::channels_list.limit" = "conditional:if_matches:\\d+|then:regex:\\b\\d+\\b|else:default:100"
"slack-mcp-server::conversations_history.limit" = "conditional:if_matches:\\d+|then:regex:\\b\\d+\\b|else:default:1d"
"slack-mcp-server::conversations_search_messages.limit" = "conditional:if_matches:\\d+|then:regex:\\b\\d+\\b|else:default:20"

# Include activity messages (boolean)
"include_activity_messages" = "conditional:if_contains:activity|then:default:true|else:default:false"

# Search query
"search_query" = "remove:search,find,slack,messages"
"Extract search query from query" = "remove:search,find,slack,messages"

# Date filters
"filter_date_after" = "regex:(?:after|since|from)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+|Today|Yesterday)"
"filter_date_before" = "regex:(?:before|until|to)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+|Today|Yesterday)"
"filter_date_during" = "regex:(?:during|in)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+)"
"filter_date_on" = "regex:(?:on|date)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+|Today|Yesterday)"

# Filter in channel
"filter_in_channel" = "regex:(?:in|channel)\\s+(C[A-Z0-9]{9,}|G[A-Z0-9]{9,}|#[\\w-]+)"

# Filter in DM/MPIM
"filter_in_im_or_mpim" = "regex:(?:dm|direct|mpim)\\s+(D[A-Z0-9]{9,}|@[\\w-]+)"

# Filter users
"filter_users_from" = "regex:(?:from|user)\\s+(U[A-Z0-9]{9,}|@[\\w-]+)"
"filter_users_with" = "regex:(?:with|user)\\s+(U[A-Z0-9]{9,}|@[\\w-]+)"

# Filter threads only (boolean)
"filter_threads_only" = "conditional:if_contains:thread|then:default:true|else:default:false"

# Sort for channels_list
"sort" = "conditional:if_contains:popularity|then:default:popularity|else:default:"
SLACK_EXTRACTORS
```

**Important Notes:**
- **`.env` file auto-loaded**: `brain-trust4 connect` automatically finds and loads `.env` from project root (matching pattern used for other config files like `parameter_extractors.toml`)
- **For AI Agents**: Prefer direct calls (`./brain-trust4 call`) over natural language commands for reliability
- **For End Users**: Natural language commands (`./oi "slack post..."`) provide better UX but may timeout
- **Cache sync is critical**: Enables channel lookups by name (`#channel-name`) and user lookups by handle (`@username`)
- **Direct Calls**: Use `./brain-trust4 call slack-mcp-server tool-name '{"param": "value"}'` to bypass intent mapping and parameter extraction

---

## Prerequisites

### Required Software

- **Go** (1.21+ recommended)
- **Make** (for building)
- **OI OS / Brain Trust 4** installed and running
- **Slack workspace access** with authentication tokens

### Required Slack Tokens

You need one of the following authentication methods:

1. **Browser Tokens (xoxc/xoxd)** - Recommended for OI OS
   - `SLACK_MCP_XOXC_TOKEN`: Slack browser token (`xoxc-...`)
   - `SLACK_MCP_XOXD_TOKEN`: Slack browser cookie (`xoxd-...`)

2. **OAuth Token (xoxp)** - Alternative
   - `SLACK_MCP_XOXP_TOKEN`: User OAuth token (`xoxp-...`)

**How to get tokens:** See the [Authentication Setup Guide](docs/01-authentication-setup.md) in the repository.

---

## Full Installation Steps

### Step 1: Clone the Repository

```bash
# From your OI OS project root
git clone https://github.com/korotovsky/slack-mcp-server.git MCP-servers/slack-mcp-server
cd MCP-servers/slack-mcp-server
```

**Alternative (if already installed):**
```bash
cd MCP-servers/slack-mcp-server
git pull  # Update if needed
```

---

## Building the Server

### Step 1: Navigate to Server Directory

```bash
cd MCP-servers/slack-mcp-server
```

### Step 2: Build the Server

```bash
make build
```

This creates the `build/slack-mcp-server` executable.

### Step 3: Verify Build

```bash
ls -lh build/slack-mcp-server
# Should show the executable file
```

---

## Configuring Authentication

### Step 1: Get Slack Tokens

Extract tokens from your Slack workspace. See the [Authentication Setup Guide](docs/01-authentication-setup.md) for detailed instructions.

You'll need:
- `xoxc-...` token (browser token)
- `xoxd-...` token (browser cookie)

Or alternatively:
- `xoxp-...` token (OAuth token)

### Step 2: Configure Environment Variables

Add to your OI OS project root `.env` file:

```bash
# Required: Slack authentication tokens (use xoxc/xoxd OR xoxp)
SLACK_MCP_XOXC_TOKEN=xoxc-your-token-here
SLACK_MCP_XOXD_TOKEN=xoxd-your-token-here

# OR use OAuth token instead:
# SLACK_MCP_XOXP_TOKEN=xoxp-your-oauth-token-here

# Required: Enable message posting (set to true for all channels)
SLACK_MCP_ADD_MESSAGE_TOOL=true

# Optional: Restrict message posting to specific channels
# SLACK_MCP_ADD_MESSAGE_TOOL=C09QF4P842G,C08ABC1234D

# Optional: Cache file paths (defaults shown)
# SLACK_MCP_USERS_CACHE=.users_cache.json
# SLACK_MCP_CHANNELS_CACHE=.channels_cache_v2.json

# Optional: Logging
# SLACK_MCP_LOG_LEVEL=info
```

**Important Security Notes:**
- Never commit `.env` files to version control
- Tokens provide full access to your Slack workspace
- Use channel restrictions (`SLACK_MCP_ADD_MESSAGE_TOOL=C1234567890`) for safety

---

## Connecting to OI OS

### Step 1: Verify Build Location

```bash
cd MCP-servers/slack-mcp-server
ls -lh build/slack-mcp-server
# Ensure the binary exists
```

### Step 2: Connect the Server

From your OI OS project root:

```bash
./brain-trust4 connect slack-mcp-server ./MCP-servers/slack-mcp-server/build/slack-mcp-server
```

**Note:** The `brain-trust4 connect` command automatically finds and loads `.env` file from the project root, matching the pattern used for other config files like `parameter_extractors.toml`. Environment variables (`SLACK_MCP_XOXC_TOKEN`, `SLACK_MCP_XOXD_TOKEN`, etc.) will be automatically available to the server process.

### Step 3: Verify Connection

```bash
./oi list
# Should show "slack-mcp-server" in the server list

./oi status slack-mcp-server
# Should show server status and capabilities

# Test with direct call (most reliable method)
./brain-trust4 call slack-mcp-server channels_list '{"channel_types": "public_channel"}'
```

---

## Syncing Cache Files

**Critical Step:** The cache sync is required for full functionality. Without it:
- Channel lookups by name (`#channel-name`) won't work
- User lookups by handle (`@username`) won't work
- The `channels_list` tool won't function properly

### Step 1: Run Cache Sync Script

From your OI OS project root:

```bash
./MCP-servers/slack-mcp-server/sync-slack-cache.sh
```

The script will:
- Load environment variables from `.env`
- Start the Slack MCP server
- Trigger `channels_list` to sync cache
- Create `.users_cache.json` and `.channels_cache_v2.json` in project root
- Wait ~90 seconds for sync to complete

### Step 2: Verify Cache Files

```bash
ls -lh .users_cache.json .channels_cache_v2.json
# Both files should exist and have content
```

### Step 3: Verify Cache Contents

```bash
# Check users cache
cat .users_cache.json | python3 -m json.tool | head -20

# Check channels cache
cat .channels_cache_v2.json | python3 -m json.tool | head -20
```

**Cache Limitations:**
- Without users cache: No user lookups by handle, limited functionality
- Without channels cache: `channels_list` tool won't work, limited channel lookups
- With both caches: Full functionality enabled

---

## Configuring Parameter Extractors

Parameter extractors allow OI OS to automatically extract tool parameters from natural language queries.

**⚠️ CRITICAL: File Loading Priority**

OI OS loads parameter extractors from `parameter_extractors.toml.default` in the project root, **not** from `parameter_extractors.toml`. The system prioritizes the `.default` file, so patterns must be added there for them to be loaded.

**NOTE (Backup Option)**: For direct tool calls bypassing intent mapping and parameter extraction, use: `./brain-trust4 call slack-mcp-server tool-name '{"param": "value"}'`

### Location

Add to: `parameter_extractors.toml.default` in your OI OS project root (this is the file that's actually loaded).

### Slack Parameter Extractors

```toml
# ============================================================================
# SLACK MCP SERVER EXTRACTION PATTERNS
# ============================================================================

# Channel ID - Extract Slack channel ID (Cxxxxxxxxxx), channel name (#general), or bare name (dev)
# Supports: "slack post dev message", "slack post #dev message", "slack post C09QF4P842G message"
"channel_id" = "regex:(C[A-Z0-9]{9,}|#[\\w-]+|@[\\w-]+)"
"Extract channel ID from query" = "regex:(C[A-Z0-9]{9,}|#[\\w-]+|@[\\w-]+)"
"slack-mcp-server::conversations_add_message.channel_id" = "regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*([#@]?[\\w-]+|C[A-Z0-9]{9,})"
"slack-mcp-server::conversations_add_message.Extract channel" = "regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*([#@]?[\\w-]+|C[A-Z0-9]{9,})"

# Message payload/text - Extract message content after channel
# Supports: "slack post dev easy as pie" → extracts "easy as pie"
"payload" = "keyword:after_message"
"Extract message payload from query" = "remove:post,send,message,slack,to,in,channel"
"slack-mcp-server::conversations_add_message.payload" = "transform:regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*(?:[#@]?[\\w-]+|C[A-Z0-9]{9,})\\s+(.+)$|trim"
"slack-mcp-server::conversations_add_message.Extract message text" = "transform:regex:(?:slack\\s+)?(?:post|send|message|write|create)\\s+(?:to|in|channel|#)?\\s*(?:[#@]?[\\w-]+|C[A-Z0-9]{9,})\\s+(.+)$|trim"

# Thread timestamp - Extract Slack thread timestamp (format: 1234567890.123456)
"thread_ts" = "regex:\\d{10}\\.\\d{6}"
"Extract thread timestamp from query" = "regex:\\d{10}\\.\\d{6}"

# Content type - Default to text/markdown
"content_type" = "default:text/markdown"

# Channel types for channels_list
"channel_types" = "regex:(mpim|im|public_channel|private_channel)(?:,(?:mpim|im|public_channel|private_channel))*"
"Extract channel types from query" = "regex:(mpim|im|public_channel|private_channel)(?:,(?:mpim|im|public_channel|private_channel))*"

# Cursor for pagination
"cursor" = "regex:[A-Za-z0-9=]+"
"Extract cursor from query" = "regex:[A-Za-z0-9=]+"

# Limit with defaults (different for different tools)
"slack-mcp-server::channels_list.limit" = "conditional:if_matches:\\d+|then:regex:\\b\\d+\\b|else:default:100"
"slack-mcp-server::conversations_history.limit" = "conditional:if_matches:\\d+|then:regex:\\b\\d+\\b|else:default:1d"
"slack-mcp-server::conversations_search_messages.limit" = "conditional:if_matches:\\d+|then:regex:\\b\\d+\\b|else:default:20"

# Include activity messages (boolean)
"include_activity_messages" = "conditional:if_contains:activity|then:default:true|else:default:false"

# Search query
"search_query" = "remove:search,find,slack,messages"
"Extract search query from query" = "remove:search,find,slack,messages"

# Date filters
"filter_date_after" = "regex:(?:after|since|from)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+|Today|Yesterday)"
"filter_date_before" = "regex:(?:before|until|to)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+|Today|Yesterday)"
"filter_date_during" = "regex:(?:during|in)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+)"
"filter_date_on" = "regex:(?:on|date)\\s+(\\d{4}-\\d{2}-\\d{2}|[A-Za-z]+|Today|Yesterday)"

# Filter in channel
"filter_in_channel" = "regex:(?:in|channel)\\s+(C[A-Z0-9]{9,}|G[A-Z0-9]{9,}|#[\\w-]+)"

# Filter in DM/MPIM
"filter_in_im_or_mpim" = "regex:(?:dm|direct|mpim)\\s+(D[A-Z0-9]{9,}|@[\\w-]+)"

# Filter users
"filter_users_from" = "regex:(?:from|user)\\s+(U[A-Z0-9]{9,}|@[\\w-]+)"
"filter_users_with" = "regex:(?:with|user)\\s+(U[A-Z0-9]{9,}|@[\\w-]+)"

# Filter threads only (boolean)
"filter_threads_only" = "conditional:if_contains:thread|then:default:true|else:default:false"

# Sort for channels_list
"sort" = "conditional:if_contains:popularity|then:default:popularity|else:default:"
```

### Adding to parameter_extractors.toml.default

**⚠️ IMPORTANT**: Add patterns to `parameter_extractors.toml.default`, not `parameter_extractors.toml`.

You can either:
1. **Manual Edit**: Open `parameter_extractors.toml.default` and add the patterns above
2. **Append Script** (for AI agents):
   ```bash
   cat >> parameter_extractors.toml.default << 'SLACK_EXTRACTORS'
   # Slack patterns (paste patterns above)
   SLACK_EXTRACTORS
   ```

---

## Creating Parameter Rules

**⚠️ CRITICAL: Parameter rules must be created in the database for parameter extraction to work.**

Parameter rules define which fields are required and how to extract them from natural language queries. The OI OS parameter engine **only extracts required fields** - optional fields are skipped even if extractors exist in `parameter_extractors.toml`.

### Why Parameter Rules Are Needed

- **Required fields are extracted**: The parameter engine processes required fields and invokes their extractors
- **Optional fields are skipped**: Optional fields are ignored during parameter extraction, even if extractors exist
- **Database-driven**: Parameter rules are stored in the `parameter_rules` table in `brain-trust4.db`

### Creating Parameter Rules

Run this optimized SQL transaction to create all parameter rules in a single operation:

```sql
BEGIN TRANSACTION;
-- conversations_add_message: channel_id and payload are REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_add_message', 'slack-mcp-server::conversations_add_message', '["channel_id", "payload"]',
'{"channel_id": {"FromQuery": "slack-mcp-server::conversations_add_message.channel_id"}, "payload": {"FromQuery": "slack-mcp-server::conversations_add_message.payload"}, "content_type": {"FromQuery": "slack-mcp-server::conversations_add_message.content_type"}, "thread_ts": {"FromQuery": "thread_ts"}}', '[]');

-- channels_list: channel_types is REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'channels_list', 'slack-mcp-server::channels_list', '["channel_types"]',
'{"channel_types": {"FromQuery": "slack-mcp-server::channels_list.channel_types"}, "limit": {"FromQuery": "slack-mcp-server::channels_list.limit"}, "sort": {"FromQuery": "sort"}, "cursor": {"FromQuery": "cursor"}}', '[]');

-- conversations_history: channel_id is REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_history', 'slack-mcp-server::conversations_history', '["channel_id"]',
'{"channel_id": {"FromQuery": "slack-mcp-server::conversations_history.channel_id"}, "limit": {"FromQuery": "slack-mcp-server::conversations_history.limit"}, "cursor": {"FromQuery": "cursor"}, "include_activity_messages": {"FromQuery": "include_activity_messages"}}', '[]');

-- conversations_replies: channel_id and thread_ts are REQUIRED
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_replies', 'slack-mcp-server::conversations_replies', '["channel_id", "thread_ts"]',
'{"channel_id": {"FromQuery": "slack-mcp-server::conversations_replies.channel_id"}, "thread_ts": {"FromQuery": "slack-mcp-server::conversations_replies.thread_ts"}, "limit": {"FromQuery": "slack-mcp-server::conversations_replies.limit"}, "cursor": {"FromQuery": "cursor"}, "include_activity_messages": {"FromQuery": "include_activity_messages"}}', '[]');

-- conversations_search_messages: no required fields (all optional)
INSERT OR REPLACE INTO parameter_rules (server_name, tool_name, tool_signature, required_fields, field_generators, patterns) VALUES
('slack-mcp-server', 'conversations_search_messages', 'slack-mcp-server::conversations_search_messages', '[]',
'{"search_query": {"FromQuery": "slack-mcp-server::conversations_search_messages.search_query"}, "limit": {"FromQuery": "slack-mcp-server::conversations_search_messages.limit"}, "filter_in_channel": {"FromQuery": "filter_in_channel"}, "filter_users_from": {"FromQuery": "filter_users_from"}, "filter_date_after": {"FromQuery": "filter_date_after"}, "filter_date_before": {"FromQuery": "filter_date_before"}, "cursor": {"FromQuery": "cursor"}}', '[]');

COMMIT;
```

### Critical Fix: Making Payload Required

**Problem**: If `payload` is marked as optional in the parameter rule, the parameter engine will skip it entirely, even if:
- An extractor pattern exists in `parameter_extractors.toml`
- The extractor pattern is correctly configured
- The query contains the message text

**Solution**: Make `payload` a required field in the parameter rule:

```sql
-- WRONG: payload is optional, so it won't be extracted
required_fields: '["channel_id"]'

-- CORRECT: payload is required, so it will be extracted
required_fields: '["channel_id", "payload"]'
```

**Why This Works**: The OI OS parameter engine only processes fields listed in `required_fields`. Optional fields are completely skipped during parameter extraction, regardless of whether extractors exist.

### Verifying Parameter Rules

```bash
# List all Slack parameter rules
sqlite3 brain-trust4.db "SELECT tool_signature, required_fields FROM parameter_rules WHERE server_name = 'slack-mcp-server';"

# Check specific tool rule
sqlite3 brain-trust4.db "SELECT * FROM parameter_rules WHERE tool_signature = 'slack-mcp-server::conversations_add_message';"
```

### Updating Parameter Rules

To update a parameter rule (e.g., to make a field required):

```bash
sqlite3 brain-trust4.db << 'SQL'
-- Make payload required for conversations_add_message
UPDATE parameter_rules 
SET required_fields = '["channel_id", "payload"]' 
WHERE tool_signature = 'slack-mcp-server::conversations_add_message';
SQL
```

### Testing Parameter Extraction

After creating parameter rules, test with debug output:

```bash
export SLACK_MCP_XOXC_TOKEN=$(grep "^SLACK_MCP_XOXC_TOKEN=" .env | cut -d'=' -f2-)
export SLACK_MCP_XOXD_TOKEN=$(grep "^SLACK_MCP_XOXD_TOKEN=" .env | cut -d'=' -f2-)
export SLACK_MCP_ADD_MESSAGE_TOOL=true

# Test with debug output
DEBUG=1 ./oi brain "slack post message to #general Hello from OI!" --test-params 2>&1 | grep -A 15 "Parameter Generation"
```

You should see both `channel_id` and `payload` in the generated parameters if the rule is correct.

---

## Creating Intent Mappings

Intent mappings connect natural language queries to specific Slack MCP tools. Create them using SQL INSERT statements.

### Database Location

```bash
sqlite3 brain-trust4.db
```

### Intent Mappings Schema

```sql
CREATE TABLE intent_mappings (
    keyword TEXT PRIMARY KEY,
    server_name TEXT NOT NULL,
    tool_name TEXT,
    priority INTEGER DEFAULT 1
);
```

### All Slack MCP Server Intent Mappings

Run this optimized single SQL statement to create all intent mappings:

```sql
INSERT OR REPLACE INTO intent_mappings (keyword, server_name, tool_name, priority) VALUES 
('slack list channels', 'slack-mcp-server', 'channels_list', 10),
('slack channels', 'slack-mcp-server', 'channels_list', 10),
('slack show channels', 'slack-mcp-server', 'channels_list', 10),
('slack get channels', 'slack-mcp-server', 'channels_list', 10),
('slack channel history', 'slack-mcp-server', 'conversations_history', 10),
('slack get history', 'slack-mcp-server', 'conversations_history', 10),
('slack show history', 'slack-mcp-server', 'conversations_history', 10),
('slack messages', 'slack-mcp-server', 'conversations_history', 10),
('slack recent messages', 'slack-mcp-server', 'conversations_history', 10),
('slack thread replies', 'slack-mcp-server', 'conversations_replies', 10),
('slack get replies', 'slack-mcp-server', 'conversations_replies', 10),
('slack show replies', 'slack-mcp-server', 'conversations_replies', 10),
('slack thread messages', 'slack-mcp-server', 'conversations_replies', 10),
('slack post message', 'slack-mcp-server', 'conversations_add_message', 10),
('slack send message', 'slack-mcp-server', 'conversations_add_message', 10),
('slack write message', 'slack-mcp-server', 'conversations_add_message', 10),
('slack create post', 'slack-mcp-server', 'conversations_add_message', 10),
('slack post', 'slack-mcp-server', 'conversations_add_message', 10),
('slack search messages', 'slack-mcp-server', 'conversations_search_messages', 10),
('slack search', 'slack-mcp-server', 'conversations_search_messages', 10),
('slack find messages', 'slack-mcp-server', 'conversations_search_messages', 10);
```

### Verifying Intent Mappings

```bash
# List all Slack intent mappings
sqlite3 brain-trust4.db "SELECT * FROM intent_mappings WHERE server_name = 'slack-mcp-server' ORDER BY priority DESC;"

# Or use OI command
./oi intent list | grep slack
```

### Removing Intent Mappings

```sql
-- Remove a specific mapping
DELETE FROM intent_mappings WHERE keyword = 'slack list channels';

-- Remove all Slack mappings
DELETE FROM intent_mappings WHERE server_name = 'slack-mcp-server';
```

---

## End User Setup

### Quick Start for End Users

1. **Install Prerequisites**
   ```bash
   # Install Go (if not installed)
   brew install go  # macOS
   # or visit: https://go.dev/dl/
   ```

2. **Clone Repository**
   ```bash
   git clone https://github.com/korotovsky/slack-mcp-server.git
   cd slack-mcp-server
   ```

3. **Build Server**
   ```bash
   make build
   ```

4. **Get Slack Tokens**
   - Extract `xoxc-...` and `xoxd-...` tokens from your Slack workspace
   - See [Authentication Setup Guide](docs/01-authentication-setup.md) for details

5. **Configure Environment**
   ```bash
   # Create .env file in project root
   SLACK_MCP_XOXC_TOKEN=xoxc-your-token-here
   SLACK_MCP_XOXD_TOKEN=xoxd-your-token-here
   SLACK_MCP_ADD_MESSAGE_TOOL=true
   ```

6. **Configure Claude Desktop / Cursor**

   **For Claude Desktop:**
   - Edit: `~/Library/Application Support/Claude/claude_desktop_config.json`
   ```json
   {
     "mcpServers": {
       "slack": {
         "command": "/full/path/to/slack-mcp-server/build/slack-mcp-server",
         "env": {
           "SLACK_MCP_XOXC_TOKEN": "xoxc-your-token",
           "SLACK_MCP_XOXD_TOKEN": "xoxd-your-token",
           "SLACK_MCP_ADD_MESSAGE_TOOL": "true"
         }
       }
     }
   }
   ```

   **For Cursor:**
   - Edit: `~/.cursor/mcp.json`
   ```json
   {
     "mcpServers": {
       "slack": {
         "command": "/full/path/to/slack-mcp-server/build/slack-mcp-server",
         "env": {
           "SLACK_MCP_XOXC_TOKEN": "xoxc-your-token",
           "SLACK_MCP_XOXD_TOKEN": "xoxd-your-token",
           "SLACK_MCP_ADD_MESSAGE_TOOL": "true"
         }
       }
     }
   }
   ```

7. **Sync Cache (for OI OS only)**
   ```bash
   # From OI OS project root
   ./MCP-servers/slack-mcp-server/sync-slack-cache.sh
   ```

8. **Restart Claude Desktop / Cursor**

---

## Verification & Testing

### Test Server Connection

```bash
# List all servers
./oi list

# Check Slack server status
./oi status slack-mcp-server

# Test tool discovery
./brain-trust4 call slack-mcp-server tools/list '{}'
```

### Test Intent Mappings

```bash
# Test listing channels (works reliably)
./oi "slack list channels"
./oi "slack channels"

# Test getting history
./oi "slack get history from #dev"

# Test posting a message (parameter extraction may fail - use direct call instead)
./oi "slack post message to #dev: Hello from OI OS!"

# Test searching messages
./oi "slack search messages query: deployment"
```

### Direct Tool Calls (Backup Option)

**NOTE**: For direct tool calls bypassing intent mapping and parameter extraction:

```bash
# Direct tool call (bypasses intent mapping)
./brain-trust4 call slack-mcp-server channels_list '{"channel_types": "public_channel,private_channel"}'

# Post message directly
./brain-trust4 call slack-mcp-server conversations_add_message '{"channel_id": "#dev", "payload": "Test message"}'

# Get channel history
./brain-trust4 call slack-mcp-server conversations_history '{"channel_id": "#dev", "limit": "1d"}'
```

---

## Troubleshooting

### Build Issues

**Build Fails**
```bash
cd MCP-servers/slack-mcp-server
make clean
make build
```

**Go Not Found**
```bash
# Verify Go installation
go version  # Should show 1.21+

# Install Go if missing
brew install go  # macOS
```

### Authentication Issues

**"Missing required tokens" Error**
- Verify `.env` file exists in project root
- Check token format: `xoxc-...` and `xoxd-...` (or `xoxp-...`)
- Ensure no extra spaces or quotes around token values
- Restart OI OS after adding tokens

**"Invalid token" Error**
- Tokens may have expired (refresh from Slack)
- Verify tokens are correct (no typos)
- Check if workspace restrictions apply

**Message Posting Disabled**
- Set `SLACK_MCP_ADD_MESSAGE_TOOL=true` in `.env`
- Or restrict to specific channels: `SLACK_MCP_ADD_MESSAGE_TOOL=C1234567890`
- Restart server after changing environment variables

### Cache Sync Issues

**Cache Files Not Created**
- Ensure `.env` file has correct tokens
- Check script permissions: `chmod +x sync-slack-cache.sh`
- Run script from OI OS project root directory
- Check logs: `tail -f /tmp/slack-sync.log`

**Cache Sync Times Out**
- Increase wait time in `sync-slack-cache.sh` (default: 90 seconds)
- Check if you have many channels/users (may need more time)
- Verify server is responding: `./oi status slack-mcp-server`

**Channel Lookups Not Working**
- Verify cache files exist: `ls -lh .users_cache.json .channels_cache_v2.json`
- Re-run cache sync: `./MCP-servers/slack-mcp-server/sync-slack-cache.sh`
- Check cache file permissions and content

### Tool Execution Issues

**"Channel not found" Error**
- Cache may be out of date - re-run cache sync
- Use full channel ID instead of name: `C1234567890` instead of `#general`
- Verify channel exists and you have access

**"Tool not found" Error**
- Verify server connection: `./oi status slack-mcp-server`
- Check if tool is enabled: `SLACK_MCP_ADD_MESSAGE_TOOL` for posting
- Restart server connection

**Parameter Extraction Fails**
- **CRITICAL**: Verify parameter extractors are in `parameter_extractors.toml.default` (not `parameter_extractors.toml`)
- Check parameter rules exist in database
- Verify required fields are correctly marked in parameter rules
- Test with debug output: `DEBUG=1 ./oi "slack post dev test" 2>&1 | grep -E "(Pattern|Extract|Generated)"`
- **NOTE (Backup)**: Use direct calls if needed: `./brain-trust4 call slack-mcp-server tool-name '{"param": "value"}'`

**Patterns Not Loading / Extractors Not Found**
- **Root Cause**: OI OS loads `parameter_extractors.toml.default`, not `parameter_extractors.toml`
- **Fix**: Add patterns to `parameter_extractors.toml.default` in project root
- **Verification**: Check debug output for "Loaded X custom extraction patterns" - should show patterns loading
- **Pattern Format**: Ensure patterns handle bare channel names (e.g., "dev" without "#") for natural language queries

**"text must be a string" Error (Slack Message Posting)**
- **Root Cause**: The `payload` field is not being extracted because it's marked as optional in the parameter rule
- **Fix**: Make `payload` a required field in the parameter rule:
  ```sql
  UPDATE parameter_rules 
  SET required_fields = '["channel_id", "payload"]' 
  WHERE tool_signature = 'slack-mcp-server::conversations_add_message';
  ```
- **Why**: The OI OS parameter engine only extracts required fields. Optional fields are skipped even if extractors exist in `parameter_extractors.toml`
- **Verification**: Check the parameter rule:
  ```bash
  sqlite3 brain-trust4.db "SELECT required_fields FROM parameter_rules WHERE tool_signature = 'slack-mcp-server::conversations_add_message';"
  ```
  Should show: `["channel_id", "payload"]` (not just `["channel_id"]`)

### Connection Issues

**Server Won't Connect**
- Verify binary exists: `ls -lh build/slack-mcp-server`
- Check binary permissions: `chmod +x build/slack-mcp-server`
- Verify `.env` file exists in project root with correct tokens
- Check that `brain-trust4` is loading `.env` (should happen automatically)
- Check logs for error messages

**Connection Drops Quickly**
- Normal for OI OS - connection pool closes connections after use
- This is why cache sync script is needed
- **NOTE (Backup)**: Use direct tool calls if needed: `./brain-trust4 call slack-mcp-server tool-name '{}'`

### Performance Issues

**Slow Cache Sync**
- Normal if you have many channels/users
- Increase wait time in sync script if needed
- Cache only needs to be synced once (or when channels/users change)

**Slow Tool Execution**
- Normal on first call (cache initialization)
- Subsequent calls should be faster
- Check network connection to Slack

---

## Available Tools Reference

### Channel Management
- `channels_list(channel_types, limit, cursor, sort)` - List all channels
  - **Required**: `channel_types` (comma-separated: `public_channel,private_channel,im,mpim`)
  - **Optional**: `limit` (1-1000, default: 100), `cursor`, `sort` (`popularity`)

### Message Retrieval
- `conversations_history(channel_id, limit, cursor, include_activity_messages)` - Get channel/DM messages
  - **Required**: `channel_id` (channel ID `C...` or name `#channel`, `@user_dm`)
  - **Optional**: `limit` (time: `1d`, `1w`, `30d`, or count: `50`, default: `1d`), `cursor`, `include_activity_messages`

- `conversations_replies(channel_id, thread_ts, limit, cursor, include_activity_messages)` - Get thread messages
  - **Required**: `channel_id`, `thread_ts` (timestamp: `1234567890.123456`)
  - **Optional**: `limit`, `cursor`, `include_activity_messages`

- `conversations_search_messages(search_query, filters, limit, cursor)` - Search messages
  - **Optional**: `search_query`, `filter_in_channel`, `filter_in_im_or_mpim`, `filter_users_from`, `filter_users_with`, `filter_date_after`, `filter_date_before`, `filter_date_on`, `filter_date_during`, `filter_threads_only`, `limit` (default: 20), `cursor`

### Message Posting
- `conversations_add_message(channel_id, payload, thread_ts, content_type)` - Post message
  - **Required**: `channel_id`, `payload` (message text)
  - **Optional**: `thread_ts` (reply to thread), `content_type` (`text/markdown` or `text/plain`, default: `text/markdown`)

**Note:** Message posting requires `SLACK_MCP_ADD_MESSAGE_TOOL=true` environment variable.

---

## Additional Resources

- **Slack MCP Server Repository:** https://github.com/korotovsky/slack-mcp-server
- **Authentication Setup:** [docs/01-authentication-setup.md](docs/01-authentication-setup.md)
- **Installation Guide:** [docs/02-installation.md](docs/02-installation.md)
- **Configuration Guide:** [docs/03-configuration-and-usage.md](docs/03-configuration-and-usage.md)
- **OI OS Documentation:** See `docs/` directory in your OI OS installation
- **MCP Protocol Specification:** https://modelcontextprotocol.io/

---

## Support

For issues specific to:
- **Slack MCP Server:** Open an issue at https://github.com/korotovsky/slack-mcp-server
- **OI OS Integration:** Check OI OS documentation or repository
- **General MCP Issues:** See MCP documentation at https://modelcontextprotocol.io/

---

**Last Updated:** 2025-11-08  
**Compatible With:** OI OS / Brain Trust 4, Claude Desktop, Cursor  
**Server Version:** Latest from korotovsky/slack-mcp-server

---

## Known Issues & Fixes

### Payload Extraction Not Working

**Issue**: When posting Slack messages via natural language queries (e.g., `./oi "slack post message to #general Hello!"`), the `payload` field is not extracted, resulting in errors like "text must be a string".

**Root Cause**: The OI OS parameter engine only extracts fields marked as **required** in the `parameter_rules` database table. If `payload` is marked as optional, it will be skipped entirely, even if:
- An extractor pattern exists in `parameter_extractors.toml`
- The extractor pattern is correctly configured
- The query contains the message text

**Fix**: Make `payload` a required field in the parameter rule:

```sql
sqlite3 brain-trust4.db << 'SQL'
UPDATE parameter_rules 
SET required_fields = '["channel_id", "payload"]' 
WHERE tool_signature = 'slack-mcp-server::conversations_add_message';
SQL
```

**Verification**: After applying the fix, test with debug output:

```bash
export SLACK_MCP_XOXC_TOKEN=$(grep "^SLACK_MCP_XOXC_TOKEN=" .env | cut -d'=' -f2-)
export SLACK_MCP_XOXD_TOKEN=$(grep "^SLACK_MCP_XOXD_TOKEN=" .env | cut -d'=' -f2-)
export SLACK_MCP_ADD_MESSAGE_TOOL=true

DEBUG=1 ./oi brain "slack post message to #general Hello from OI!" --test-params 2>&1 | grep -A 15 "Parameter Generation"
```

You should see both `channel_id` and `payload` in the generated parameters.

**Prevention**: When creating parameter rules, ensure all fields that need to be extracted from natural language queries are marked as required, even if they're technically optional in the tool's API signature.

### Parameter Extractors File Location Issue

**Issue**: Parameter extractors are not loading, showing "Loaded 0 custom extraction patterns" in debug output, or patterns are not being found.

**Root Cause**: OI OS loads parameter extractors from `parameter_extractors.toml.default` in the project root, **not** from `parameter_extractors.toml`. The system prioritizes the `.default` file.

**Fix**: Add patterns to `parameter_extractors.toml.default`:

```bash
# Add patterns to the correct file
cat >> parameter_extractors.toml.default << 'SLACK_EXTRACTORS'
# Slack patterns here
SLACK_EXTRACTORS
```

**Verification**: Check if extractors are loading:
```bash
DEBUG=1 ./oi "test" 2>&1 | grep -E "(Loaded|Merged).*patterns"
```
Should show: `✅ Loaded X custom extraction patterns` (where X > 0)

**Pattern Improvements**: The updated patterns handle:
- Bare channel names: `slack post dev message` (extracts "dev" as channel)
- Channel names with #: `slack post #dev message` (extracts "#dev")
- Channel IDs: `slack post C09QF4P842G message` (extracts channel ID)
- Natural language: `slack post dev easy as pie` (extracts "dev" and "easy as pie")

**Prevention**: Always add patterns to `parameter_extractors.toml.default`, not `parameter_extractors.toml`.

