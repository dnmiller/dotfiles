# Tools on Cursor models

Applies only when your tool list has Cursor names (ReadFile, Shell, GetDynamicTools, CallDynamicTool). Other models: ignore this.

OpenCode's skills and MCP servers are not top-level functions on Cursor models. They are dynamic tools. This is expected; do not reason about it, just use these routes:

- Skill: if it is listed with a SKILL.md path, read that file. Otherwise call namespace `opencode`, tool `skill`.
- CodeGraph: namespace `codegraph`, tool `codegraph_explore`.
- Other MCP servers (Linear, Context7 for library docs): the namespace is the server name, `linear` or `context7`.
- Any other OpenCode or plugin tool: namespace `opencode`.

Fetch a tool's schema with GetDynamicTools once, then call it with CallDynamicTool.
