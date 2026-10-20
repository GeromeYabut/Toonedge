# Story 13.4 Reader gap-centred pinch fix

User authorized fixing PR #17, focused regression, independent review, preservation and no merge. This is a narrow continuation of the existing reviewable PR outcome on feature/story-13.4-reader-zoom-pinch-continuation at 4590813dffa2bb7a2b48fbae24760da9e90c0dcd; origin/main fetched and verified 4e2d55b4371ec645bac962a21d781e90572abf8c. Existing evidence basis and historical qualifications remain unchanged. No stopped checkout is reused or cleaned.

## Design and boundaries
- Preserve active pinch continuity when logical focal has no page anchor during relayout, using the remapped presentation to rebase its projected viewport midpoint into new logical coordinates. Prefer this to cancelling a valid gesture or assigning blank space an arbitrary page anchor.
- Keep existing semantic-anchor behavior when the focal lies on a page; preserve sticky magnification history, frozen reading and remapped cancellation rollback.
- Modify only app/Sources/ToonEdgeAppCore/Features/Reader/Interaction/ReaderZoomState.swift and app/Tests/ToonEdgeAppCoreTests/ReaderZoomStateTests.swift, plus new evidence here.
- No persistence changes/investigation, no full matrix, no production safety clearance. iOS 17 API floor required; runtime waiver unchanged. Protected screenshots and all prior artifacts preserved. No schema/API changes.

## Execution
1. Controller captures original source hashes, prior evidence hashes, worktree bindings and status before edits. Verify agent slots before runtime. Verify external UUID, free space, then separate directory probe. Inspect each real completion/exit; no setup chaining.
2. Proposal implementer may write only proposals.json and implementation-report.md in this directory. Complete untrimmed before/after source bytes, exact absolute destination, SHA256 and separate test/fix stages are required; controller alone applies and dispatches tests.
3. Controller validates envelopes and original hashes, applies test stage only. Run ReaderZoomStateTests to establish RED at new gap/gutter continued-update assertions; compile/setup errors are failed gates, not RED.
4. Apply production stage only after RED confirms the defect. Run focused ReaderZoomStateTests GREEN, then full package suite jobs1 and generic simulator Debug build at deployment floor17. No native UI case dispatch. Inspect exits, case totals and diagnostics.
5. Fresh independent reviewer, distinct from proposal implementer, reviews full patch/tests/results and surrounding source. No writes except designated independent-review.md, no runtime. Resolve material findings within scope or stop. Controller checks evidence privacy, unchanged prior hashes, source bytes/hashes and diff before commit/push to PR #17. Await required Simulator Build. Never merge.

## Budget and gates
Maximum initial allocation: four local dispatches (focused RED, focused GREEN, full package, generic simulator build), jobs1 for SwiftPM, one at a time; maximum20minutes combined local wall time, no automatic retry or additional UI cases. CI read-only wait maximum10minutes. One proposal implementer and one fresh reviewer; no concurrent source writers. Stop on wrong branch/head, changed evidence/source binding, missing resource or failed setup, unexpected RED, failed GREEN/package/build/review/privacy, runtime cap or additional scope. A failed gate requires assessment before further allocation; no expansion to persistence or broad recalibration.

Workspace: /Users/geromeyabut/.codex/worktrees/reader-zoom-pinch-continuation/Toonedge
Evidence: /Users/geromeyabut/.codex/worktrees/reader-zoom-pinch-continuation/Toonedge/docs/qa_evidence/2026-10-20/story-13.4-reader-zoom-gap-fix
Fresh outputs: /Volumes/Seagate 2TB/ToonEdgeBuilds/Active/feature-story-13.4-reader-zoom-gap-fix-20261020a
QA report: /Users/geromeyabut/.codex/worktrees/reader-zoom-pinch-continuation/Toonedge/docs/qa_evidence/2026-10-20/story-13.4-reader-zoom-gap-fix/QA.md

Progress: prerequisites verified (linked isolated PR worktree, tracked/index clean, origin/main unchanged, available agent capacity, external UUID 7C6E7CE1-D8D5-3041-AA58-DC000A724A29 and about1.48TB free). Storage probe and baseline snapshot next. Prior review artifact review-summary.md remains untouched.
