# Aggregate: permutation build simplification (latest round)

Sources: codex, claude, gemini, cursor-agent.

Findings:
- Base is rebuilt per matrix job; bake setup duplicated. Consider a single bake invocation that builds base + all permutations together (or a dedicated base job that pushes cache to GHCR, permutations pull).
- Mapping step can be folded into matrix by adding the target name to the matrix entries, reducing glue.
- Variants could be handled via bake args instead of separate targets to shrink HCL, but optional.
- Current actions are fine (setup-buildx/login/metadata/bake); main simplification is consolidating bake calls to share cache and avoid rebuild.
