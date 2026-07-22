# Scopos Mail — Fork Maintenance

This repo is a **rebrand fork** of [mailwish/mailbux-flutter](https://github.com/mailwish/mailbux-flutter)
(itself a fork of Linagora TMail). It is a webmail **client only**; the mail
server is Mailbux (`my.mailbux.com`). AGPL-3.0.

**Deployed:** Cloudflare Pages project `scopos-mail` → `https://scopos.pro`.
**Golden baseline:** tag `golden-visuals-2026-07-22`.
**Remotes:** `origin` = donateko/scopos-webmail (ours, public), `upstream` = mailwish/mailbux-flutter.

---

## Toolchain (non-obvious, required)

- **Flutter 3.27.4**, pinned via `.fvmrc`. The repo does **not** build on newer
  Flutter (dart:ffi/platformView breakages). Use `fvm flutter ...`.
- Before the first build you MUST run codegen: `bash scripts/prebuild.sh`
  (generates l10n + Hive `.g.dart` across 9 sub-modules; not committed upstream).
- Build: `fvm flutter build web --release` → `build/web/`.

## Deploy

```
fvm flutter build web --release
wrangler pages deploy build/web --project-name scopos-mail --branch brand/scopos-mail --commit-dirty=true
```
CF creds: `set -a; source /Volumes/NVMe/CITADEL/keys/.cloudflare.env; set +a`
(map to `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`). Apex `scopos.pro` is a
proxied web CNAME to `scopos-mail.pages.dev`; the domain's **MX/SPF/DKIM/DMARC
must never be touched** — scopos.pro is the consultants' live email domain.

---

## Updating from upstream — the ritual

Do this **only** for a security fix or a feature you actually want, not on a schedule.

1. `git fetch upstream`
2. `git merge upstream/master` (or rebase) onto `brand/scopos-mail`.
3. Resolve conflicts — they will land in the LOAD-BEARING files below. Re-apply
   our intent, don't just accept theirs.
4. `bash scripts/prebuild.sh` then `fvm flutter build web --release`.
5. Eyeball login + inbox against the golden tag; then deploy.

`git diff upstream/master...brand/scopos-mail` is the full ground truth of our divergence.

---

## LOAD-BEARING changes (re-verify these after any upstream merge)

These are edits to **shared vendor code** where an upstream change can conflict
or silently revert our intent. Check each after merging.

| Concern | File(s) | What we did |
|---|---|---|
| **OIDC bypass** (in-app login instead of the vendor hosted page) | `lib/features/home/presentation/extensions/handle_web_finger_to_get_token_extension.dart` (`checkOIDCIsAvailable` short-circuit), `lib/features/login/presentation/login_controller.dart` (`_checkOIDCIsAvailable` guard), `lib/main/utils/app_config.dart` (`disableOidc`), `env.file` (`DISABLE_OIDC=true`) | If login starts redirecting to `auth.mailbux.com` again, these regressed. |
| **Palette / dark chrome** | `core/lib/presentation/extensions/color_extension.dart` | primaryColor→red `#AC0014`, surfaces→dark, `colorNameEmail`, `steelGray*`, `colorBgDesktop`=`#F1F1F1` viewport, avatar `mapGradientColor` (DO NOT change avatars). |
| **Global theme** | `core/lib/presentation/utils/theme_utils.dart` | scaffold `#0D0D0D`, square checkbox/dialog/card/menu themes. |
| **Body font** | `core/lib/presentation/constants/constants_ui.dart` | `fontApp = 'Barlow'`. |
| **Square corners** | ~130 files: `Radius.circular(N)`, `static const ... radius = N`, and inline `radius: N` / `borderRadius: N` all zeroed (except ≥100 = true circles). | Upstream adds rounded widgets over time; re-run the zeroing sweep if new rounded corners appear. |
| **Left column vs viewport swap** | `lib/features/mailbox_dashboard/presentation/mailbox_dashboard_view_web.dart` | left column dark `#141414`, message viewport `colorBgDesktop`, toolbar header `#E4E4E4`. |
| **Sidebar text/icons** | `folders_bar_widget.dart`, `mailbox_category_widget.dart`, `label_mailbox_item_widget.dart`, `mailbox_item_widget.dart`, `count_of_emails_widget.dart`, `mailbox_expand_button.dart` | muted-ivory labels/icons, dark-on-white when selected. |
| **Manage-account chrome** | `manage_account_menu_view.dart`, `menu/widgets/account_menu_item_tile_builder.dart` | dark menu, white selected row, themed icons. |
| **Send / Compose CTAs** | `styles/web/bottom_bar_composer_widget_style.dart` (Send bg red), `bottom_bar_composer_widget.dart` (Send icon white), `compose_button_widget.dart` (red) | |
| **Source-code offer (AGPL §13)** | `privacy_link_widget.dart` + `app_config.dart` `sourceCodeUrl` | The in-app "Source code" link. Must stay pointing at this repo. |

## LOW-RISK changes (asset swaps — upstream rarely touches these)

- **Logos/marks:** `assets/images/ic_logo_with_text*.svg`, `ic_tmail_logo.svg`,
  `ic_logo_twake_welcome.svg`, `power_by_linagora.svg`, `lg_mailbux.png`,
  `scopos_logo_lockup.svg`, `scopos_mark_light.svg`, `scopos_wordmark_light.png`.
- **Icon set (23):** `ic_mailbox_*`, `ic_compose*`, `ic_send`, `ic_search_bar`,
  `ic_refresh`, `ic_filter`, `ic_star`, `ic_unstar`, `ic_attachment`, `ic_reply*`,
  `ic_forward`, `ic_delete`, `ic_read`, `ic_unread`, `ic_add_new_folder`,
  `ic_folder_mailbox`, `ic_checkbox_*`, `ic_select_all`, `ic_empty_folder`.
  Mono graphite `#55534E`; recolored by the app's colorFilter where applied.
- **Web shell:** `web/index.html`, `web/manifest.json`, `web/splash/*`, favicon/icons.
- **Fonts:** `assets/fonts/{Barlow,BarlowCondensed,SpaceMono}` + `pubspec.yaml` registration.

## Config

- `env.file` → `SERVER_URL=https://my.mailbux.com`, `DISABLE_OIDC=true`,
  `APP_GRID_AVAILABLE=unsupported`. No secrets in this repo (public OIDC client
  IDs only). Login uses plain JMAP basic auth against `SERVER_URL`.
