import os, sys, shutil
root = sys.argv[1]
cases_dir = os.path.join(root, "cases")
shutil.rmtree(cases_dir, ignore_errors=True)

def req(name, text, scen):
    s = f"### Requirement: {name}\n{text}\n"
    for sn, w, t in scen:
        s += f"\n#### Scenario: {sn}\n- **WHEN** {w}\n- **THEN** {t}\n"
    return s

def sec(title, body): return f"## {title} Requirements\n\n{body}\n"

def case(cid, desc, spec_files, tasks_done=True, extra=None, flags="-y", yaml="schema: spec-driven\n", pre=None):
    cdir = os.path.join(cases_dir, cid)
    chg = os.path.join(cdir, "changes", cid)
    os.makedirs(chg, exist_ok=True)
    open(os.path.join(cdir, "case.md"), "w").write(f"# {cid}\n\n{desc}\n\nCLI flags: `{flags}`\n")
    open(os.path.join(cdir, "flags"), "w").write(flags + "\n")
    open(os.path.join(chg, ".openspec.yaml"), "w").write(yaml)
    open(os.path.join(chg, "proposal.md"), "w").write(f"## Why\n\nFixture for archive case `{cid}`, kept as a reference for the spec adapter unit fixtures.\n\n## What Changes\n\n{desc}\n")
    mark = "x" if tasks_done else " "
    open(os.path.join(chg, "tasks.md"), "w").write(f"## 1. Work\n\n- [{mark}] 1.1 Do the thing\n")
    for rel, content in (pre or {}).items():
        pd = os.path.join(cdir, "pre", os.path.dirname(rel)); os.makedirs(pd, exist_ok=True)
        open(os.path.join(cdir, "pre", rel), "w").write(content)
    for cap, content in spec_files.items():
        d = os.path.join(chg, "specs", cap); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "spec.md"), "w").write(content)

A_NEW = req("Alpha reservation", "The system SHALL reserve stock and also log the reservation id.", [
    ("Reserve available stock", "a reservation is requested for an item with enough stock", "the available count is reduced and the reservation id is logged"),
    ("Reserve unavailable stock", "a reservation is requested for more than the available stock", "the reservation is rejected")])
B_NEW = req("Bravo release", "The system SHALL release a reservation when it is cancelled or expires.", [
    ("Cancel reservation", "a reservation is cancelled", "the reserved quantity returns to the available count"),
    ("Expired reservation", "a reservation passes its expiry time", "the reserved quantity returns to the available count")])
D_NEW = req("Delta export", "The system SHALL export the stock table as CSV or JSON on request.", [
    ("Export requested", "an export is requested", "a CSV file with one row per item is produced")])
E_NEW = req("Echo low-stock alert", "The system SHALL raise an alert when stock falls below the threshold.", [
    ("Below threshold", "the available count drops below the threshold", "an alert is raised"),
    ("At threshold", "the available count equals the threshold", "no alert is raised")])
F_NEW = req("Foxtrot stock import", "The system SHALL import stock levels from a CSV file.", [
    ("Import file", "a CSV file is imported", "the stock levels are replaced by the file contents")])
C_REM = "### Requirement: Charlie audit log\n**Reason**: Audit moves to a central service.\n**Migration**: Read audit entries from the central service.\n"

case("h01-added-new-capability", "ADDED only, target capability `notifications` does not exist yet (new spec file is created).",
     {"notifications": sec("ADDED", req("Email notice", "The system SHALL send an email when an order ships.", [("Order shipped", "an order ships", "an email is sent to the customer")]))})
case("h02-added-existing", "ADDED to an existing capability: appended after the existing requirements, in delta order.",
     {"inventory": sec("ADDED", E_NEW + "\n" + F_NEW)})
case("h03-modified", "MODIFIED replaces the whole block in place (position kept). Alpha gets new text and a new scenario; Bravo is untouched.",
     {"inventory": sec("MODIFIED", A_NEW.replace("#### Scenario: Reserve unavailable stock", "#### Scenario: Reservation id logged\n- **WHEN** a reservation succeeds\n- **THEN** its id is written to the log\n\n#### Scenario: Reserve unavailable stock"))})
case("h04-removed", "REMOVED deletes the block (Charlie, a middle requirement). The Reason/Migration text only documents the removal; it is not merged.",
     {"inventory": sec("REMOVED", C_REM)})
