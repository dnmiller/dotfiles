# Searching the codebase

When the repo has a `.codegraph/` index, use CodeGraph before grep or reading files to find or understand code: one `codegraph_explore` call returns the relevant symbols' source and the call paths between them. If the MCP tool isn't available, run `codegraph explore "<symbols or question>"` in the shell. Without a `.codegraph/` index, skip CodeGraph; indexing is the user's call.

For open-ended searches that would mean reading many files ("where is X handled", "how does Y work", "find every Z"), hand the search to the Explore subagent and work from its summary. Read files yourself only once you know which ones matter.
