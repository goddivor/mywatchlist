# Handoff — `mal-hub-followups`: MAL hub follow-ups: in-app thread on message tap, JSON posts through postJson, message poller next to the hub poller

**Kind** unit · **Priority** P1 · **Group** user · **Model** opus

## Needs done first
- `mal-hub-wiring` (MAL notifications: bell, sidebar entry, background polling when the app is closed, settings switches)

## Owns (may create or edit ONLY these)
- `lib/utils/app_routes.dart`
- `lib/services/notifications/notification_service.dart`
- `lib/services/notifications/mal_hub_poller.dart`
- `lib/services/api/MAL/web/mal_notifications_api.dart`
- `lib/main.dart`
- `lib/l10n/units/mal-hub-followups/**`
- `test/units/mal-hub-followups/**`
- `test/units/mal-hub-followups/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Findings from mal-hub-wiring (PR #273): (1) a tapped new-message notification must open the in-app thread screen (mal-messages), not mymessages.php in the browser: route mymessages.php?go=read&id= (and the inbox) in AppRoutes / openMalHubPayload; (2) move the JSON POSTs of mal_notifications_api.dart onto MalWebClient.postJson; (3) move MalHubMessagesPoller and the message watcher out of main.dart into mal_hub_poller.dart (or a sibling file), main.dart keeping only the registration.
- Fakes only in tests: never send anything to MAL.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Tests: the message payload routes to the thread screen; notification POSTs go through postJson; behaviour of the poller unchanged.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
