# Code Design Principles

## Code readability

- **Structure scripts with well-named functions.** Use function names to convey intent rather than relying on section comments. The main block at the bottom should read as a high-level summary of what the script does.
- **Separate steps within a function with blank lines.** Treat groups of related lines as paragraphs — blank lines between them aid readability by signalling a shift in concern. When a paragraph grows complex enough to name, extract it into a function. But extraction isn't always desirable (e.g. tests that assert several things in sequence).
- **Define variables next to their immediate use.** Don't hoist variables to the top of a script when they're only relevant inside a single function — it increases cognitive load by forcing readers to retain awareness of names that aren't yet relevant. Shared variables that multiple functions depend on are fine at module scope.

## Locality of change

- **Encapsulate the "how" behind functions that describe the "what."** Abstract implementation details behind well-named functions, modules, or files so consumers see intent, not mechanics. This applies at every level — shell functions, test assertions, file organization.
- **High cohesion within modules, low coupling across modules.** Keep related concerns together in the same script or file. Avoid implicit coupling where one script silently depends on another having set up specific state — instead, let each module own its full responsibility. When two scripts must coordinate, make the dependency explicit (e.g. via arguments or ordering in an orchestrator).
- **De-duplicate knowledge, not code.** Apply DRY to eliminate repeated knowledge (constants, logic, config) ruthlessly. But don't merge similar-looking code that has different responsibilities and could diverge — that's coincidental similarity, not duplication. Exception: deliberate duplication is acceptable where it adds necessary friction for security, e.g. hardcoding an expected username in a privileged script to allow verification at the point of use.
