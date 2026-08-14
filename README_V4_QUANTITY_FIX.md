# V4 – Invoice Quantity Input Fix

Fixed the invoice line quantity field so it is reliably editable in Firefox/RTL layouts and accepts English or Arabic-Indic digits.

Changes:
- Quantity uses a text input with decimal input mode for better browser compatibility.
- Arabic-Indic and Persian digits are normalized to numeric values.
- Arabic decimal separator is accepted.
- Quantity field is explicitly selectable/clickable and uses LTR numeric direction.
- Existing invoice calculations and validation remain unchanged.
