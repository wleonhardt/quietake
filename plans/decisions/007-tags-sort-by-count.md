# 007 Sort tags by capture count

Status: accepted.

## Decision

The Tags screen has a sort button that switches between name order (default) and
most captures first. Ties keep name order. The choice lasts for the open screen.

## Reasons and limits

- It reuses the per-tag counts the screen already computes from the catalog, so it
  reads no new data and adds no storage.
- The choice is not saved. The picker and the merge sheet keep name order.
- Cover choice and a Moments view stay separate ideas.
