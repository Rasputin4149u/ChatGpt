# Research To X — Execution Protocol

**Version:** V4 — final candidate for user approval and GitHub storage  
**Status:** READY FOR USER APPROVAL FOR GITHUB STORAGE; NOT YET DEPLOYED  
**Normative source:** `ResearchProtocol_OneDocumentV5.docx`  
**Target repository (after approval):** `Rasputin4149u/ChatGpt`, branch `main`  
**Future bookmarklet button label (exact spelling):** `Reaserch To X`

## 0. Interpretation and authority

- `REQUIRED`: an approved requirement in V5. Apply only within its defined scope.
- `PROPOSED`: suggested behavior not yet approved. Record it; **do not execute it as mandatory**.
- `OPEN`: an unresolved product decision. Ask the user when the decision is needed; do not invent a default.
- `BLOCKED`: execution cannot be completed without an unmet prerequisite. Report it, do not claim completion.
- `IMPLEMENTATION`: technical representation that does not alter product behavior; chosen by the assistant.

**Precedence:** V5 approved requirements > this derived protocol. If they conflict, stop the affected step, cite the conflict, and seek resolution. No assistant-made product policy may override an unresolved V5 decision. The status of a whole V5 subsection must not be inferred from a single sentence: e.g. the fairness principle is established, but its proposed implementation details still require approval.

**Lifecycle:** This is a reviewed protocol candidate for storage, not authorization to immediately process a chat, publish to X, upload to Google Drive, or edit the bookmarklet. GitHub storage follows explicit user approval; activation and publication remain separate decisions. OPEN product decisions are resolved only when needed for the affected operation, without inventing defaults.

## 1. Execution model

### 1.1 Inputs

| ID | Input | Status | Source | Rule |
| --- | --- | --- | --- | --- |
| IN-01 | Research conversation or specified segment | OPEN | Appendix A.3 | The selection mechanism and scope are unresolved. Do not assume the whole conversation. |
| IN-02 | Requested output: Word / X / both | OPEN | Appendix A.3 | Do not choose automatically. |
| IN-03 | X account Premium status | REQUIRED condition | 2.6.1–2.6.2 | Apply the corresponding publication rule only when status is known. Do not infer from previous sessions. |
| IN-04 | Reading-time preference for X | REQUIRED | 2.6.3 | At the end of each research, user chooses: 2–3 min, 3–5 min, 5–7 min, or adaptive/no fixed time. No default. |
| IN-05 | Finality/trigger of research | OPEN | Appendix A.3 | The automatic trigger and how completion is recognized remain undefined. |
| IN-06 | Sources, citations, attachments and available links | REQUIRED when used | 1.6 | Preserve provenance and distinguish unavailable/unverified material. |

### 1.2 Outputs

- `OUT-WORD`: a complete `.docx` research archive, when requested and prerequisites are met (3.1–3.2).
- `OUT-X`: copy-ready plain text for X, when requested and prerequisites are met (2.1–2.6).
- `OUT-ISSUES`: a concise list of blocked steps, missing evidence, and unresolved decisions affecting delivery (1.5, Appendix A.3).
- No automated posting, Google Drive upload, GitHub write, or bookmarklet modification is authorized by this draft.

## 2. Research integrity rules

**R-001 [REQUIRED; 1.2, 1.4]** Extract and preserve the research question/purpose, material follow-up questions, findings, reasoning, final conclusion, corrections, limitations and uncertainty. Do not turn a partial study into a claimed complete study.

**R-002 [REQUIRED principle; 1.3]** Preserve the established fairness objective: the research should fairly consider relevant perspectives and diverse sources even when the user has an initial position. Do not treat the specific implementation bullets in V5 §1.3 (including evidence weighting, source categories, and opposing-view review procedures) as separately approved mandatory steps; see R-003.

**R-003 [PROPOSED implementation; 1.3]** Candidate dimensions: historical, scientific, legal, religious, social, political and other relevant dimensions; these are examples, not a mandatory checklist. The V5 §1.3 implementation proposals also include considering contrary views, broad relevant coverage, diverse primary/academic/official/journalistic/critical sources, distinguishing facts from interpretations/hypotheses/suspicions, assessing conflicting claims by evidence quality rather than automatic equal weight, allowing conclusions contrary to the initial position, and not selectively excluding material counterevidence. Preserve all as proposals pending approval, not operational gates.

**R-004 [REQUIRED; 1.4]** When a later correction was accepted, use the corrected meaning; do not revive a withdrawn claim. Preserve the distinction between **“מוטלות בספק”** (open to doubt) and **“לא אמינות”** (unreliable).

**R-005 [REQUIRED; 1.4]** Keep open questions and evidentiary limitations visible. Never elevate possibility to certainty, suspicion to proof, or criticism to total invalidation.

