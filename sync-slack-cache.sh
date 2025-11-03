#!/bin/bash
# Slack MCP Server Cache Sync Script
#
# PURPOSE:
#   This script initializes the Slack MCP server and syncs the users and channels
#   cache. The cache is required for full functionality of the Slack MCP server,
#   including channel lookups by name (#channel-name) and user lookups by handle (@username).
#
# OI OS SETUP:
#   When running on OI OS (Brain Trust 4), run this script AFTER setting up your .env file
#   with the required Slack authentication tokens.
#
# REQUIRED ENVIRONMENT VARIABLES (in .env file):
#   - SLACK_MCP_XOXC_TOKEN: Slack browser token (xoxc-...)
#   - SLACK_MCP_XOXD_TOKEN: Slack browser cookie d (xoxd-...)
#   - SLACK_MCP_ADD_MESSAGE_TOOL=true: Enable message posting (set to true for all channels)
#
# USAGE:
#   1. Navigate to your OI OS project root directory (where .env file is located)
#   2. Run: ./MCP-servers/slack-mcp-server/sync-slack-cache.sh
#
#   Or from within the slack-mcp-server directory:
#   cd MCP-servers/slack-mcp-server
#   ./sync-slack-cache.sh
#
# WHAT IT DOES:
#   - Starts the Slack MCP server with proper JSON-RPC initialization
#   - Triggers channels_list to sync users and channels cache
#   - Creates cache files: .users_cache.json and .channels_cache_v2.json
#   - Waits ~90 seconds for sync to complete (adjust if you have many channels/users)
#
# CACHE FILES:
#   After successful sync, you'll find:
#   - .users_cache.json (in project root or as specified by SLACK_MCP_USERS_CACHE)
#   - .channels_cache_v2.json (in project root or as specified by SLACK_MCP_CHANNELS_CACHE)
#
# NOTE:
#   The OI connection pool closes connections quickly, which interrupts cache sync.
#   This script keeps the connection alive long enough for the sync to complete.
#

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Try to find .env in project root or current directory
if [ -f "$PROJECT_ROOT/.env" ]; then
    ENV_FILE="$PROJECT_ROOT/.env"
    cd "$PROJECT_ROOT"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
else
    echo "❌ Error: .env file not found in project root ($PROJECT_ROOT) or current directory" >&2
    echo "   Please ensure your .env file is in the OI OS project root with:" >&2
    echo "   - SLACK_MCP_XOXC_TOKEN" >&2
    echo "   - SLACK_MCP_XOXD_TOKEN" >&2
    echo "   - SLACK_MCP_ADD_MESSAGE_TOOL=true" >&2
    exit 1
fi

# Load environment variables
echo "📁 Loading environment from: $ENV_FILE" >&2
set -a
source "$ENV_FILE"
set +a

# Verify required tokens are set
if [ -z "$SLACK_MCP_XOXC_TOKEN" ] || [ -z "$SLACK_MCP_XOXD_TOKEN" ]; then
    echo "❌ Error: Required Slack tokens not found in .env" >&2
    echo "   Please set:" >&2
    echo "   - SLACK_MCP_XOXC_TOKEN=xoxc-..." >&2
    echo "   - SLACK_MCP_XOXD_TOKEN=xoxd-..." >&2
    exit 1
fi

# Get path to binary (from project root or script directory)
if [ -f "$PROJECT_ROOT/MCP-servers/slack-mcp-server/slack-mcp-server" ]; then
    BINARY="$PROJECT_ROOT/MCP-servers/slack-mcp-server/slack-mcp-server"
elif [ -f "$SCRIPT_DIR/slack-mcp-server" ]; then
    BINARY="$SCRIPT_DIR/slack-mcp-server"
else
    echo "❌ Error: slack-mcp-server binary not found" >&2
    echo "   Expected at: $PROJECT_ROOT/MCP-servers/slack-mcp-server/slack-mcp-server" >&2
    exit 1
fi

echo "Starting Slack MCP server for cache sync..." >&2

# Create a named pipe for communication
FIFO=$(mktemp -u)
mkfifo "$FIFO"

# Start server with stdin from FIFO (run from project root so cache files are created there)
cd "$PROJECT_ROOT"
"$BINARY" < "$FIFO" > /tmp/slack-sync.log 2>&1 &
SLACK_PID=$!

# Open FIFO for writing
exec 3>"$FIFO"

# Send initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cache-sync","version":"1.0.0"}}}' >&3

# Wait for response
sleep 2

# Send initialized notification
echo '{"jsonrpc":"2.0","method":"notifications/initialized"}' >&3

# Wait a bit
sleep 2

# Trigger channels_list which will sync the cache
echo "Triggering channels_list to sync cache..." >&2
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"channels_list","arguments":{"channel_types":"public_channel","limit":100}}}' >&3

# Wait for cache to sync (this can take a while)
echo "Waiting for cache to sync (this may take 1-2 minutes)..." >&2
sleep 90

# Send shutdown
echo '{"jsonrpc":"2.0","id":3,"method":"shutdown"}' >&3
sleep 2
echo '{"jsonrpc":"2.0","method":"$/cancel","params":{"id":3}}' >&3

# Close FIFO and clean up
exec 3>&-
rm -f "$FIFO"
kill $SLACK_PID 2>/dev/null
wait $SLACK_PID 2>/dev/null

echo "" >&2
echo "Cache sync complete!" >&2
echo "Cache files location: $PROJECT_ROOT" >&2
tail -30 /tmp/slack-sync.log | grep -E "(cache|Caching|users|channels|Successfully|Wrote)" >&2