case("h05-renamed", "RENAMED changes only the header; body and scenarios are kept; position kept.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo cancellation`\n"})
case("h06-all-kinds", "All four kinds in one capability, with sections written in the reverse of the apply order (ADDED first). RENAMED + MODIFIED of the renamed block (MODIFIED uses the NEW header). Also REMOVED, MODIFIED, ADDED x2. A second capability gets only a MODIFIED.",
     {"inventory":
        sec("ADDED", E_NEW + "\n" + F_NEW) + "\n" +
        sec("MODIFIED", B_NEW.replace("Bravo release", "Bravo cancellation") + "\n" + D_NEW) + "\n" +
        sec("REMOVED", C_REM) + "\n" +
        "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo cancellation`\n",
      "billing": sec("MODIFIED", req("Invoice creation", "The system SHALL create exactly one invoice per completed order and email it.", [("Order completed", "an order is completed", "exactly one invoice is created and emailed")]))})
case("h07-multi-capability", "One change touching three capabilities: existing inventory (ADDED), existing billing (ADDED), new shipping (ADDED).",
     {"inventory": sec("ADDED", E_NEW), "billing": sec("ADDED", req("Refund", "The system SHALL refund a cancelled invoice.", [("Cancelled", "an invoice is cancelled", "the amount is refunded")])),
      "shipping": sec("ADDED", req("Label", "The system SHALL print a label per parcel.", [("Parcel packed", "a parcel is packed", "a label is printed")]))})
case("h08-remove-all", "REMOVED the only requirement of billing: what happens to the now empty spec file?",
     {"billing": sec("REMOVED", "### Requirement: Invoice creation\n**Reason**: Billing is outsourced.\n**Migration**: Use the external provider.\n")})
case("h09-removed-and-added-back", "ADDED of a new name plus REMOVED of the first requirement in the same capability: the added block lands at the end, the removed one is gone (REMOVED+ADDED of the SAME name is a conflict, see e07).",
     {"inventory": sec("ADDED", E_NEW) + "\n" + sec("REMOVED", "### Requirement: Alpha reservation\n**Reason**: Superseded.\n**Migration**: None.\n")})
case("h10-rename-chain-position", "RENAMED of the first and the last requirement in one change: both keep their positions.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Alpha reservation`\n- TO: `### Requirement: Alpha hold`\n- FROM: `### Requirement: Delta export`\n- TO: `### Requirement: Delta csv export`\n"})
case("h11-idempotent-added", "ADDED whose block is byte-identical to an existing requirement (early-sync pattern): treated as already applied.",
     {"inventory": sec("ADDED", req("Alpha reservation", "The system SHALL reserve stock when a reservation is requested.", [
        ("Reserve available stock", "a reservation is requested for an item with enough stock", "the available count is reduced by the reserved quantity"),
        ("Reserve unavailable stock", "a reservation is requested for more than the available stock", "the reservation is rejected")]))})
case("h12-removed-missing", "REMOVED of a requirement that is not in the spec: warning, treated as already removed (only an ADDED is also applied so the archive does something).",
     {"inventory": sec("ADDED", E_NEW) + "\n" + sec("REMOVED", "### Requirement: Zulu does not exist\n**Reason**: n/a\n**Migration**: n/a\n")})
case("h13-skip-specs", "Same delta as h02 but archived with --skip-specs: main specs untouched, change folder still moved.",
     {"inventory": sec("ADDED", E_NEW)}, flags="-y --skip-specs")
case("h14-incomplete-tasks", "ADDED delta, but tasks.md has an unchecked task, archived with -y.",
     {"inventory": sec("ADDED", E_NEW)}, tasks_done=False)
case("h15-modified-whitespace-header", "MODIFIED header with two spaces after the colon and a trailing space (`### Requirement:  Alpha reservation `): still matches; the block is written back verbatim, whitespace included.",
     {"inventory": sec("MODIFIED", "### Requirement:  Alpha reservation \nThe system SHALL reserve stock (whitespace variant header).\n\n#### Scenario: Reserve available stock\n- **WHEN** x\n- **THEN** y\n\n#### Scenario: Reserve unavailable stock\n- **WHEN** x\n- **THEN** y\n")})
case("h16-modified-renamed-scenario", "MODIFIED that renames one scenario (Reserve unavailable stock -> Reserve too much) instead of keeping it: scenario names are matched.",
     {"inventory": sec("MODIFIED", A_NEW.replace("Reserve unavailable stock", "Reserve too much"))})

# error cases
case("e01-modified-missing", "MODIFIED of a requirement that does not exist.",
     {"inventory": sec("MODIFIED", req("Zulu nothing", "The system SHALL do nothing.", [("None", "a", "b")]))})
case("e02-added-existing-different", "ADDED with the name of an existing requirement but different content.",
     {"inventory": sec("ADDED", A_NEW)})
case("e03-modified-drops-scenario", "MODIFIED block that omits an existing scenario (Reserve unavailable stock).",
     {"inventory": sec("MODIFIED", req("Alpha reservation", "The system SHALL reserve stock.", [("Reserve available stock", "w", "t")]))})
