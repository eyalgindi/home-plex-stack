# How to Add MCP Server in Cursor

## Overview

MCP (Model Context Protocol) servers allow Cursor to connect to external tools and services, extending its capabilities with custom integrations.

## Quick Setup

### Method 1: Through Cursor Settings UI

1. **Open Cursor Settings**:
   - Press `Ctrl+,` (Windows/Linux) or `Cmd+,` (Mac)
   - Or: `File → Preferences → Settings`

2. **Navigate to MCP Settings**:
   - In the settings sidebar, select **Tools & Integrations** (or **Tools** on Free Plan)
   - Look for **MCP Tools** section
   - Click **Add Custom MCP**

3. **Configure the Server**:
   - This opens the `mcp.json` configuration file
   - Add your server configuration (see examples below)

4. **Save and Restart**:
   - Save the `mcp.json` file
   - Completely quit and restart Cursor

### Method 2: Edit Configuration File Directly

1. **Locate Configuration File**:
   - `~/.cursor/mcp.json` (Linux/Mac)
   - `%APPDATA%\Cursor\mcp.json` (Windows)
   - Or: `~/.config/cursor/mcp.json`

2. **Edit the File**:
   - Create the file if it doesn't exist
   - Add your MCP server configuration

3. **Restart Cursor**

---

## Configuration Examples

### GitHub MCP Server

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token_here"
      }
    }
  }
}
```

**Setup**:
1. Get GitHub token: https://github.com/settings/tokens
2. Create token with `repo` scope
3. Replace `your_github_token_here` with your token

### Filesystem MCP Server

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/nfs/data/docker/home_plex"
      ]
    }
  }
}
```

**Note**: Replace `/nfs/data/docker/home_plex` with the directory you want to allow access to.

### PostgreSQL MCP Server

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-postgres"
      ],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://user:password@host:5432/database"
      }
    }
  }
}
```

### Brave Search MCP Server

```json
{
  "mcpServers": {
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "your_brave_api_key"
      }
    }
  }
}
```

### SSE (Server-Sent Events) Transport

For servers using SSE transport:

```json
{
  "mcpServers": {
    "custom-server": {
      "url": "http://localhost:3000/sse"
    }
  }
}
```

---

## Multiple Servers Configuration

You can configure multiple MCP servers:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_token"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/nfs/data/docker/home_plex"
      ]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://user:pass@host:5432/db"
      }
    }
  }
}
```

---

## Common MCP Servers

| Server | Package | Purpose |
|--------|---------|---------|
| GitHub | `@modelcontextprotocol/server-github` | GitHub API access |
| Filesystem | `@modelcontextprotocol/server-filesystem` | File system access |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | Database queries |
| Brave Search | `@modelcontextprotocol/server-brave-search` | Web search |
| SQLite | `@modelcontextprotocol/server-sqlite` | SQLite database |
| Puppeteer | `@modelcontextprotocol/server-puppeteer` | Web automation |

---

## Verification

After adding an MCP server:

1. **Restart Cursor completely**

2. **Test in AI Chat**:
   - Press `Cmd + L` (Mac) or `Ctrl + L` (Windows/Linux)
   - Try a prompt like:
     - "Use the GitHub tool to list my repositories"
     - "Use the filesystem tool to read README.md"

3. **Check Server Status**:
   - Look for MCP server indicators in Cursor's status bar
   - Check Cursor's developer console for connection status

---

## Troubleshooting

### Server Not Connecting

1. **Check Configuration Syntax**:
   - Ensure JSON is valid (use a JSON validator)
   - Check for typos in server names or commands

2. **Verify Dependencies**:
   - Ensure `npx` is available: `which npx` or `npx --version`
   - Node.js must be installed

3. **Check Environment Variables**:
   - Ensure all required env vars are set
   - Verify tokens/keys are valid

4. **Check Logs**:
   - Open Cursor's developer console
   - Look for MCP-related errors

### Server Not Available in Chat

1. **Restart Cursor**: Always restart after configuration changes
2. **Check Server Name**: Use the exact server name in prompts
3. **Verify Installation**: Ensure the MCP server package is accessible

### Permission Issues

- **Filesystem Server**: Ensure the path is accessible
- **GitHub Server**: Verify token has correct scopes
- **Database Servers**: Check connection strings and credentials

---

## Best Practices

1. **Use Environment Variables**: Store sensitive tokens in environment variables, not in the config file
2. **Limit Filesystem Access**: Only grant access to necessary directories
3. **Use Specific Versions**: Pin MCP server versions for stability
4. **Test Incrementally**: Add one server at a time and test
5. **Document Configuration**: Keep notes on what each server does

---

## Example: GitHub MCP for This Repository

To add GitHub MCP server for the `home-plex-stack` repository:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "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"
      }
    }
  }
}
```

**Note**: Replace with your actual GitHub token. The token above is from your previous configuration.

---

## Resources

- **Official MCP Documentation**: https://modelcontextprotocol.io
- **Cursor MCP Docs**: https://cursordocs.com/en/docs/advanced/model-context-protocol
- **MCP Server List**: https://github.com/modelcontextprotocol/servers

---

**Last Updated**: 2024-12-27



