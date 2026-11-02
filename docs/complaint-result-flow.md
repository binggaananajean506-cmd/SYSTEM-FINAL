# One hearing-result entry point

Once a hearing starts, the complaint case has one Record result button. The form asks Settled or Not settled, who attended, and agreement/notes. Settled requires both attendance confirmations and saves through the existing record_result action, closing the case. Not settled saves through record_result when both attended, or record_nonattendance when a party is explicitly unchecked. No server attendance or CFA guards are weakened.

Only after confirmed success does the floating activity offer Schedule next hearing (rounds 1–5) or Review CFA (round 6). Scheduling uses a separate form with no repeated attendance fields and blank date/time. The case remains in Needs action if the official continues elsewhere; opening it shows the same next step. No seventh round is offered. Save failures preserve state and existing retry/recovery behavior. Existing six-round, 20-A/20-B, audit and operation-version controls remain unchanged.

Browser coverage includes settled closure, no agreement with both parties present, actual respondent absence, rejection of a settlement with an absent party, future schedule validation, and the six-round path through 20-B printing/PDF. The complaint Delete controls remain available in the list and case footer.
