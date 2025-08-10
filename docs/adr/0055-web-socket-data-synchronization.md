# 55. Web socket data synchronization

Date: 2024-11-10

## Status

Accepted

## Context

- Currently Mailbux web use Firebase Cloud Messaging to sync data on real time
- JMAP already implemented web socket push, which is more optimized for web

## Decision

- Web socket is implemented for real time update data for Mailbux web

## Consequences

- Mailbux web now no longer depends on Firebase Cloud Messaging, using web socket to update users' latest data