**R-006 [REQUIRED; 1.6]** Every externally sourced research claim needs traceable attribution. Show online references as full visible URLs. Distinguish verbatim quotation, translation, paraphrase and interpretation; translate foreign-language quotes into Hebrew for Hebrew publication and identify the translation. Never fabricate source URLs or quotations. Label unavailable or unverified sources; comply with copyright and quotation limits.

**R-007 [PROPOSED; 1.5, Appendix B.3.1]** A pre-publication research-gap review is proposed, not approved. V5 §1.5 gives five example gap types: (1) relevant perspective not examined; (2) claim without source support; (3) unresolved contradiction; (4) conclusion inconsistent with presented evidence; (5) missing or unidentified link. Appendix B.3.1 separately gives eight illustrative questions: (1) fitness of method to research question; (2) expert's field and limits of expertise; (3) who selected samples and sampling bias; (4) funding and potential conflicts; (5) blinded testing; (6) availability of raw data; (7) independent replication; (8) whether conclusions exceed measured results. These are examples, not findings against a particular expert and not a mandatory gate. Do not activate until approved.

**R-008 [OPEN; 1.5]** If a substantive gap exists, policy is undecided between (A) notify only and (B) notify and suggest further research. Do not choose a policy for the user.

## 3. Transforming research content

**T-001 [REQUIRED; 2.3, 2.4.8, 2.5]** Remove irrelevant timestamps, interface artifacts, greetings, technical acknowledgements and operational commentary from publication outputs. Preserve material questions, revisions, evidence and reasoning.

**T-002 [REQUIRED; 1.4, 2.3, 2.5]** Preserve logical continuity and exact meaning when editing. Never omit substantive caveats or evidence to create a stronger conclusion.

**T-003 [PROPOSED; 2.3]** Consolidating repetitive passages and removing redundant technical exchanges are suggested editorial techniques, not independently approved permissions to discard material.

**T-004 [OPEN; 2.3, Appendix A.3]** Whether to preserve Q&A format or rewrite as continuous article, and how much editing is allowed, is unresolved. Do not silently decide the presentation model.

**T-005 [OPEN; Appendix A.3]** Missing URLs and incomplete source references require a user-approved handling policy. Never invent them; explicitly disclose missing/unverified references under R-006.

## 4. X output rules

**X-001 [REQUIRED; 2.2]** Present content in this order: (1) research purpose/question; (2) visual separator; (3) final conclusion; (4) visual separator; (5) research, findings and sources when that portion belongs to the chosen publication mode. The stated objective is to invite the reader into the research. **X-001a [PROPOSED; 2.2]:** Specific writing rules for an engaging question, accurate conclusion and non-exaggeration remain proposed; do not treat them as independently approved implementation requirements. All REQUIRED integrity rules elsewhere still apply.

**X-002 [REQUIRED; 2.4.1–2.4.6]** Output copy-ready plain text. Place the main title on its own line; use short clear headings and **numbered section headings** for the research body, with a clear purpose/conclusion/research hierarchy. Use short paragraphs, blank lines where needed, natural wrapping, visible full URLs and correct Hebrew/English directionality. Do not rely on Markdown bold syntax, Word formatting, fixed-width layout or alignment made from spaces.

**X-003 [REQUIRED; 2.4.4]** Use a short consistent textual separator. Its exact characters and length are OPEN pending compatibility tests; do not claim a fixed separator was approved.

**X-004 [REQUIRED; 2.4.7]** No tables in X text. Convert each table to numbered entries, separate records or verbal comparisons while retaining column/row meanings and material relationships. Do not simulate columns with spaces.

**X-005 [REQUIRED; 2.4.5, 2.4.9–2.4.10]** Preserve full URL visibility and account for X's link-counting mechanism when checking length. Before final operational activation for a chosen X post mode, verify current X publication limits applicable to that mode; at output time recheck limits if needed. Do not hardcode unverified numeric limits. V5 requires verification before final protocol approval: if that external verification has not occurred, record it as a **pending operational acceptance test**, not as passed. X paste/copy compatibility for Hebrew, English and mixed text is likewise a pending live test, not a claimed result.

**X-006 [REQUIRED; 2.6.1]** For an account **without Premium**, show the research question and conclusion in the prescribed order and provide an accessible Google Drive link to the **full Word document** in place of the full research body on X. A link may be presented only after its existence and accessibility have been verified. If no verified link exists, do not present a fabricated link or claim that link delivery is complete. Report the missing dependency; **do not block other independently deliverable outputs**. The broader handling policy remains OPEN (O-09).

**X-007 [REQUIRED; 2.6.2–2.6.4]** For an account **with Premium**, create a readable, proportionate summary rather than filling the maximum length. Preserve central evidence, substantive caveats and uncertainty. The complete Word document remains separate.

