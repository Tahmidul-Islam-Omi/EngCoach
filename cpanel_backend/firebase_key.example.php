<?php

// Template for firebase_key.php — the Firebase service-account key.
//
// Copy this to firebase_key.php and paste the whole downloaded JSON between
// the single quotes, replacing the example below. Keep it a .php file: a raw
// .json in this folder is a public download, and this key bypasses every
// Firestore security rule.
//
// Preferred alternative, if you can write above public_html:
//   /home/bdappsd1/secure/firebase-key.json
// firebase_token.php checks there first and uses this only as a fallback.
//
// firebase_key.php is gitignored. This template is not.

return '{
  "type": "service_account",
  "project_id": "engcoach-app",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@engcoach-app.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}';
