**Verdicts: accept (no decision change) 0 · owner decision 10 · reject 1 · already done 1** (12 findings; 6 of the owner decisions are recommended as partial accepts)

# Triage of Gemini's simplification review (G1–G12)

Analyst: independent; did not write the design or the review. Inputs: `gemini-simplification-review.md`, `values.md`, `decisions.md` (D-01…D-63), `requirements.md`, `glossary.md`, `README.md`, `architecture.md` (rev. 3 + 3a), `adr/*`, `how-it-works.md`, `triage.md`, `review-round3.md`.
Notation: `arch:N` = `architecture.md` line N; `dec:N` = `decisions.md` line N; `req:N` = `requirements.md`; `hiw:N` = `how-it-works.md`; `ADR-00x:N`.
Values (binding, in order): 1 verified outcome per token · 2 minimal worker context · 3 simple · 4 safe by structure · 5 observable. Safety is judged against the value-4 test: *a misbehaving worker of any provider cannot push, merge, change the rules or touch protected paths*. Other structural properties are named when they are affected.

## Summary

| G | Title (short) | Verdict | Decisions affected | Safety impact (value 4) | Recommendation |
|---|---|---|---|---|---|
| G1 | Defer holdout scenarios | owner decision | D-36, D-37, D-45, D-55; P1 | None on the value-4 test. Lost: the one check the builder cannot see | **Accept**: defer to v2 with dark routes; the test author covers boundaries and negative paths in visible tests |
| G2 | Drop verifier and moderator | owner decision | D-09, D-13 (D-39 outcome `wrong`) | None | **Partial**: drop the moderator (checklist built deterministically); keep one verifier call per round, run only on `Important` findings |
| G3 | Replace council + judge | owner decision | **R3, R9 (owner-stated)**, D-06, D-09, D-12, D-22, D-54 | None | **Accept**: the plan lists design options with a recommendation; the plan critique checks them; disagreement goes to the Inbox; ADRs are still rendered |
| G4 | Collapse budgets | owner decision | D-19, D-28, D-60 | None on value 4. Quota exposure from D-60 becomes flagged, not charged | **Partial**: no reservations and no Budget entity; caps on steps, wall time, rounds and tokens (measured or estimated) per item and run; `requests`/`usd` dropped. **Closes C1** |
| G5 | Defer breaker, dark routes, noise | owner decision | D-03 (dark part), D-39; P13, P14 | **Positive**: removes the only path where the orchestrator merges | **Partial**: defer dark routes and the breaker to v2; keep finding outcomes as telemetry; drop `finding reclassify` |
| G6 | No answers via GitHub comments | owner decision | D-20 (ADR-007) | **Positive**: removes one of the two paths that can create a human approval | **Accept**: the mirror becomes notification-only |
| G7 | Tester = builder toolchain | owner decision | D-17, P15 (reverts the A16 fix) | Loses D-17's "run only the repo's tests" exec limit; the value-4 test still holds | **Accept**: the test author gets what the builder already has, in a discarded and diff-checked copy |
| G8 | Defer eval harness | owner decision | D-48 (P11) | None | **Accept**: defer to v2; OpenSpec archive fixtures move to `Factory.Core.Tests` |
| G9 | Drop D-62; restore in `checking` | **reject** (as proposed) | D-62 | **Negative**: unapproved third-party code would run in builder Steps that have provider egress | Reject. Counter-proposal (Q65): keep approval before restore, but drop the `building → planning` loop. **Closes A7** |
| G10 | Remove dead dedicated-user fallback | **already done** | D-63 | — | Done in revision 3a; one leftover line (`arch:534`) to fix locally |
| G11 | 2 UI screens, read-only Config | owner decision | **R2, R9, D-04 amendment (owner-stated)**, D-15, D-16, D-42; ADR-006 | Slightly positive: one fewer write path into `.factory/**` | **Partial**: drop the repo-config PR generator; keep machine and provider editing in the UI; keep the screen layout |
| G12 | Remove late `reviewing → red` | owner decision | **D-52 last sentence** (Gemini says none) | None | **Accept**: a late "E2E needed" finding becomes an escalation with a follow-up-issue option |

---

