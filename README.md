# Ticketing Platform API

A JSON API built with Rails 7 and PostgreSQL that powers the core purchasing flow
for a local event ticketing platform (Eventbrite-like backend).

---

## Table of Contents

- [Setup](#setup)
- [Problem Description](#problem-description)
- [Architectural Decisions](#architectural-decisions)
- [How the Price Snapshot Works](#how-the-price-snapshot-works)
- [How the Concurrency Problem is Tackled](#how-the-concurrency-problem-is-tackled)
- [Trade-offs of the Current Implementation](#trade-offs-of-the-current-implementation)

---

## Setup

### Requirements

- Ruby 3.1.0
- PostgreSQL 16
- Bundler

### Installation

```bash
git clone git@github.com:RobbySa/eventbright-copy.git
cd eventbright-copy
bundle install
rails db:create db:migrate db:seed
rails server
```

### Running Automatic Tests

```bash
bundle exec rspec
```

### Seeded Data

The seed file creates:
- 3 published events
- 2–3 ticket types per event (GA, VIP, Early Bird) with varying prices and quantities
- A handful of confirmed orders

You can immediately hit the API after seeding:

```bash
# Browse events
curl http://localhost:3000/events

# List ticket types for event 1
curl http://localhost:3000/events/1

# Place an order
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","items":[{"ticket_type_id":1,"quantity":2}]}'

# Look up your order
curl http://localhost:3000/orders/1

# List all orders for an email
curl "http://localhost:3000/orders?email=you@example.com"
```

---

## Problem Description

We're building the backend for a small event ticketing platform. The core
requirement is a purchasing flow where:

- Customers can browse upcoming events and their ticket options
- Each event has multiple ticket types (e.g. General Admission, VIP), each with
  its own price and availability
- Customers can place an order for one or more ticket types in a single checkout
- Orders can be retrieved later by customer email

Two specific failure modes from previous projects were called out as must-fix:

1. **Overselling** — Two customers simultaneously buying the "last ticket" and
   both succeeding, resulting in more tickets sold than physically available.

2. **Mid-sale repricing** — A promoter changing ticket prices while a customer
   is mid-checkout, causing the customer to be charged the new price rather than
   the one they saw when they added tickets to their cart.

Authentication and payments are explicitly out of scope for this iteration.
As well are the logic for creating a new events and ticket_types

---

## Architectural Decisions

### Service Object for Order Placement

The purchasing logic lives in a single service object: `Orders::Place`. Rather than
putting this logic in the controller or model, a dedicated service object was
chosen because:

- The operation spans multiple models (`Order`, `OrderItem`, `TicketType`), no single model owns it naturally
- It has clear inputs (email + items) and a clear output (a `Result` hash
  with `success?`, `order`, and `error` keys) making it easy to test in isolation
- The controller stays thin and focused only on HTTP concerns

### Separate `orders` and `order_items` Tables

An order is modelled as a header + line items rather than a flat structure:

- `orders` holds who bought, when, the overall status, and total
- `order_items` holds each individual ticket line — which ticket type, how many,
  and the price at the time of purchase

This separation is necessary because a single checkout can contain multiple
ticket types (e.g. 2× GA + 1× VIP). A flat structure would force duplicating
order-level fields across every row, artificially limiting checkouts to a
single ticket type, or would require to employ a json column with all the ticket details.

### Monetary Values as Integer Cents

All prices and totals are stored as integers in cents (`price_cents`,
`total_cents`, `unit_price_cents_snapshot`) rather than floats. Floating point
arithmetic is not safe for money due to rounding errors when saved to DB.
A `currency` column sits alongside every money field.

### PostgreSQL Check Constraints as a Safety Net

In addition to ActiveRecord validations, the database enforces:

- `sold_quantity <= total_quantity` on `ticket_types`
- Valid status values on `orders` and `events`

These constraints mean that even if something bypasses the model layer (a
migration, a console operation, a future code path), the database will reject
corrupt data rather than silently allow it.

---

## How the Price Snapshot Works

When a customer places an order, the price they are charged is the price that
existed at the moment their `OrderItem` was created — not the live price on the
`TicketType` at any later point.

At the instant the order item is built inside the database transaction,
`ticket_type.price_cents` is read and copied into `unit_price_cents_snapshot`.
From that point on:

- The `OrderItem` record carries its own copy of the price it was created at
- If a promoter updates `ticket_types.price_cents` tomorrow, every existing
  `order_items.unit_price_cents_snapshot` is unaffected
- The order total is calculated from these snapshots, not from live prices

This means the database will reject any `order_items` row where the line total
is inconsistent with the snapshot — regardless of what the live price on
`ticket_types` says.

**What breaks if you remove it:** Without the snapshot, re-rendering an order or
recalculating a total would use the current live price. Any price change after
purchase would silently alter the customer's order history. Customers could be
shown a different price than what they were charged, or worse, charged a
different amount than what they saw at checkout.

---

## How the Concurrency Problem is Tackled

### The Problem

Without any protection, the following race condition is possible:

1. Buyer A reads `sold_quantity = 9`, `total_quantity = 10` → 1 ticket left
2. Buyer B reads `sold_quantity = 9`, `total_quantity = 10` → 1 ticket left
3. Both pass the availability check
4. Both create their `OrderItem` and increment `sold_quantity`
5. `sold_quantity` becomes `11` on a `total_quantity = 10` ticket

### The Solution: `SELECT ... FOR UPDATE`

Inside the transaction in `Orders::Place`, before any availability check is performed,
we acquire a **pessimistic row-level lock** on every `TicketType` row involved
in the order:

```ruby
TicketType.where(id: ids).order(:id).lock("FOR UPDATE")
```

This instructs PostgreSQL to lock those rows for the duration of the current
transaction. Any other transaction that tries to lock the same rows will
**block** (wait) until the first transaction either commits or rolls back.

The sequence now becomes:

1. Buyer A's transaction acquires the lock on the `ticket_types` row
2. Buyer B's transaction tries to acquire the same lock → **blocks**
3. Buyer A checks availability (1 left), passes, creates the order, increments
   `sold_quantity` to 10, commits
4. Buyer B's transaction unblocks, re-reads the row (now `sold_quantity = 10`),
   checks availability → 0 left → fails with `InsufficientInventoryError`
5. Only Buyer A gets the ticket

Critically, the availability check happens **after** acquiring the lock, not
before. Checking before locking would recreate the race condition.

### Deadlock Prevention

When an order contains multiple ticket types, we always lock them in
**ascending ID order**:

```ruby
TicketType.where(id: ids).order(:id).lock("FOR UPDATE")
```

Without this, Transaction A locking types [1, 2] and Transaction B locking
types [2, 1] could deadlock. Consistent ordering eliminates this possibility.

### The Database as a Final Backstop

Even if the application-level lock were somehow bypassed, the PostgreSQL check
constraint `sold_quantity <= total_quantity` would reject the violating `UPDATE`
with a hard database error, rolling back the transaction. No ticket would be
silently oversold.

**What breaks if you remove the lock:** Without `FOR UPDATE`, concurrent
requests race through the availability check simultaneously. Under load, multiple
buyers can each see sufficient inventory, all pass, and all succeed — resulting
in `sold_quantity` exceeding `total_quantity`. The DB constraint would then cause
a hard error on the second concurrent `UPDATE`, giving the customer an opaque
failure rather than a clean "sold out" message. The lock prevents the race from
ever occurring.

---

## Trade-offs of the Current Implementation

### Pessimistic Locking vs. Optimistic Locking

**Current approach (pessimistic):** Lock the row at the start, block concurrent
writers for the duration.

- ✅ Simple to reason about — no retry logic needed
- ✅ Guarantees the first buyer gets the ticket without retries
- ⚠️ Transactions hold locks longer under slow queries or high load

**Alternative (optimistic):** Add a `lock_version` column, attempt the update
without locking, and retry if a version conflict is detected.

- ✅ Better throughput when conflicts are rare
- ⚠️ Requires retry logic in the application layer

For a local ticketing platform with moderate concurrent load, pessimistic locking
is the right call — it's simpler, correct, and the contention scenario only
materialises at a scale this platform is unlikely to face in its first iteration.

### No Idempotency Key Enforcement on Create

The `orders` table has no `idempotency_key` column.
A retry on a failed network request could create duplicate orders.
Enforcing a client-supplied idempotency key on `POST /orders` would be a recommended
next step before going to production.

### sold_quantity as a Denormalised Counter

`ticket_types.sold_quantity` is a denormalised count that must stay in sync with
the actual number of confirmed `order_items`. It's incremented inside the same
transaction as the order creation, so it's consistent under normal operation.
However, if orders are ever cancelled and refunded, a corresponding decrement
must be applied as there is currently no automatic trigger keeping it in sync.
