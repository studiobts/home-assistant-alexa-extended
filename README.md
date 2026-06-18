# Amazon Alexa - Extended

[![hacs_badge](https://img.shields.io/badge/HACS-Custom-orange.svg)](https://github.com/hacs/integration)

If you want to make donation as appreciation of my work, you can do so via buy me a coffee. Thank you!

<a href="https://buymeacoffee.com/studiobts" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png"></a>

## Introduction

This is an extended version of the core Alexa integration. It adds a configurable `blocker` option: when the template evaluates to `true`, the integration will block execution of incoming Alexa commands that would change device state. 

Requests that update state (state report) and authorization requests are still allowed when the template evaluates to `true`.

## Key behavior

- `blocker` is evaluated using Home Assistant templating (Jinja2 style).
- When the template evaluates to `true`:
  - Commands that request changes (turn on/off, set temperature, etc.) are blocked and not forwarded to your devices/services.
  - Alexa state update requests (reports) and authorization requests continue to be processed.
- When the template evaluates to `false`, the integration behaves like the standard Alexa integration.

## When to use

Use this feature when you need a global or conditional "safety switch" to prevent Alexa from making state changes — for example:
- Night mode, maintenance windows, child-safe mode, not at home
- External conditions (power saving, emergency mode)
- Integration-level temporary lockouts

## Installation

1. Add the repository to HACS

- In Home Assistant open HACS.
- Click the overflow menu (three dots) in the top right and choose Custom repositories.
- Add a new repository with: 
  - Repository: studiobts/home-assistant-alexa-extended
  - Category: Integration
- Go to HACS and search for Amazon Alexa - Extended. Click Install to install the integration.
- After installation, restart Home Assistant

2. Manual installation

- Download or clone this repository.
- Copy the `alexa` folder into your Home Assistant `custom_components` directory.
- Restart Home Assistant.

## Configuration

The integration accepts a `blocker` parameter. The template can reference `states`, `state_attr`, `now()`, helpers, and other standard Home Assistant template features.

Example configuration (in `configuration.yaml` or integration options depending on your setup):

```yaml
alexa:
  # Block when the input_boolean is on
  blocker: "{{ is_state('input_boolean.alexa_block', 'on') }}"
```

Notes:
- Templates must evaluate to a boolean (`true`/`false`).

## Behavior details

- Allowed requests while blocked:
  - Alexa authorization (account linking / auth) requests
  - Alexa state update/report requests
- Blocked requests while blocked:
  - Any directive that intends to change device state (e.g., `TurnOn`, `SetTemperature`, `ActivateScene`)
- The integration will not execute the underlying service calls while blocked. It will respond according to the Alexa skill expectations but will not perform state-changing operations.

## Examples

Block using an `input_boolean` (recommended for UI control):

1. Create an `input_boolean` helper in Home Assistant:
2. Use it in the integration config:
```yaml
alexa_extended:
  blocker: "{{ states('input_boolean.alexa_commands_block') == 'on' }}"
```

Flip the `input_boolean` in the UI to toggle blocking.

## Testing

- Use the Home Assistant developer tools to evaluate your template and confirm it returns the expected boolean value.
- Test typical Alexa directives and confirm state-update and authorization requests still pass while change-directives are blocked.

## Troubleshooting

- If the template never evaluates as expected, validate it in Developer Tools → Templates.
- Ensure the template returns a boolean. Use `| bool` or explicit comparisons to avoid string truthiness issues.
- Check Home Assistant logs for any template rendering errors or integration errors.

## Limitations

- This component adds conditional blocking at the integration level. It is not a replacement for fine-grained access control per entity.
- Depending on Alexa skill expectations, blocked directives may return error responses or be silently ignored; test your Alexa setup to confirm desired behavior.

## Release and core compatibility

Every released version of this extended integration is built against a specific version of the original core Alexa integration. When changes are introduced in the core integration, those changes will be integrated into this extension; a new extension release will be published to reflect the update.

Versioning semantics:
- Extension release tags include a reference to the Home Assistant core version used for that release
- Example: `v1.0.0-ha2025.11.2` — extension version `1.0.0` built against Home Assistant core `2025.11.2`
- The suffix format is `-ha<core-version>` to make compatibility explicit

Check release notes or the tag for each release to see the exact referenced core version and any integration changes.

## Updating to a new Home Assistant core version

This repository keeps the upstream code and the custom modifications on separate
branches, which makes updates predictable:

- `original` — a verbatim copy of the core `alexa` component, with no custom changes.
- `main` — the `original` code plus the `blocker` feature.

The modifications introduced by this extension are intentionally small and isolated
so syncing with a new core release is usually conflict-free.

### 1. Update the `original` branch with the new core code

Use the helper script `sync-original.sh` passing the target core version as argument:

```bash
./sync-original.sh 2026.6.3
```

The script checks out `original`, downloads only the `alexa` component from the given
core tag (a sparse, blobless clone — it does not download the whole core repository),
replaces `custom_components/alexa` with the pristine code, commits with the message
`Updated code to <version>`, and returns to the branch you started from.

Then publish the branch:

```bash
git push origin original
```

### 2. Merge `original` into `main`

Bring the updated core code into `main`, preserving the `blocker` feature:

```bash
git checkout main
git pull --ff-only
git merge original
```

Because the custom changes do not overlap with the upstream changes, the merge
normally completes automatically. If a conflict ever appears, it will be limited to
the files changed; resolve it by keeping both the upstream change and the `blocker` logic.

### 3. Update metadata and tag the release

Before publishing, update the version metadata to match the new core version:

- `manifest.json` — bump the `version` field.
- `hacs.json` — bump `version` and, if needed, the minimum `homeassistant` version.

Then commit, push, and create a release tag following the
`v<ext-version>-ha<core-version>` convention described in
[Release and core compatibility](#release-and-core-compatibility):

```bash
git push origin main
git tag v1.0.5-ha2026.6.3
git push origin v1.0.5-ha2026.6.3
```