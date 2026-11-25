# Server architecture: hexagonal + DDD (strict)

Every server-side part of Tippy follows **Domain-Driven Design** with a strict
**hexagonal (ports and adapters)** structure. This is a project rule, not a suggestion.

## 1. Where the server fits

The app is local-first. The core domain (drink logging, weekly goals, the pet's mood, coins, the shop)
runs **on the device** and needs no server. A server exists only for things a phone-installed web app can't do alone:

| Bounded context | Subdomain type | Why it needs a server | Phase |
|---|---|---|---|
| **Reminders** | Supporting | iOS web apps can't schedule their own notifications; reminders must come from a Web Push sender | When reminders are wanted |
| **Backup** | Generic | Optional end-to-end-encrypted backup, so clearing browser data doesn't wipe history | Later, optional |

Privacy rule: the server **never** receives drink data, notes or pet state. Reminders store only a push
subscription, a reminder time, a time zone, and the date of the last check-in. Backup stores only ciphertext
it can't read.

## 2. Ubiquitous language

Use these exact terms in code, tests, UI copy and docs. If a term changes, update this table first.

| Term | Meaning |
|---|---|
| **Drink entry** | One logged drink: volume, ABV, derived standard drinks |
| **Standard drink** | 14 g pure alcohol (US). A *UK unit* is 8 g |
| **Check-in** | Logging a day, either with drink entries or as a *drink-free day* |
| **Drink-free day** | A check-in with zero standard drinks |
| **Weekly goal** | Maximum standard drinks per week |
| **Week** | Seven days starting on the user's *week start day* |
| **Pace** | Standard drinks so far ÷ pro-rated weekly goal |
| **Mood** | The pet's state derived from pace and check-ins (thriving, happy, okay, concerned, waiting) |
| **Coins** | Reward currency earned for check-ins and goals |
| **Device** | One installed copy of the app (pseudonymous id, no account) |
| **Reminder schedule** | When a device wants its daily check-in nudge (local time + time zone) |
| **Reminder** | A single push notification sent for a given local date |
| **Backup snapshot** | One encrypted export blob for a device |

## 3. Layers and the dependency rule

```
          adapters/in  ──►  application (ports/in → use cases)  ──►  domain
                                    │
                                    ▼
                           application/ports/out  ◄──  adapters/out
```

Dependencies point **inward only**:

- **domain/**: entities, aggregates, value objects, domain events, domain services and
  repository *interfaces*. Pure TypeScript with **no imports** from frameworks, libraries, I/O, `Date.now()`
  or other contexts (time comes in through a `Clock` port or as a parameter).
- **application/**: use cases (one per command or query), *inbound ports* (use case interfaces and
  command/query DTOs) and *outbound ports* (interfaces such as `PushNotifier`, `Clock`, `IdGenerator`,
  `UnitOfWork`). It orchestrates the domain and owns transactions. It imports only `domain/` and
  `shared-kernel/`.
- **adapters/in/**: driving adapters (HTTP routes, scheduler ticks, CLI). These translate input into commands,
  call inbound ports, and map results and errors to responses. No business rules.
- **adapters/out/**: driven adapters that implement outbound ports and repository interfaces (SQL, web-push,
  system clock). No business rules.
- **bootstrap/**: the single **composition root**. It reads config, builds adapters and wires them into use
  cases. It is the only place that knows about every concrete class.

### Hard rules

1. The domain never imports from `application`, `adapters`, `bootstrap` or any npm package.
2. Use cases depend on port interfaces, never on adapters.
3. Adapters never call each other or the domain directly. They go through ports.
4. **Aggregates are the consistency boundary.** One aggregate per transaction; reference other aggregates by id only.
5. Invariants are enforced inside aggregates and value objects (constructors validate, so invalid
   states can't be represented). No anemic models or setters; changes go through behaviour methods
   that emit domain events.
6. **Bounded contexts don't import each other.** They communicate only through published integration events or
   an explicit anti-corruption layer. Only `shared-kernel/` (tiny and stable: `Result`, `DomainEvent`
   base, `Clock` port, branded ids) is shared.
7. Persistence and transport models are separate from domain models; adapters map between them.
8. Errors: domain errors are typed values (`Result<T, DomainError>`), not HTTP codes. Inbound adapters map them.
9. These rules are **enforced in CI** with `dependency-cruiser` (or `eslint-plugin-boundaries`); a violation
   fails the build.

## 4. Folder structure

```
server/
  src/
    shared-kernel/
      result.ts
      domain-event.ts
      clock.ts                      # port
      ids.ts                        # branded id types
    reminders/                      # ── bounded context ──
      domain/
        reminder-schedule.ts        # aggregate root
        push-endpoint.ts            # value object (endpoint + keys)
        local-time.ts               # value object (HH:MM)
        time-zone.ts                # value object (IANA)
        device-id.ts                # value object
        events.ts                   # ReminderScheduled, ReminderDue, ReminderSent, CheckInAcknowledged
        reminder-schedule-repository.ts   # repository interface
        due-reminder-policy.ts      # domain service: is a schedule due at instant X?
      application/
        ports/
          in/
            register-device.ts      # command + use case interface
            change-reminder-time.ts
            acknowledge-check-in.ts
            dispatch-due-reminders.ts
            unregister-device.ts
          out/
            push-notifier.ts
            unit-of-work.ts
        use-cases/
          register-device.service.ts
          change-reminder-time.service.ts
          acknowledge-check-in.service.ts
          dispatch-due-reminders.service.ts
          unregister-device.service.ts
      adapters/
        in/
          http/reminders.routes.ts  # POST /devices, PUT /devices/:id/reminder, POST /devices/:id/check-ins …
          scheduler/minute-tick.ts  # calls DispatchDueReminders every minute
        out/
          persistence/sql-reminder-schedule.repository.ts
          persistence/schema.sql
          push/web-push.notifier.ts # VAPID, maps 404/410 → subscription expired
          clock/system-clock.ts
    backup/                         # ── bounded context (later) ──
      domain/ application/ adapters/   # same shape
    bootstrap/
      config.ts
      container.ts                  # composition root
      main.ts
  test/
    reminders/
      domain/…                      # pure unit tests, no fakes needed
      application/…                 # use cases with in-memory fakes of every port
      adapters/…                    # integration tests (real SQLite, mocked push endpoint)
      contracts/…                   # one shared test suite every repository implementation must pass
  .dependency-cruiser.cjs
```

## 5. Reminders context (first server feature)

**Aggregate `ReminderSchedule`** (id = `DeviceId`)
- State: `pushEndpoint`, `localTime`, `timeZone`, `enabled`, `lastCheckInDate?`, `lastReminderDate?`
- Behaviour:
  - `changeTime(localTime, timeZone)` → `ReminderRescheduled`
  - `acknowledgeCheckIn(localDate)` → `CheckInAcknowledged` (that day's reminder is then skipped)
  - `markSent(localDate)` → `ReminderSent`. Invariant: **at most one reminder per local date**
  - `expireEndpoint()` when the push service reports the subscription is gone → `enabled = false`
- `DueReminderPolicy.isDue(schedule, instant)`: true when local time ≥ reminder time, not yet sent today,
  and not checked in today. It handles DST and time-zone changes.

**Use case `DispatchDueReminders`** (driven by the minute tick)
1. Load candidate schedules via the repository.
2. For each schedule the policy says is due: `PushNotifier.send(...)`, then `markSent`, and save in its own unit of work.
3. A notifier result of "gone" calls `expireEndpoint()`.

The client calls `AcknowledgeCheckIn` after each check-in, sending only the date.

## 6. Technology (adapters only, so it can be swapped)

- TypeScript (same language as the web app), Node 22 LTS.
- HTTP adapter: Hono (also runs on Cloudflare Workers).
- Persistence adapter: SQLite (local) / Cloudflare D1 (hosted). Both implement the same repository port and pass the same contract tests.
- Push adapter: `web-push` (VAPID keys from env/secrets, never committed).
- Scheduler adapter: a node-cron tick locally, Cloudflare Cron Trigger when hosted.
- Hosting: GitHub Pages can't run a server. The cheapest fits are Cloudflare Workers (free tier) or a home server.
  Because of the hexagonal structure, this choice touches only `adapters/` and `bootstrap/`.

## 7. Definition of done for any server change

- [ ] New concepts are added to the ubiquitous-language table.
- [ ] Business rules live in the domain, with unit tests.
- [ ] Each use case has tests that use in-memory fakes for every outbound port.
- [ ] Each new adapter has integration tests, and repository adapters pass the shared contract suite.
- [ ] `dependency-cruiser` passes (no inward-rule or cross-context violations).
- [ ] No drink data, notes or other personal data reaches the server.
