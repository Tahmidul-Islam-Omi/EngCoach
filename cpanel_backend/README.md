# cPanel backend

PHP that runs on shared hosting, **not** in the Flutter app. Deployed by hand
through cPanel File Manager.

| | |
|---|---|
| Lives at | `https://bdappsdigitalapps.com/engcoach/` |
| Server path | `public_html/engcoach/` |
| cPanel home | `/home/bdappsd1/` |

## Why this exists at all

Two credentials can never ship inside an APK — anyone can unzip one and read
its strings:

- **`BDAPPS_APP_PASSWORD`** — with it, a stranger could subscribe and
  unsubscribe arbitrary Robi numbers on the account, and send SMS as EngCoach.
- **The Firebase service-account key** — it bypasses every Firestore rule.

So these files hold them instead, and the app only ever talks to this server.

## Credentials — not in git

| file | what | where |
|---|---|---|
| `config.php` | bdapps app id and password | **gitignored**; copy `config.example.php` and fill it in |
| `firebase-key.json` | Firebase service account | `/home/bdappsd1/secure/`, **above** `public_html` |

The Firebase key must stay outside the web root. LiteSpeed serves `.json`
statically, so a key inside `public_html` is a public download for anyone who
guesses the filename. `.php` files execute and leak nothing, which is why
`config.php` is safe where it is.

## The files

**Called by the app**

| file | does |
|---|---|
| `check_subscription.php` | live subscription status; also signs an existing subscriber in |
| `send_otp.php` | asks bdapps for a subscription OTP, returns `referenceNo` |
| `verify_otp.php` | checks the OTP — this is what subscribes and starts the charge |
| `firebase_token.php` | signs the Firebase custom token; `uid` is the phone number |

**Called by bdapps** — ⚠️ these filenames are registered as callback URLs in
the bdapps portal. Renaming one breaks it silently, with only a 404 to show.

| file | does |
|---|---|
| `subscription_listener.php` | told when someone subscribes or texts `STOP engcoach` to 21213 |
| `sms.php` | incoming SMS to the shortcode |
| `ussd.php` | the USSD menu |

**Other:** `unsubscribe.php` (in-app unsubscribe), `sdk_file.php` (bdapps' own
SDK, vendor code — don't edit).

## Behaviour worth knowing, all verified live

- `E1351` — bdapps **refuses** an OTP for an already-subscribed number, which
  is why `check_subscription.php` signs those learners in directly.
- `E1325` — non-Robi/Airtel numbers are rejected by bdapps itself.
- `E1343` — the number isn't whitelisted. In Limited Production **every**
  number must be whitelisted in the portal.
- A wrong OTP returns `E1850` and does **not** invalidate the `referenceNo`,
  so a retry costs no second SMS.
- After a successful verify the status reads `INITIAL CHARGING PENDING` and
  takes **40–60 seconds** to settle to `REGISTERED`. Never gate a new
  subscriber on `isSubscribed` during that window.
- Charge is **Tk 2.78/day**, auto-renewing.

## Known gap

`check_subscription.php` signs an existing subscriber in on a typed phone
number alone, with no code — because bdapps offers no OTP for that case. Anyone
who types a subscribed number gets a Firebase token for it. **Deliberate, and
must be closed before public release.** The fix is to send our own code over
the bdapps MT SMS API (`SMSSender` in `sdk_file.php`) and check it before
minting the token.