**X-008 [REQUIRED; 2.6.3]** Ask the user to choose an approximate reading time at the end of each research: **2–3 / 3–5 / 5–7 minutes / adaptive**. Reading time is a target, not a strict character limit.

**X-009 [OPEN; 2.1, 2.4.10, Appendix A.3]** Single standard post vs long post vs thread; segmentation; placement of many sources; exact separator; and mixed-language paste tests remain unresolved.

## 5. Word output rules

**W-001 [REQUIRED; 3.1]** Produce a full `.docx` archival research document, without X's length limits. Retain research content, evidence, citations, conclusions and limitations.

**W-002 [REQUIRED; 3.2]** Use minimal styling only: bold, underline and font-size variation. Apply consistent conceptual heading treatment without adding unapproved visual styling. For Hebrew text use appropriate RTL; maintain readable bilingual order and copy/paste integrity. **W-002a [PROPOSED; 3.2]:** Consider headings written wholly in Hebrew or wholly in English, as appropriate; V5 expresses this as a preference to consider, not a mandatory language restriction.

**W-003 [REQUIRED; 3.2]** Omit timestamps. Display URLs in full. Render tables as rows of fields separated by literal `|`, including header rows, preserving field boundaries, headers and meaning without relying on visual spacing or column alignment.

**W-004 [OPEN; 3.1.1, Appendix A.3]** Whether and how to use Word footnotes is undecided. Do not infer that footnotes are rejected.

**W-005 [OPEN dependency; 2.6.1, Appendix A.3]** The process for uploading the completed Word file to Google Drive, configuring sharing, and checking the resulting link is not specified. Verification of a link before claiming it exists is an implementation safeguard, **not authorization to upload or a policy to block the entire deliverable**. Report the missing dependency for the affected non-Premium link; other outputs remain independent.

## 6. Stop conditions and user decisions

When an OPEN item prevents an affected output, report: (1) the unresolved decision, (2) its V5 reference, (3) the precise operation it blocks, and (4) the choices actually stated in V5, if any. Do not invent an option or silently choose a default. Unaffected work may be prepared, but must not be represented as a completed blocked deliverable.

Open decision register:

| ID | Decision still required | V5 source |
| --- | --- | --- |
| O-01 | Scope of conversation/research and start/end trigger | Appendix A.3 |
| O-02 | Word, X, or both | Appendix A.3 |
| O-03 | Standard post, long post, thread; segmentation; separators; source placement | 2.1, 2.4.10, Appendix A.3 |
| O-04 | Q&A vs continuous article; editing latitude | 2.3, Appendix A.3 |
| O-05 | Whether to adopt research quality review and how to handle gaps | 1.5, Appendix A.3 |
| O-06 | Handling of missing sources beyond required disclosure | 1.6, Appendix A.3 |
| O-07 | Word footnotes | 3.1.1, Appendix A.3 |
| O-08 | Whether each final publication requires review/approval | Appendix A.3 |
| O-09 | Google Drive upload/sharing verification workflow | 2.6.1, Appendix A.3 |
| O-10 | Final protocol filename and exact bookmarklet invocation | Appendix A.3 |

## 7. Quality assurance and approval gates

**Q-000 [REQUIRED; Appendix A.4.1–A.4.3] Joint specification review:** The user and assistant review the **entire V5 specification together**, record comments and unresolved decisions, and establish an agreed specification before treating this as a fully operational protocol. This technical translation is prepared for approval and GitHub storage; its existence does not imply that every OPEN product decision has been resolved. No approved requirement may be added, removed or changed during translation.

**Q-000a [REQUIRED / PROPOSED distinction; Appendix A.2.1–A.2.3] Specification governance:** Maintain **one central specification document** and develop it incrementally. Do not promote proposals to requirements without user approval, or divert specification work to nonessential technical troubleshooting. GitHub is the preferred eventual storage location, but V5 records an earlier HTTP 403 failure and **no verified GitHub save**. Appendix A.2.3 separately **proposes**, without yet requiring, updating the specification after decisions, preserving the approved/proposed distinction, preventing loss of earlier decisions and checking completeness before finalization. These proposed maintenance steps must not be silently promoted to mandatory workflow.


**Q-001 [REQUIRED; Appendix A.4.4] Completeness check:** Compare every approved V5 requirement with an implementation rule or explicitly recorded dependency. List unmapped requirements.

**Q-002 [REQUIRED; Appendix A.4.4] Unambiguity check:** Find conflicting instructions, unclear scope, missing prerequisites and accidental promotion of PROPOSED/OPEN to REQUIRED.

**Q-003 [REQUIRED; Appendix A.4.4] Feasibility check:** Walk through scenarios involving missing sources, unresolved research, bilingual text, tables, long posts, non-Premium users, inaccessible Drive links and absent external capabilities. Do not claim live testing without performing it.

