# Capture List

Screenshots worth taking as the detection engineering work is done. These turn the write-ups into a portfolio.

## Rules

- Save as `images/<short-descriptive-name>.png`
- Crop to the relevant panel, not the whole screen
- Blur tenant IDs, subscription GUIDs and anything not lab data
- Name by what it shows, not by date
- Capture the moment it works, not afterwards

---

## 01 and 02 - Detection as Code

| Capture | File | Done |
| --- | --- | :---: |
| The detection repository structure in an editor | `repo-layout.png` | [ ] |
| A Sigma rule open, with its tags and tests | `sigma-rule.png` | [ ] |
| `sigma convert` producing Wazuh and Sentinel output | `sigma-convert.png` | [ ] |
| The CI pipeline run, all checks green | `ci-passing.png` | [ ] |
| A pull request showing the review gate | `pr-gate.png` | [ ] |
| The git log of a rule, showing why it changed | `rule-history.png` | [ ] |
| The two old rules found broken during migration | `broken-rule-found.png` | [ ] |

**`broken-rule-found.png` is the best story in this project.** A rule that looked healthy in the console but had never fired, exposed by a real test. Capture it.

---

## 03 and 04 - Threat Hunting

| Capture | File | Done |
| --- | --- | :---: |
| A hypothesis written in the IF-THEN-IN-THAT shape | `hunt-hypothesis.png` | [ ] |
| The beacon hunt, low jitter results (H-0001) | `hunt-beacon.png` | [ ] |
| The stack-counting hunt, rare autorun value (H-0002) | `hunt-rare.png` | [ ] |
| A pivot from the first finding to the root cause | `hunt-pivot.png` | [ ] |
| A completed hunt write-up | `hunt-writeup.png` | [ ] |

**`hunt-beacon.png` should show the jitter column.** Near-zero jitter next to a public IP is the whole hunt in one screenshot.

---

## 05 - Adversary Emulation

| Capture | File | Done |
| --- | --- | :---: |
| `Invoke-AtomicTest -ShowDetailsBrief` output | `atomic-details.png` | [ ] |
| A technique running and the alert firing within seconds | `atomic-detected.png` | [ ] |
| The emulation results table, detected versus gaps | `emulation-results.png` | [ ] |
| A closed gap: new rule firing on re-emulation | `gap-closed.png` | [ ] |
| The weekly regression run | `regression-run.png` | [ ] |

---

## 06 - Detection Coverage

| Capture | File | Done |
| --- | --- | :---: |
| The ATT&CK Navigator coverage layer | `navigator-coverage.png` | [ ] |
| The script generating the layer from the rules | `layer-generator.png` | [ ] |
| The gap register | `gap-register.png` | [ ] |

**`navigator-coverage.png` is a strong portfolio image.** The heatmap with honest grey columns for Collection and Exfiltration shows you measure coverage rather than claim it.

---

## 07 - Malware Triage

| Capture | File | Done |
| --- | --- | :---: |
| Static analysis: strings revealing intent | `triage-strings.png` | [ ] |
| A base64 blob decoded to an executable | `triage-decode.png` | [ ] |
| Dynamic analysis: procmon showing persistence | `triage-dynamic.png` | [ ] |
| FakeNet revealing the C2 domains | `triage-fakenet.png` | [ ] |
| The extracted indicators list | `triage-indicators.png` | [ ] |

---

## 08 - Threat Intelligence

| Capture | File | Done |
| --- | --- | :---: |
| Intelligence turned into a Sigma detection | `intel-to-rule.png` | [ ] |
| A retrospective hunt on a new indicator | `intel-retro-hunt.png` | [ ] |
| The indicator register with expiry dates | `indicator-register.png` | [ ] |

---

## 09 - Metrics and Maturity

| Capture | File | Done |
| --- | --- | :---: |
| The detection health dashboard | `metrics-dashboard.png` | [ ] |
| Detections-as-code percentage over time | `metrics-ascode.png` | [ ] |
| The one-page program summary | `metrics-summary.png` | [ ] |

---

## The Seven That Matter Most

For a Tier 2 portfolio, these tell the whole story.

```text
1. sigma-rule.png            you write detections as code
2. ci-passing.png            they are tested automatically
3. broken-rule-found.png     testing found a rule that never fired
4. hunt-beacon.png           you hunt, and you found something
5. emulation-results.png     you prove detections fire, honestly
6. navigator-coverage.png    you measure coverage, gaps and all
7. metrics-dashboard.png     you can show whether it is improving
```

Numbers 3 and 6 matter most. Finding a broken rule and showing honest coverage gaps both prove you verify rather than assume, which is the Tier 2 trait.

---

## Already Complete

Authored SVG, verified in light and dark themes.

| Diagram | Kind | Used in |
| --- | --- | --- |
| `detection-pipeline.svg` | Concept | README, 01 |
| `detection-cicd.svg` | Concept | 01, 02 |
| `sigma-anatomy.svg` | Concept | 02 |
| `hunt-loop.svg` | Concept | 03 |
| `purple-team-flow.svg` | Concept | 05 |
| `coverage-heatmap.svg` | Data | README, 06 |
| `attack-navigator-schematic.svg` | **Console schematic** | 06 |
| `malware-triage-flow.svg` | Concept | 07 |
| `pyramid-of-pain.svg` | Concept | 08 |
| `maturity-model.svg` | Concept | 09 |
| `metrics-dashboard-schematic.svg` | **Console schematic** | 09 |

Eleven diagrams, two of them console schematics. Your own screenshots are the real evidence, tracked above.
