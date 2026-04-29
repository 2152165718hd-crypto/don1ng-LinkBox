# Changelog

## v0.2.0 - 2026-04-29

- Added editable dashboard UI cards with display mode, size, color, unit, decimal precision, and icon settings.
- Added built-in IoT PNG icon assets for common sensors and actuators.
- Added custom PNG upload support for widget icons.
- Added dashboard schema version 2 with migration support for existing widget records.
- Improved dashboard generation so importing new thing-model properties fills missing cards without deleting existing layout choices.
- Removed the static graduate-template shortcut in favor of importing the actual OneNET Studio TSL JSON.
- Added dashboard configuration tests.

## v0.1.0 - 2026-04-29

- Initial Flutter Android MVP for OneNET Studio device dashboards.
- Added OneNET OpenAPI and application MQTT integration.
- Added project/group authorization storage with secure AccessKey handling.
- Added Token.log and TSL JSON import support.
- Added generated default monitoring and control panels.
