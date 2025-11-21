# Project Plan

1. **Environment & Tooling (Current phase)**  
   - Harden devcontainer (clang-21, mold, cmake/ninja, MRDocs, Graphviz, Doxygen, Mermaid, vcpkg overlays).  
   - Define build presets, documentation scripts, and vcpkg manifests. ✅  
   - Add renderable workflow diagrams (Mermaid/PlantUML + export script to SVG/PNG) for devcontainer/bake flows.

2. **Policy & Concept Scaffolding**  
   - Formalize concepts in `include/slotmap/Concepts.hpp` for handles, slots, storage, and lookup.  
   - Provide default policies (growth, storage, lookup, instrumentation) backed by qlibs/stdx overlays.  
   - Document each policy in `docs/Policies/*.md` and illustrate flows in `docs/Diagrams/`.

3. **SlotMap Core Implementation**  
   - Implement handle generation, slot storage, and error propagation via `std::expected`/`boost::outcome::result`.  
   - Integrate Google Highway for SIMD-assisted scans where policy allows.  
   - Align `docs/Architecture/*.md` with real data-flow diagrams.

4. **Instrumentation & Logging**  
   - Wire Quill logging and policy-based tracing hooks.  
   - Introduce Intel CIB service registration for pluggable allocators/growth behaviors.

5. **Validation & Packaging**  
   - Expand gtest coverage, add sanitizers presets, and document release/deployment steps.  
   - Ensure `scripts/generate_docs.sh` artifacts feed CI/publishing.