case("e04-renamed-source-missing", "RENAMED whose FROM does not exist (and TO does not exist either).",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Zulu nothing`\n- TO: `### Requirement: Zulu something`\n"})
case("e05-renamed-target-exists", "RENAMED whose TO is an existing requirement.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Alpha reservation`\n- TO: `### Requirement: Bravo release`\n"})
case("e06-modified-old-name-after-rename", "RENAMED Bravo then MODIFIED under the OLD header (must use the NEW one).",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo cancellation`\n\n" + sec("MODIFIED", B_NEW)})
case("e07-added-and-removed-same", "Same requirement name in ADDED and REMOVED.",
     {"inventory": sec("ADDED", E_NEW) + "\n" + sec("REMOVED", "### Requirement: Echo low-stock alert\n**Reason**: r\n**Migration**: m\n")})
case("e08-modified-on-new-spec", "MODIFIED against a capability that has no spec yet.",
     {"notifications": sec("MODIFIED", req("Email notice", "The system SHALL send email.", [("S", "w", "t")]))})
case("e09-empty-delta", "Delta spec file with no ADDED/MODIFIED/REMOVED/RENAMED sections.",
     {"inventory": "## Notes\n\nNothing to apply here.\n"})
case("e10-case-near-miss", "ADDED name differs from existing only in case (`alpha Reservation`).",
     {"inventory": sec("ADDED", req("alpha Reservation", "The system SHALL do a different thing.", [("S", "w", "t")]))})
case("e11-duplicate-in-section", "Two MODIFIED blocks with the same header in one delta.",
     {"inventory": sec("MODIFIED", D_NEW + "\n" + D_NEW)})
case("e12-no-shall", "ADDED requirement text without SHALL/MUST: archive succeeds (exit 0); only the later strict validate warns.",
     {"inventory": sec("ADDED", req("Echo low-stock alert", "The system raises an alert when stock is low.", [("Below", "w", "t")]))})
case("e13-no-scenario", "ADDED requirement without any scenario: validation failure.",
     {"inventory": sec("ADDED", "### Requirement: Echo low-stock alert\nThe system SHALL raise an alert when stock is low.\n")})
case("e14-atomicity", "Two capabilities: inventory delta is valid (ADDED), billing delta fails (MODIFIED of a missing requirement). Is inventory still written?",
     {"inventory": sec("ADDED", E_NEW), "billing": sec("MODIFIED", req("Zulu nothing", "The system SHALL do nothing.", [("S", "w", "t")]))})
case("e15-removed-with-scenarios-block-form", "REMOVED written as full requirement blocks (with scenarios) instead of name + Reason/Migration.",
     {"inventory": sec("REMOVED", req("Charlie audit log", "The system SHALL write an audit entry for every stock change.", [("Audit entry written", "the available count changes", "an audit entry with the old and new count is stored")]))})
case("e16-renamed-and-removed", "RENAMED and REMOVED of the same source name (cross-section conflict).",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo cancellation`\n\n" + sec("REMOVED", "### Requirement: Bravo release\n**Reason**: r\n**Migration**: m\n")})
case("e17-rename-unpaired", "RENAMED section with a FROM but no TO.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n"})
case("e18-orphan-requirement", "Requirement written under a non-delta `## Requirements` header: silently ignored or error?",
     {"inventory": "## Requirements\n\n" + E_NEW})
case("e19-misspelled-header", "Section header `## added requirements` (lower case) plus a requirement under `## ADD Requirements`; the second one makes the whole archive abort, so a lower-case header merging is not shown.",
     {"inventory": "## added requirements\n\n" + E_NEW + "\n## ADD Requirements\n\n" + F_NEW})
case("e20-purpose-on-existing", "Delta contains a `## Purpose` for an existing capability, plus an ADDED requirement.",
     {"inventory": "## Purpose\nA different purpose text that is long enough to pass the validator without complaint.\n\n" + sec("ADDED", E_NEW)})
case("e21-new-spec-with-purpose", "New capability whose delta carries a Purpose section.",
     {"notifications": "## Purpose\nSend notifications to customers about the state of their orders and shipments.\n\n" + sec("ADDED", req("Email notice", "The system SHALL send an email when an order ships.", [("Order shipped", "an order ships", "an email is sent to the customer")]))})
case("e22-new-spec-removed-only", "REMOVED against a capability with no spec (nothing else).",
     {"notifications": sec("REMOVED", "### Requirement: Email notice\n**Reason**: r\n**Migration**: m\n")})
case("e23-no-specs-dir", "Change with no specs/ folder at all (proposal and tasks only), archived without --skip-specs.", {})
case("h17-retire-capability", "REMOVED the last requirement of billing with `retire_capabilities: true` in the change's .openspec.yaml: the spec file is deleted.",
     {"billing": sec("REMOVED", "### Requirement: Invoice creation\n**Reason**: Billing is outsourced.\n**Migration**: Use the external provider.\n")},
     yaml="schema: spec-driven\nretire_capabilities: true\n")