## G1 — Defer holdout scenarios
- **Evidence:** correct (`arch:222-226`, `246`, `319-333`, `609`, Q8 `arch:725`; D-36 `dec:262`, D-55 `dec:395`). Gemini missed some dependencies: D-37 makes "holdout passes on main" part of group done (`dec:269`), D-45 calls holdout "a separate hidden layer" (`dec:325`), P1 is `agreed` (`req:73`), and the eval scores use holdout pass rate (`arch:636`).
- **What goes away:** group state `scenarios` (6 → 5 group states); 2 model calls and 1 human approval per group, and dispatch no longer waits for that approval; the similarity checker; requirement-reference scoping; the `groups/<n>/holdout/` store; `gate.holdout`; the Group fields for scenario hash and approval; one escalation reason; holdout promotion in the closing PR.
- **What the owner loses:** the only verification the builder cannot tailor code to. In light mode a human still reviews every PR, and the scenarios are effectively new requirements, so their main payoff comes with dark mode.
- **Safety:** none on the value-4 test. The red-test lock and the separate test author (D-45) stay.
- **Interactions:** goes with G5 (dark routes) and G8 (eval scoring). No effect on A7, C1 or C2.
- **Verdict:** owner decision. **Recommend accept, with a substitution:** test-author instructions require boundary and negative-path tests per requirement, and the `spec-correctness` lens checks for them. This is an instructions change only.

## G2 — Drop finding verifier and moderator
- **Evidence:** correct (`arch:352-354`, `43`, `49`; D-13 `dec:101`). Correction: each verifier handles all findings of a round in one call (`arch:352`). With default counts, G2 saves 2 calls per round, not "half" (5 → 3 calls).
- **The two parts differ in value.** The verifier is the false-positive filter that D-13 names as its reason (`dec:102`). Critics are told to favour false positives (`arch:350`). Without the verifier, every false positive costs a builder call plus a full review round, so removing the verifier likely costs tokens (value 1). The moderator is a model call that only merges and tags. Dedup is already deterministic (`arch:351`), and critics can tag severity themselves.
- **Safety:** none. The human merges, and more findings reaching the builder is not a safety loss.
- **Interactions:** with G3 (the judge role disappears only if both are accepted). With G5: noise outcome `wrong` = "rejected by verifiers" (`arch:356`), so it keeps a source only if the verifier stays.
- **Verdict:** owner decision (D-09, D-13). **Recommend partial:** drop the moderator and build the checklist deterministically from critic-tagged findings; run the verifier (default count 1) only when a round has `Important` findings. Trade-off: nit and pre-existing tags are not verified, which is acceptable because they never block.

