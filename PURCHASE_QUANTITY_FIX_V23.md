# V23 Quantity Fix

- Fixed Purchase quantity handling in `finance-expansion.js`.
- The visible quantity input is now synchronized from the DOM immediately before `erp_create_purchase`.
- Added decimal/Arabic-number normalization.
- Added validation that received purchase quantities are greater than zero.
- Added a single-submit guard to prevent duplicate purchase submissions.
- The purchase RPC receives the exact quantity currently shown in the Purchase UI.
- Bumped the `finance-expansion.js` cache-busting version in `erp.html`.