case("h18-archive-target-exists", "The archive folder `<date>-<change>` already exists (pre-created): archive must refuse.",
     {"inventory": sec("ADDED", E_NEW)}, pre={"openspec/changes/archive/@DATE@-h18-archive-target-exists/proposal.md": "old\n"})
case("h19-json-output", "Same delta as h02 with --json: machine-readable output.", {"inventory": sec("ADDED", E_NEW)}, flags="-y --json")
case("h20-idempotent-modified", "MODIFIED whose block is identical to the current block: no-op (`already in sync`).",
     {"inventory": sec("MODIFIED", req("Delta export", "The system SHALL export the stock table as CSV on request.", [("Export requested", "an export is requested", "a CSV file with one row per item is produced")]))})
case("h21-idempotent-rename", "RENAMED whose TO already exists and FROM is gone (early-sync): no-op. Pre-state: base spec is replaced by one where Bravo is already called `Bravo cancellation`.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo cancellation`\n"},
     pre={"openspec/specs/inventory/spec.md": open(os.path.join(root, "base/openspec/specs/inventory/spec.md")).read().replace("Bravo release", "Bravo cancellation")})
case("h22-skip-specs-metadata", "Change without deltas but `skip_specs: true` in .openspec.yaml (pure tooling change).", {}, yaml="schema: spec-driven\nskip_specs: true\n")
case("e24-modified-lowercase-name", "MODIFIED header differs from the existing one only in case (`alpha reservation`).",
     {"inventory": sec("MODIFIED", req("alpha reservation", "The system SHALL reserve stock.", [("Reserve available stock", "w", "t"), ("Reserve unavailable stock", "w", "t")]))})
case("e25-modified-no-shall", "MODIFIED requirement text without SHALL/MUST.",
     {"inventory": sec("MODIFIED", req("Delta export", "The system exports the table.", [("Export requested", "w", "t")]))})
case("e26-modified-and-removed-same", "Same name in MODIFIED and REMOVED.",
     {"inventory": sec("MODIFIED", D_NEW) + "\n" + sec("REMOVED", "### Requirement: Delta export\n**Reason**: r\n**Migration**: m\n")})
case("e27-modified-and-added-same", "Same name in MODIFIED and ADDED.",
     {"inventory": sec("MODIFIED", D_NEW) + "\n" + sec("ADDED", D_NEW)})
case("e28-renamed-to-collides-with-added", "RENAMED TO equals the name of an ADDED requirement.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Echo low-stock alert`\n\n" + sec("ADDED", E_NEW)})
case("e29-renamed-duplicate-from", "Two RENAMED pairs with the same FROM.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo one`\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo two`\n"})
case("e30-renamed-source-near-miss", "RENAMED FROM differs from the existing name only in case.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: bravo release`\n- TO: `### Requirement: Bravo cancellation`\n"})
case("e31-removed-near-miss", "REMOVED name differs from the existing name only in case (hard error, unlike a totally absent name, see h12).",
     {"inventory": sec("REMOVED", "### Requirement: charlie audit log\n**Reason**: r\n**Migration**: m\n")})
case("e14b-atomicity-later-capability-fails", "billing (alphabetically first) is valid, inventory (later) fails: is the billing spec still written? Distinguishes all-or-nothing from write-per-capability.",
     {"billing": sec("ADDED", req("Refund", "The system SHALL refund a cancelled invoice.", [("Cancelled", "an invoice is cancelled", "the amount is refunded")])),
      "inventory": sec("MODIFIED", req("Zulu nothing", "The system SHALL do nothing.", [("S", "w", "t")]))})
case("h23-renamed-from-reused-by-added", "RENAMED Bravo release to Bravo cancellation AND ADDED a new requirement named `Bravo release`: allowed (rename applies before add); the renamed block keeps its slot, the new one goes last.",
     {"inventory": "## RENAMED Requirements\n\n- FROM: `### Requirement: Bravo release`\n- TO: `### Requirement: Bravo cancellation`\n\n" + sec("ADDED", req("Bravo release", "The system SHALL release a hold when its owner asks.", [("Owner asks", "the owner asks", "the hold is released")]))})
case("e32-modified-no-scenario", "MODIFIED block without any scenario.",
     {"inventory": sec("MODIFIED", "### Requirement: Delta export\nThe system SHALL export the stock table as CSV on request.\n")})
case("e33-renamed-on-new-spec", "RENAMED against a capability that has no spec yet.",
     {"notifications": "## RENAMED Requirements\n\n- FROM: `### Requirement: Email notice`\n- TO: `### Requirement: Mail notice`\n"})
print("cases:", len(os.listdir(cases_dir)))