## G3 — Replace council + judge
- **Evidence:** correct (`arch:243`, `341-345`; D-06, D-12, D-54). Gemini missed that the council is **owner-stated**: R3 says "Mechanism: a council of an odd number of agents; a decision passes by majority" (`req:23`), and R9's odd counts apply to roles (`req:46-47`).
- **What goes away:** state `deciding` and its two edges; the `council-voter` and `judge` roles (with G2's moderator cut); Question kind `design` and addressee `council` for design questions; D-54's rationale rules; multi-round refinement; council tallies on the Runs screen. ADR rendering can stay (no tokens): it renders from whoever decided.
- **Key fact:** the default council is N = 1 (`dec:73`): one judge plus one voter. That is one model's opinion with an extra call, not a majority. The plan critique (D-51) already gives every plan a second opinion from a distinct profile.
- **Owner loses:** multi-provider voting on design choices, and some Inbox volume moves to the owner (only on planner/critic disagreement, via the existing "second `revise` → parked" path, `arch:242`).
- **Safety:** none. D-22 (changing constraints needs a human) is unaffected.
- **Interactions:** with G2 (role count). Removes the `deciding → planning` part of the fixed order into `red` (A10). No effect on A7, C1 or C2.
- **Verdict:** owner decision (R3, D-06, D-09, D-12, D-54). **Recommend accept** and amend R3 to "every plan is analysed and critiqued (D-51); multi-agent design votes in v2".

## G4 — Collapse budgets
- **Evidence:** correct (`arch:45`, `392`, `406-418`; D-19, D-28). Error: "CLI token reporting is unverified anyway (Q5)" mixes up two things. Q5 is about the provider's *usage window* (`arch:722`); per-Step token usage is a separate "verify" item (`arch:129`). Gemini also drops the token cap entirely, while D-19 and the value-1 test ("every run reports spend against its budget") need token spend at least reported.
- **What goes away (partial version):** the Budget entity and table (10 → 9 entities); two-level reservation; `reserved` accounting; `usd` and `requests` dimensions; group and question scopes; `budget.reserved/charged/released` entries (`refused` stays, so value 5 holds). Spent becomes a projection over `steps`. Caps: item {steps, wall_time, tokens (measured, else estimated)}, run {tokens, steps}, rounds per stage. The token-free plan estimate and the confirm refusal (D-28) stay.
- **Owner loses:** the guarantee that 2 slots never overshoot a run cap. Overshoot is bounded by one in-flight Step per slot.
- **Safety:** none on value 4. D-60 shell traffic to provider hosts becomes recorded and flagged on Health instead of charged; it is still bounded by the step and wall-time caps.
- **Interactions:** **closes C1**, because `requests` (gateway connections) stops being a budget or threshold input, and the threshold uses CLI-reported usage or the known window limit, else `not measured`. Also removes the "move reservations" half of C3.
- **Verdict:** owner decision (D-19, D-28, D-60 wording). **Recommend partial**, as above.

## G5 — Defer breaker, dark routes, review-noise classification
- **Evidence:** correct (`arch:356`, `378`, `435-440`, `540`, `551`). Error: "None in v1" undersells scope. D-03 makes dark routes an agreed **opt-in v1** capability (`dec:31`); only dark-by-default is a non-goal (`req:95`). P13 and P14 are `agreed`.
- **What goes away:** dark routes and the orchestrator's `gh` merge; `Group.autonomy`; breaker counters and trip/reset; polling for reverts and `factory:escaped`; `breaker` CLI; `breaker.*` entries; `dark_routes` and `breaker` config keys. **Keep:** finding outcomes as deterministic telemetry (`arch:356`). They are cheap, they feed the retrospective and value 5, and v2's breaker needs their history.
- **Safety:** positive. Every merge is a human merge, and the one orchestrator-merge path disappears.
- **Interactions:** D-14 ties dark routes to a closed breaker, so defer them together. Goes with G1 (holdout's payoff is dark mode) and G8 (clean-case false alarms, `arch:438`). If G2's verifier is dropped, the outcome `wrong` loses its source.
- **Verdict:** owner decision (D-03 dark part, D-39; P13, P14). **Recommend partial:** defer dark routes and the breaker; keep outcome recording; drop `finding reclassify` (CLI and endpoint) until v2.

## G6 — No answers via GitHub comments
- **Evidence:** correct (`arch:371-374`, `427-432`; ADR-007 answer rules; `hiw:460-477`). D-20's stated reason, "answerable from a phone" (`dec:151`), is what is lost.
- **What goes away:** comment polling for answers (PR, main and label polling stay); the store of factory-created comment ids used for anti-spoofing (markers still give idempotency); the first-line parser; block-quoting as a *safety* rule; A4's whole problem class.
- **Safety:** positive. Only the owner API (token + CSRF, `arch:581-585`) can create a human approval, and agent text on GitHub can no longer be mistaken for an owner answer.
- **Interactions:** none with A7, C1 or C2. Fits G11 (the local UI is the only human write surface).
- **Verdict:** owner decision (D-20). **Recommend accept.** The mirror comment, label and optional macOS notification remain as the phone ping. Trade-off: answers need the Mac.

## G7 — Tester preset collapses into the builder's toolchain
- **Evidence:** correct (`arch:181-188`, `77`; ADR-005 decision 3–4; D-17 `dec:129`). This reverses the A16 fix (`triage.md:24`, `:60`).
- **What goes away:** the `tester` preset (4 → 3 presets), the `factory-run-tests` shim binary, the gateway's `POST /run-tests`, the nested check-Step spawn during a worker Step, and one hostile-worker test.
- **Property lost (precise):** "a test-author Step can execute only the shim and read-only helpers" (D-17 "run only the repo's tests", P15). **The value-4 test still holds.** Writes are limited to test globs by the diff check, the copy is discarded, the Step has no credentials, and the orchestrator's red check runs independently. The test author would run arbitrary local code in its own sandbox, exactly as the builder already does. D-60 already covers test-author shells.
- **Gain beyond simplicity:** the test author iterates on compile errors directly instead of one check Step per attempt (value 1).
- **Verdict:** owner decision (D-17, P15). **Recommend accept**, and record the value-3-over-4 collision in the decision (D-33).

## G8 — Defer the factory eval harness
- **Evidence:** correct (`arch:631-637`, `552`; ADR-007 `local` adapter; D-48). Missed: Q8 relies on eval cases to cover OpenSpec delta kinds (`arch:725`), and the breaker uses clean-case false alarms (`arch:438`).
- **What goes away:** `evals/`, `Run.kind = eval`, `actor_kind = harness`, the `local` GitHub adapter (3 → 2 adapters), seeded-defect and bad-plan scoring, `eval run` and `eval capture`.
- **Owner loses:** offline regression checks for prompt changes before a real run, and D-48's "needed to trust and improve v1". The signal moves to live runs: the journal's tokens per verified outcome, review rounds and escalations (P12 stays).
- **Safety:** none.
- **Verdict:** owner decision (D-48). **Recommend accept**, with the OpenSpec archive delta-kind fixtures moved to `Factory.Core.Tests`.

## G9 — Drop D-62 and restore in `checking`
- **Evidence:** mostly correct (`arch:108`, `192-200`, `206`, `245`, Q6 `arch:723`). Two errors:
  - Sensitive paths do **not** trigger a diff approval before push today. They make the item high risk, which means *plan* approval (`arch:364`). Gemini's safeguard would be a new trigger.
  - The design itself is inconsistent about where restore runs: `building` (`arch:245`), before `building` (`arch:195`), or gate step 1 in `checking` (`arch:600`). Fix this whatever the outcome.
- **Safety, precisely:** D-62 guarantees that no agent-chosen third-party package runs before a human or the allowlist approves it. Under G9, a hallucinated or injected package would be restored in `checking`. NuGet MSBuild targets, analyzers and generators run during build; `--ignore-scripts` covers npm only. After the first failing check, the item overlay feeds the **builder** Step, which has provider-host egress: the D-60 channel, usable with an attacker's API key. Without a new diff-approval trigger, the package would also run in GitHub Actions on push.
- **Also:** G9 does not solve A7's lock-file problem. `--locked-mode` still fails until something regenerates the lock files.
- **Verdict:** **reject as proposed** (D-62's why, `dec:445`; value 4).
- **Counter-proposal (Q65):** keep "approved before restore", but drop the loop back to `planning`. The builder ends `blocked: dependency {id, version, why}`. An allowlisted package is added by the orchestrator, which writes the reference and lock files (orchestrator-only paths) and restores, then the builder is re-issued with that new information. Any other package is one owner Question while the item parks. Declared dependencies in the plan go through the same orchestrator step before `red`. This closes A7 (a)–(c): no re-plan, no re-critique, no re-red.

## G10 — Remove the dead dedicated-user fallback
- **Evidence (Gemini is out of date):** `_afworker` does not appear in any input file. Resume step 1 is generic (`arch:260`). §5 (`arch:228-231`), §18 Q1/Q4 (`arch:718`, `721`), ADR-005:48 and `hiw:134` already reflect D-63 (revision 3a, `arch:788-789`).
- **Leftover:** the `doctor` row in §13 (`arch:534`) still says "guides the owner through the one-time dedicated-user setup … sudoers … (D-61)". Replace it with "a CLI the sandbox cannot hold is reported `unsupported` (D-63)". The rows in §19/§20 are a change log; leave them.
- **Verdict:** **already done** (local one-line fix).

## G11 — Two UI screens and a read-only Config
- **Evidence:** correct for the PR generator (`arch:537`, `591`; ADR-006 "comments are not preserved"). Gemini missed that UI configuration is **owner-stated**: the D-04 amendment says providers and per-role settings "are configured in the factory UI" (`dec:38`), R9 says the same (`req:45-47`), and R2 lists a "config editor" (`req:19`). Gemini also mixes up machine-local edits (`PUT /machine`, provider probe/login, no PR) with the repo-config PR generator.
- **Real saving:** the YAML serializer and PR opener (`POST /config/proposals`, `config propose`) and the comment-loss caveat. Merging 5 screens into 2 saves little, because the projections and endpoints stay the same.
- **Safety:** slightly positive: one fewer owner-API path that writes `.factory/**`.
- **Verdict:** owner decision (D-04 amendment, R2, R9, D-15, D-16, D-42). **Recommend partial:** Config shows the effective config at the commit plus validation errors; providers and `machine.yaml` stay editable; repo config and roles are edited in the IDE with `config validate`; keep the 5-screen layout; the UI repo-config editor comes in v2.

## G12 — Remove the late `reviewing → red` path
- **Evidence:** the mechanics are correct (`arch:244`, `247`, `283`, `623`). Error: "Decisions affected: None". D-52's last sentence is exactly this path: "A late finding can send the item back to `red`" (`dec:374`). It came from round-1 A9 (owner Q51).
- **What goes away:** edges `reviewing → red` and `red → checking`; the base+new-tests checkout in the red check (`red` gets a single mode); the `re-red` answer option on `parked`.
- **Replacement:** a confirmed "e2e should be required" finding becomes an escalation with options: open the PR plus a follow-up issue for the E2E tests (reuses the pre-existing-findings path) / re-plan / accept. It must **not** go to the builder as an ordinary finding, because that would let the builder write tests for its own code (against D-45).
- **Owner loses:** automatic recovery in a case that has already passed two checks before `red` (plan critique + owner confirmation of downgrades).
- **Safety:** none.
- **Interactions:** removes the second red mode that A7(c) also hit; with Q65, `red` has exactly one entry mode.
- **Verdict:** owner decision (D-52). **Recommend accept.**

---

## Combined effect (all recommended cuts applied: G1, G2-partial, G3, G4-partial, G5-partial, G6, G7, G8, G11-partial, G12, Q65 instead of G9, G10 fix)

| Measure | Before | After |
|---|---|---|
| Roles (role files) | 7 | **5**: planner, test author, builder, critic, finding verifier |
| Capability presets | 4 | 3 (`tester` gone) |
| Entities | 10 | 9 (Budget gone) |
| Item states / backward edges | 12 / incl. `planning↔deciding`, `building→planning`, `reviewing→red`, `red→checking` | **11** / those 5 edges gone; nothing added |
| Group states | 6 | 5 (`scenarios` gone) |
| Question kinds | design, verify, escalation | verify, escalation |
| Model calls, typical clean item (1 review round, default counts) | 9 (+2 per design question; +2 per group for holdout) | **8** (7 if no `Important` findings; +0 per design question; +0 per group) |
| Model calls, typical item with 1 fix round | 15 | 13 |
| Model calls, worst case (counts 7, 4 lenses, 3 council rounds, 3 review rounds) | ≈ 70 | ≈ 42 |
| Budget dimensions × scopes; reservation levels | 6 × 4; 2 | 4 (tokens, steps, wall_time, rounds) × 2 (item, run); 0 |
| Board entry types | ~27 | ~22 (−`budget.reserved/charged/released`, −`breaker.*`) |
| CLI command rows (§13) | 20 | 16 (−`config propose`, −`finding reclassify`, −`breaker`, −`eval`) |
| UI screens | 5 | 5 (Config read-only for repo config; machine/providers editable) |
| ADRs | 7 | 7 (ADR-003, -005, -006, -007 shrink) |
| GitHub adapters / extra binaries | 3 / shim | 2 / none |
| Human touches per group | + holdout set approval; GitHub answers possible | − holdout approval; + rare design disagreements; answers only on the Mac |

## Interaction with open items (A7, C1, C2, Q62)
- **A7: closed by Q65** (the G9 counter-proposal). (a) The orchestrator adds the declared reference and regenerates lock files before a locked restore. (b) An undeclared dependency is a dependency request, not a `policy_violation`. (c) There is no return to `planning`, so no re-red. G12 additionally leaves `red` with one mode.
- **C1: closed by Q66** (G4 partial). `requests` (gateway connections) is no longer a budget dimension or a threshold input. Gateway connections and bytes are telemetry flagged on Health; tokens are charged where the CLI reports them, otherwise estimated; D-60 changes "charged" to "recorded and flagged".
- **C2: not touched** by any G finding; it stays a local fix. An optional simplification (the analyst's, not Gemini's): count *new* suppressions in the item diff as a `pr_open` diff-approval trigger, like rule paths, and drop `suppressions` from the ratchet. No baseline arithmetic remains, so C2 cannot occur. Cost: the count on main is guarded per change by SHA-bound approvals instead of by a ratchet.
- **Q62** therefore shrinks to C2 plus the non-blocking A5/B1/C3/C4 items. G4 also removes the reservation half of C3; C4 (discard edits on `blocked`) still applies to Q65's `blocked: dependency`.

## Gemini's "minimum viable factory": element by element
- **3 projects + thin UI:** agree (this is already the design).
- **8 entities (drop Budget and Finding):** agree on Budget (G4). **Disagree** on Finding. No G finding argues for dropping it. Verifier votes, round-2 de-repetition, `disputed[finding_id]`, follow-up issues and outcome telemetry all reference it, and ADR-003 kept it on purpose.
- **11 item states (no `deciding`, no `reviewing → red`):** agree.
- **4 roles:** disagree. Keep the finding verifier (G2): it likely saves tokens.
- **7 calls per clean item:** roughly agree (7–8).
- **Human touchpoints 2–4:** agree, but the MVF lists "unallowlisted dependency" Inbox approval, which contradicts G9's removal of D-62. The MVF is consistent with Q65, not with G9.
- **Deferred list:** agree for G1, G3, G5, G6, G8; partial for G2, G4, G11.
- **"Safety guarantees kept (100% of Value 4)":** disagree. Gemini's own G7 and G9 are tagged "weakens V4". G7's loss is acceptable; G9's is not.
- **Keep-list (5 items):** agree with all five.

## Owner questions (by impact; "yes" accepts the recommendation)

❓ **Q64 — Council out of v1.** Replace the council, the judge and the `deciding` state with design options inside the item plan (planner recommends, plan critique checks, disagreement goes to your Inbox), keep ADR rendering, and amend R3, D-06, D-09, D-12 and D-54 accordingly?
➡️ Yes. The default council is 1 judge + 1 voter, which adds a call but not a majority; D-51 already gives every plan a second opinion.

❓ **Q65 — Dependencies without the planning loop (closes A7).** Keep "approved before restore" (allowlist or you), but when the builder needs a package, have it end `blocked: dependency`, let the orchestrator add the reference and lock files and restore, then re-issue the builder (asking you only for non-allowlisted packages), instead of going back to `planning`?
➡️ Yes. It keeps D-62's supply-chain guarantee that G9 would break and removes the friction from Q6 and all three A7 gaps.

❓ **Q66 — Budgets as caps, not reservations (closes C1).** Drop the Budget entity, reservations, `usd` and `requests`, and the group and question scopes; cap steps, wall time, rounds and tokens (measured or estimated) per item and run, computed from Steps; record and flag gateway traffic instead of charging it (amending D-19, D-28, D-60)?
➡️ Yes. Gateway connections cannot measure requests (C1), and with 2 slots an overshoot is at most one Step per slot.

❓ **Q67 — Holdout scenarios to v2.** Defer holdout scenarios (D-36, D-55, and that part of D-37) to v2 together with dark routes, and instead require visible boundary and negative-path tests from the test author, checked by the spec lens?
➡️ Yes. In light mode you review every PR; holdout costs a group state, a hidden store and an approval per group, and pays off mainly once code merges unread.

❓ **Q68 — Review: no moderator, targeted verifier.** Drop the moderator (the checklist is built deterministically from critic-tagged findings) and run the verifier only when a round has `Important` findings (amending D-13)?
➡️ Yes. The verifier is the token-saving false-positive filter; the moderator is a formatting call.

❓ **Q69 — Autonomy machinery to v2.** Defer dark routes, the circuit breaker and the eval harness (D-03 dark part, D-39, P11 in D-48) to v2, keep finding outcomes as telemetry, and move the OpenSpec archive fixtures into unit tests?
➡️ Yes. Without dark routes every merge is yours, so the breaker has nothing structural to tighten; the journal covers v1 regressions.

❓ **Q70 — The local UI and CLI are your only write surface.** Answer escalations only in the UI or CLI (GitHub mirror becomes notification-only), and edit repo config and roles in your IDE with `config validate` while providers and `machine.yaml` stay editable in the UI (amending D-20, the D-04 amendment, D-15, D-16)?
➡️ Yes. It removes the answer parser with its anti-spoofing rules, and the YAML-to-PR generator; one human approval path is safer.

❓ **Q71 — Two narrow mechanisms out.** Let the test author use the builder's offline toolchain (dropping the `tester` preset, shim and `/run-tests`; amending D-17 and P15), and turn a late "E2E needed" finding into an escalation with a follow-up-issue option instead of `reviewing → red` (amending D-52)?
➡️ Yes. Both keep the value-4 test intact (diff check, discarded copy, independent red check) and each removes a special case from the state machine or the sandbox.
