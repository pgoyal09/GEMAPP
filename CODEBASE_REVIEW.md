# GEMAPP Codebase Review (RFID + Inventory Workflow)

Date: 2026-02-28
Scope: full Swift codebase under `QDI_Gemstone_ERP/` plus project/app bootstrap files.

## Executive Summary

The project is in a **good transitional state**: scanner stability appears materially improved, unknown-tag assignment exists end-to-end, and there is clear separation for RFID responsibilities (`RFIDManager`, `RFIDScanService`, `RFIDCoordinator`).

The biggest remaining risks are architectural and data-model related, not parser-crash related:

1. **Identity model is still mixed/legacy (`rfidTag` + `rfidEpc`) and not fully canonical everywhere.**
2. **RFID lifecycle/state is stringly typed and embedded in `Gemstone`, which will not scale to tag replacement/history.**
3. **Some flows still use legacy lookup paths (e.g., `rfidTag` only in transaction RFID handler).**
4. **Error handling is frequently silent (`try?`), reducing debuggability and operational safety.**
5. **A few very large view/service files indicate rising complexity and long-term maintenance risk.**

---

## What Looks Good

### 1) Reader startup + parser hardening is significantly better
- Startup state machine is explicit (`waitingForVersion` → `waitingForBoot` → `waitingForUID` → `waitingForAsyncAck`) and treats UID timeout as non-fatal, preserving bring-up robustness.
- Parser handles partial frames, malformed lengths, CRC validation, and resync behavior.
- Session duplicate suppression and pause/resume controls are implemented and UI-visible.

**Impact:** Good operational baseline for continued feature work without over-rotating on parser refactors immediately.

### 2) Unknown-tag assignment flow exists and is practical
- Unknown tags are detected and routed into assign flow.
- Assignment checks EPC/TID conflicts and requires explicit replace confirmation if a stone already has RFID.
- UI sheet supports search + controlled assignment feedback.

**Impact:** You already have the right fallback workflow needed for migration/testing/exception handling.

### 3) MVVM direction is present in key scanner paths
- `ScannerView` is mostly presentation-only.
- `ScannerViewModel` and `RFIDCoordinator` centralize scan handling/modal state.

**Impact:** Good foundation for incremental PR-sized changes.

### 4) Inventory/memo/invoice status transitions are represented in model layer
- `GemstoneStatus`, `LineItemStatus`, and helper computed properties provide readable behavior.

**Impact:** Domain intent is clear, making it easier to wire scanner-triggered actions consistently.

---

## Areas Needing Improvement (Prioritized)

## P0 — Identity Canonicalization & Data Model

### A) Canonical identity is still not universally enforced
- Current extraction uses a fixed 12-byte chunk from `E2 80` marker (or fallback to last 12 bytes).
- This is useful for stabilization but can become a collision/normalization risk if frame layouts vary or if EPC policy changes.

**Recommendation**
- Define a canonical EPC contract now (length, character set, casing, checksum/validation rules).
- Store and compare only canonical EPC for primary identity.
- Keep raw payload for diagnostics only.

### B) Legacy field overlap (`rfidTag`, `rfidEpc`) remains active
- Multiple code paths still accommodate both fields; one path still uses legacy-only lookup behavior.

**Recommendation**
- Introduce explicit migration phases:
  1) Backfill canonical EPC.
  2) Read both, write only `rfidEpc`.
  3) Remove `rfidTag` reads once migration confidence is high.

### C) RFID should move into dedicated tag table
- Current `Gemstone`-embedded RFID fields are okay for MVP but weak for replacement/history/verification.

**Recommendation**
- Add `rfid_tags` model with lifecycle/state, assignment linkage, verification metadata, and timestamps.
- Preserve assignment history instead of overwriting fields on `Gemstone`.

---

## P1 — Reliability / Stability

### D) Silent persistence failures (`try?`) hide production issues
- Many write paths swallow errors and continue.

**Recommendation**
- Replace `try?` in critical state transitions with explicit `do/catch` and user-visible/log-visible failure handling.
- Add structured error telemetry for RFID assignment, memo/invoice conversion, and returns.

### E) App store reset fallback may be too destructive
- On container creation failure, app deletes store files and retries.

**Recommendation**
- Gate destructive reset behind a migration guard, backup attempt, or explicit recovery mode.
- At minimum, log a stronger warning and record reason.

---

## P2 — Complexity / Maintainability

### F) Several files are very large and blending concerns
- `RFIDManager.swift`, `StoneFormView.swift`, `DashboardView.swift`, `TransactionEditorView.swift` are large and likely to become change hotspots.

**Recommendation**
- Split by responsibility (parser/startup/connection/logging in RFID; reusable subviews in large views).
- Keep behavior identical while extracting modules in small PRs.

### G) Logging is mostly ad-hoc `print`

**Recommendation**
- Standardize on a logger abstraction with levels and categories (RFID I/O, assignment, transactions, persistence).

### H) Test coverage appears absent for critical flows

**Recommendation**
- Add tests first for pure logic components:
  - EPC normalization
  - assignment conflict matrix
  - memo↔invoice status transitions
  - parser frame slicing/resync fixtures

---

## Suggested Next Phase Plan (Aligned to your strategy)

1. **Schema phase**: introduce `rfid_tags` + lifecycle enum + migration path from gemstone fields.
2. **Unknown tag phase**: keep current assign UI, but write through `rfid_tags` service boundary.
3. **EPC phase**: finalize canonical EPC generator/validator and enforce single representation.
4. **Print service phase (design only)**: define API contracts + job state tracking; no Zebra command implementation yet.
5. **Verification phase**: add post-encode verify hook and state transitions (`pending` → `print_requested` → `encoded` → `verified` → `assigned`/`failed`).

