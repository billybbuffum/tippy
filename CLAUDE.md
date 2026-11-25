# Tippy

A personal, open-source, non-commercial alcohol-moderation app with a virtual pet. It is local-first:
the core experience runs on the device.

- Research and product plan: `docs/research-and-plan.md`
- Server architecture: `docs/server-architecture.md`

## Rules

- **All server-side code must follow a strict hexagonal (ports and adapters) and DDD structure**, exactly as
  described in `docs/server-architecture.md`: bounded contexts, the domain → application → adapters layering
  with dependencies pointing inward only, a single composition root, no cross-context imports, and the
  ubiquitous-language table kept up to date. Don't take shortcuts (no business logic in routes or repositories,
  no framework imports in the domain), even for small features.
- The server must never receive drink entries, notes or pet state.
- Don't reuse Tipple's name, art, screenshots or copy; use original or CC0 assets.
