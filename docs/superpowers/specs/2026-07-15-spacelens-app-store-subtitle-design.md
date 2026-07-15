# SpaceLens App Store Subtitle Design

## Goal

Use the following English App Store subtitle for SpaceLens version 1.0 (build 1):

> Smarter storage. Safer cleanup

## Rationale

The two-part line communicates SpaceLens's core value clearly: it helps people understand storage intelligently and keeps cleanup deliberate. It aligns with Smart Scan and the app's review-first deletion flow without claiming that cleanup is automatic, risk-free, or guaranteed.

## Constraints

- The subtitle is exactly 30 characters, including spaces and punctuation, which meets Apple's 30-character limit.
- This approval applies only to the primary English localization.
- The subtitle makes no privacy, legal, accessibility, age-rating, pricing, or performance claim.
- This is a metadata copy decision only; it does not authorize a binary change or any App Store Connect action.

## Application

After the user approves this written specification, replace only the draft subtitle in the local App Store metadata source and the corresponding release documentation. Do not change the archive or exported installer package, because the approved subtitle is not embedded in the app binary.

## Verification

- Recount the final subtitle from the actual metadata source and confirm 30 characters.
- Validate the metadata file's syntax and field limits.
- Confirm no unrelated metadata copy changed.
- Confirm the release-candidate package SHA-256 remains unchanged.