**Q-004 [REQUIRED; Appendix A.4.4–A.4.5]** Correct defects that can be corrected without new product decisions, rerun relevant checks, then show the protocol and findings to the user. **User approval is mandatory before implementation.** Approval to store this protocol on GitHub does not itself authorize unresolved product behavior or bookmarklet integration.

**Q-005 [REQUIRED; Appendix A.4.6]** After final user approval, upload the approved protocol to `Rasputin4149u/ChatGpt` on `main` and verify the stored content matches the approved version. Report permission errors truthfully.

**Q-006 [REQUIRED; Appendix A.4.7]** Only after verified GitHub storage, integrate the exact `Reaserch To X` button into the existing bookmarklet. Preserve existing buttons and test the new action. No code change during specification work (Appendix A.1.3).

## 8. Three independent pre-upload reviews — V4

### Review 1 — Treat as a newly uploaded candidate: completeness

- Compared against the three V5 chapters and Appendices A and B; mapped each numbered V5 section to the rules and OPEN register below.
- Confirmed the previously identified V2 omissions are represented: five gap examples; eight example audit questions; numbered X headings; language-specific heading suggestion; joint review; specification governance; pipe-separated Word tables.
- The V5 proposals remain PROPOSED; no absent source, missing link, or unresolved decision is represented as settled.
- **Result: PASS for faithful transcription and GitHub-storage candidacy; conditional for actual execution where OPEN decisions apply.**

### Review 2 — Treat as a newly uploaded candidate: ambiguity and authority

- Confirmed status vocabulary is restricted to REQUIRED / PROPOSED / OPEN / BLOCKED / IMPLEMENTATION, with qualifying descriptors only.
- Confirmed the proposed writing guidance in V5 §2.2 is not promoted to REQUIRED.
- Confirmed a missing Drive link cannot be fabricated and does not block independent outputs.
- Confirmed approval to store on GitHub is distinct from authorization to modify the bookmarklet or publish research.
- **Result: PASS for interpretation; remaining OPEN items are explicitly identified rather than guessed.**

### Review 3 — Treat as a newly uploaded candidate: feasibility

| Scenario | Expected response | Classification |
| --- | --- | --- |
| Research scope unspecified | Ask for affected scope, do not assume whole chat | OPEN O-01 |
| Word/X output unspecified | Ask for intended output | OPEN O-02 |
| Reading time not selected | Offer the four V5 choices without default | REQUIRED IN-04 |
| Unverified source or URL | Label as unavailable/unverified, never fabricate | REQUIRED R-006 |
| Research with substantive gaps | Do not activate proposed review or gap-handling policy without decision | PROPOSED / OPEN |
| Hebrew/English mixed text | Prepare RTL-compatible Word and X text; live paste test remains outstanding | REQUIRED / external test |
| Original research table | Word: literal pipe-delimited fields; X: structured text, not a table | REQUIRED |
| Non-Premium with no verified Drive link | Prepare independent deliverables; do not claim X link completed | REQUIRED / OPEN O-09 |
| X post length/URL counting unknown | Verify current limits for selected mode before operational activation | external test |
| GitHub upload rejected (e.g. HTTP 403) | Report failure; do not claim deployment or modify bookmarklet | REQUIRED Q-005/006 |

- **Result: PASS for coherent conditional execution paths; live X, Google Drive and bookmarklet tests NOT PERFORMED.**

### Section coverage index (V5 → V4)

| V5 section | V4 coverage |
| --- | --- |
| 1.1–1.2 | 1, R-001, T-001 |
| 1.3 | R-002, R-003 |
| 1.4 | R-001, R-004, R-005, T-002 |
| 1.5 | R-007, R-008, O-05 |
| 1.6 | R-006, T-005 |
| 2.1–2.2 | X-001, X-001a, X-009 |
| 2.3 | T-001–T-005 |
| 2.4.1–2.4.10 | X-002–X-005, X-009 |
| 2.5 | T-001–T-003 |
| 2.6.1–2.6.4 | IN-03, IN-04, X-006–X-008, W-005 |
| 3.1–3.1.1 | W-001, W-004 |
| 3.2 | W-002, W-002a, W-003 |
| Appendix A.1 | Q-005, Q-006 |
| Appendix A.2 | Q-000a |
| Appendix A.3 | O-01–O-10 |
| Appendix A.4 | Q-000–Q-006 |
| Appendix B | R-004, R-007, X-001 |

**Release boundary:** This version is complete as a *faithful, conditional GitHub-storable protocol*. It is **not** a claim that unresolved V5 product decisions have been approved or that live external integration tests have passed. The user may approve uploading this exact version; further operational decisions are requested only when their affected feature is actually used.
