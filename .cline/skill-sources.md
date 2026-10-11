# SAMUDERA skill sources and setup verification

Setup date: 4 October 2026. Root: `C:/laragon/www/aquara_mobile` (pubspec package aquara_mobile). Scope: configuration only; no application dependency installation, production API calls, commit or push.

## Pinned upstream sources

| Selected skill | Repository URL | Exact commit | Source within repository | License |
| --- | --- | --- | --- | --- |
| flutter-build-responsive-layout | `https://github.com/flutter/agent-plugins` | `0ef3972f93e2baa4156ba1cbb1e515cd53079c68` | skills/flutter-build-responsive-layout | BSD-3-Clause, Copyright 2026 The Flutter Authors |
| flutter-add-widget-test | `https://github.com/flutter/agent-plugins` | `0ef3972f93e2baa4156ba1cbb1e515cd53079c68` | skills/flutter-add-widget-test | BSD-3-Clause, Copyright 2026 The Flutter Authors |
| ui-ux-pro-max | `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` | `477bcb28c9812b385cb51a4605dddf30d7b2266e2` | .claude/skills/ui-ux-pro-max | MIT, Copyright (c) 2024 Next Level Builder |
| samudera-api-security | Local SAMUDERA configuration | Not an upstream import | Written from user requirements, project documentation and inspected implementation | Project-local instructions |

Repositories were shallow-cloned with Git hooks disabled into `C:/Users/Fajar/AppData/Local/Temp/samudera-skills-7e4e794c4fce4943b0e04a428bc5b0f1`, outside the project. No upstream installer, shell script, package manager, hook, MCP or plugin setup was executed. Source checkout directories and the baseline snapshot are temporary audit material, not runtime dependencies.

## Copied resources and local adaptations

- Destinations are the four matching skill directories under `C:/laragon/www/aquara_mobile/.cline/skills/`. Upstream LICENSE is retained separately in each of the three imported skill directories.
- Flutter imports contained only SKILL.md. Removed model-specific metadata, retained substantive guidance/examples, added SAMUDERA scope/theme/security guidance. Widget-test setup reuses existing flutter_test and test doubles instead of adding dependencies; examples are explicitly illustrative, not application file references.
- UI UX Pro Max: copied SKILL.md, both references, complete data (CSV stacks and provenance/license JSON resources), and five top-level Python scripts. Kept all data files used by runtime domain/stack maps rather than breaking generic search modes. This is one skill, not the repository's entire collection or platform installers.
- Upstream tests/fixtures and repository tooling/templates/gallery were not copied: they are not runtime dependencies and some tests reference repository-level maintenance tools outside the selected skill. No claim is made that the full upstream test suite was run.
- Actual selected upstream subtree has regular files, not symlinks. Git tree inspection found a symlink only at gallery/data/styles.csv outside the selected subtree; it was not copied. No installed resource depends on that symlink.
- Replaced Claude plugin-root search paths with the absolute Cline skill path. Python commands use -B to avoid bytecode artifacts. Fixed relative paths in reference files; preserved data/attribution JSON unchanged.
- Added Flutter-only implementation policy, maritime blue/white Material 3 theme, existing Poppins/components/assets, compatibility checks against local SDK, and 320-logical-pixel testing. Generic web/GSAP/React recommendations do not authorize library installation or redesign.
- Removed application persistence instructions from the local skill workflow; no --persist/--force invocation was used. Runtime scripts remain upstream-identical, including optional persistence code, so agents must continue to obey the local scope restriction.
- Added local security skill and plain Markdown unconditional rule at `C:/laragon/www/aquara_mobile/.clinerules/samudera-security-and-plan.md`. No existing configuration was overwritten; target directories/files did not exist at initial inspection.

## Project alignment and unresolved context

Read the available root AGENTS.MD, PRD.md, ARCHITECTURE.md, workflow.md, and docs/API_DOCUMENTATION.md and docs/FLUTTER_UPGRADE_PLAN.md. Inspected ApiClient, SessionService, SecureTokenStore, AuthService, auth form/navigation, main theme and available tests. Paths in the local security skill point to existing files.

