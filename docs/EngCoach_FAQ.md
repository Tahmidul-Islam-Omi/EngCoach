# EngCoach — FAQ

**App Name:** EngCoach

**App ID:** `APP_XXXXXX` *(fill from `BDAPPS_APP_ID` in the bdapps portal — My Apps → EngCoach → Credentials)*
**Username:** *(bdapps developer account username)*

**Contact details:**

- **Name:** Tahmidul Islam Omi
- **Mobile No.:** *(fill in)*
- **Email:** *(fill in)*
- **Address:** *(fill in)*

**Access Mode:** Android App (primary), with SMS and USSD supported for subscription and unsubscription.

---

## App Description

EngCoach is a Bangla-medium English learning app for Bangladeshi learners.

It does not run a fixed course. It diagnoses first: a short check finds exactly which
rules and words the learner is getting wrong, teaches only those, and then checks
again so the improvement is a measured number rather than a feeling.

Two sections are live:

- **Grammar** — 6 topics, 33 sub-skills, 396 authored questions.
- **Vocabulary** — 4 levels, 144 word cards, 264 authored questions. The level is
  found adaptively, so a stronger learner starts higher.

Every rule, every word and every wrong answer is explained in **Bangla**, with the
English kept in English. Writing, Speaking, Reading and Listening are planned.

The learner's mobile number is their account. Progress is saved to their number and
follows them to any phone.

**Platform:** Android 6.0 and above. **Version:** 1.0.0 (build 1).

---

## How to Subscribe

All subscription channels:

- **SMS:** Type **`engcoach`** and send to **21213**.
- **USSD:** Dial **`*213*XXXX#`** *(code to be assigned)* and follow the menu.
- **OTP (in the app):**
  1. Open EngCoach and enter your Robi or Cirkle mobile number.
  2. A 6-digit one-time code arrives by SMS from 21213.
  3. Enter the code. Subscription and access begin immediately.

Notes:

- Only **Robi (018)** and **Cirkle (016)** prepaid numbers are supported. Cirkle is the
  network formerly branded Airtel; 016 numbers carried over unchanged on 17 August 2026.
- If the number is already subscribed, the app signs the learner straight in — bdapps
  does not issue an OTP for an existing subscriber.
- A wrong code can be re-entered without a second SMS being sent.
- After a successful subscription the status reads *initial charging pending* for
  about 40–60 seconds before it settles to registered.

---

## How to Unsubscribe

- **SMS:** Type **`STOP engcoach`** and send to **21213**.
- **In the app:** Open **Profile → Unsubscribe** and confirm.

Notes:

- The daily charge and access both stop immediately — there is no remaining paid
  period to run out.
- Learning progress is kept, so subscribing again resumes from where the learner
  left off.
- Signing out of the app does **not** unsubscribe; the two are separate actions and
  the app says so on the screen.

---

## Host Address(es) [IP]

- **176.9.54.45** — `bdappsdigitalapps.com`, path `/engcoach/`

All application traffic (subscription check, OTP send and verify, session token,
unsubscribe) goes to this host. The bdapps callbacks — subscription listener,
incoming SMS and USSD — are registered against the same host.

---

## Charge

**Tk 2.78 (including VAT + SD + SC) per day, with Auto Renewal.**

This is a subscription-based Android application. The charge is taken from the
learner's mobile balance daily until they unsubscribe.

---

## Offer Details

A subscriber gets:

- Full access to every grammar topic and every vocabulary level.
- A personalised learning path — the app teaches only what the learner's own check
  marked weak, and skips what they already know.
- Bangla explanations for every rule, word and wrong answer.
- Before-and-after evidence: each topic is checked before the lessons and again
  after, and the progress screen shows the change for every check taken.
- Progress saved to the mobile number and available on any phone.

---

## How to Use (user manual)

1. **Install and open.** Download EngCoach and open it.
2. **Sign in with your number.** Enter your Robi or Cirkle number. A 6-digit code
   arrives by SMS. Enter it. Your number is your account — there is no password.
3. **Pick a section.** Tap **Learn** and choose **Grammar** or **Vocabulary**.
4. **Take the short check.** A few minutes of questions. This is not a test —
   it decides what you are taught. Nothing is graded and nothing is shown to anyone.
5. **Learn what the check found.** Your lessons cover only the parts you got wrong.
   Each lesson is explained in Bangla with English examples.
6. **Practise.** A few questions after each lesson, with immediate feedback in
   Bangla when an answer is wrong.
7. **Take the second check.** Once every part is practised, a second check —
   different questions, same rules — measures what changed.
8. **See your progress.** The **Progress** tab shows your before-and-after scores,
   which areas are still weak, and every check you have taken, with dates.
9. **Home tells you what to do next.** Each time you open the app, the top card
   names the single next thing to do.
10. **Manage your subscription.** **Profile** shows your number, your subscription
    and the app version, and holds **Sign out** and **Unsubscribe**.
