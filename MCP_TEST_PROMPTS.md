# GitHub MCP Server Test Prompts

Use these prompts in Cursor's AI Chat (`Cmd+L` or `Ctrl+L`) to test the GitHub MCP server:

## Basic Tests

### 1. List Repositories
```
Use the GitHub tool to list my repositories
```

### 2. Get Repository Information
```
Show me information about the home-plex-stack repository
```

### 3. List Recent Commits
```
What are the latest commits in eyalgindi/home-plex-stack?
```

### 4. Get Repository Details
```
Get details for the home-plex-stack repository owned by eyalgindi
```

## Advanced Tests

### 5. Check Repository Status
```
Use GitHub to check the status of eyalgindi/home-plex-stack repository
```

### 6. List Repository Files
```
Show me the files in the home-plex-stack repository
```

### 7. Get Latest Commit
```
What is the latest commit message in home-plex-stack?
```

### 8. Check Repository Visibility
```
Is the home-plex-stack repository public or private?
```

## Verification

If the MCP server is working correctly, you should:
- ✅ See GitHub API responses
- ✅ Get actual repository data
- ✅ See commit information
- ✅ No errors about "tool not found"

If it's not working:
- ❌ Check that Cursor was restarted after adding MCP server
- ❌ Verify `npx` is installed (Node.js required)
- ❌ Check GitHub token is valid in `~/.cursor/mcp.json`
- ❌ Look for errors in Cursor's developer console