- Actual transport is package http with interception inside ApiClient (not a separate Dio interceptor). ApiService retains legacy feature methods; AuthService uses ApiClient. Token lifecycle is centralized in SessionService and flutter_secure_storage-backed SecureTokenStore.
- Existing navigation is Navigator/MaterialPageRoute, with pushAndRemoveUntil in auth/logout flows. A complete global private-route guard was not established by this setup; do not claim all direct/back navigation paths are already protected. SessionService exposes changes for integration.
- User states Tahap 2 is complete. The upgrade plan still says pre-implementation and has unchecked stages. Use actual implementation/user status, preserve sequence and validate gates rather than rebuilding Tahap 2. No source documentation was edited.
- workflow.md contains backend-oriented permissions and a TODO update requirement. AGENTS.MD forbids PHP/Composer/Artisan in this Flutter repository, and setup scope forbids source-document changes; those workflow actions were not performed.
- Deployment origin remains a clarification for integration work: API docs use an illustrative domain, while AuthService uses SAMUDERA_API_URL with a legacy default. No deployment URL was tested or asserted as current.
- SessionService still persists some profile metadata in shared_preferences; the skill explicitly treats this as a minimization/migration concern, not permission to add plaintext private storage. No application remediation was performed.
- Upstream Flutter dataset labels target Flutter 3.44.x; these labels are not evidence of the installed SDK or permission to upgrade. Review example code and local API compatibility before applying search results.

## Verification performed

- Python executable: `C:/laragon/bin/python/python-3.10/python.exe`, Python 3.10.6. No pip/global install required.
- Reviewed search entrypoint, imports, CSV-loading paths, reasoning grammar and persistence branch before execution; selected stack/domain search reads local CSV and prints results. No network/subprocess dependency in the executed search path. All five Python scripts passed AST syntax parsing; syntax parsing alone is not an execution/security audit of every optional branch.
- All four SKILL.md files passed validation of delimited YAML mapping frontmatter, matching name and nonempty description. Local frontmatter uses only simple name/description scalars, without conditional paths/model metadata.
- Verified actual absolute project references, UI relative references and every CSV file in CSV_CONFIG/STACK_CONFIG, plus ui-reasoning.csv. No stale CLAUDE_PLUGIN_ROOT or .claude/skills invocation remains in installed guidance. Illustrative upstream Dart snippets are examples, not required project files.
- Executed `python -B C:/laragon/www/aquara_mobile/.cline/skills/ui-ux-pro-max/scripts/search.py "responsive layout" --stack flutter --json`: exit 0, 3 Flutter layout results.
- Executed `python -B C:/laragon/www/aquara_mobile/.cline/skills/ui-ux-pro-max/scripts/search.py "keyboard focus" --domain ux --json`: exit 0, 3 UX results. Web-specific result examples require Flutter translation; not blindly applied.
- Queries contain generic terms only. Results went to terminal, not application files. No persistence or production traffic.
- Baseline SHA-256 verification: 210 existing tracked/untracked non-configuration files unchanged. Existing user changes were present before setup and retained. Flutter analyzer/test were not run for this configuration-only change, avoiding generated application/build artifacts outside scope; no claim of application test/UAT success.
- Global directories checked read-only: `C:/Users/Fajar/.cline/skills` and `C:/Users/Fajar/Documents/Cline/Skills` did not exist. No same-name conflict found there; other remote/profile environments cannot be inferred. No global configuration was changed.

## Activation: pending UI verification

Official Cline guidance consulted: `https://github.com/cline/cline/blob/main/docs/customization/skills.mdx`.

1. Open workspace `C:/laragon/www/aquara_mobile` in Cline. UI labels/feature availability can differ by installed version; if Skills is absent, report that limitation rather than installing or changing global software automatically.
2. Open the scale/rules icon near the model selector, then Skills. Confirm all four names appear as workspace skills and enable their toggles.
3. Inspect source paths for same-name global skills: Cline documents global precedence. If another profile supplies a conflict, report it rather than editing global configuration automatically.
4. In Rules, confirm the local samudera-security-and-plan rule is enabled. It is unconditional plain Markdown; skills themselves load on demand, not all on every task.
5. Start a task relevant to the security skill and verify that Cline loads the intended workspace SKILL.md. File installation alone does not verify discovery, toggle state, or activation.

No Python prerequisite is outstanding. Cline UI discovery/activation and any profile-specific conflicts remain user-verifiable; this agent did not manipulate UI state or claim the skills are active.