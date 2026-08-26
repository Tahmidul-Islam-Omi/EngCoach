<?php

// Mints Firebase custom tokens so the Flutter app can sign in to Firebase
// with the phone number bdapps just verified.
//
// A custom token is a JWT signed with the project's service-account key.
// That key is a master credential — it bypasses every Firestore rule — so it
// lives OUTSIDE public_html, where LiteSpeed cannot serve it. A .json inside
// public_html would be a plain static download for anyone who guessed the
// name.

define('FIREBASE_KEY_PATH', '/home/bdappsd1/secure/firebase-key.json');

function base64url($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/**
 * Returns a Firebase custom token for $uid, or null if signing is not
 * possible. Callers must treat null as "signed in with bdapps, but Firestore
 * is unavailable" rather than as an authentication failure.
 */
function firebase_custom_token($uid, array $claims = []) {
    if (!is_readable(FIREBASE_KEY_PATH)) {
        return null;
    }

    $key = json_decode(file_get_contents(FIREBASE_KEY_PATH), true);
    if (!is_array($key) || empty($key['client_email']) || empty($key['private_key'])) {
        return null;
    }

    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $payload = [
        'iss' => $key['client_email'],
        'sub' => $key['client_email'],
        'aud' => 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
        'iat' => $now,
        // Firebase caps custom tokens at one hour. The client exchanges this
        // immediately for an ID token, which it then refreshes on its own.
        'exp' => $now + 3600,
        'uid' => $uid,
    ];
    if (!empty($claims)) {
        $payload['claims'] = $claims;
    }

    $signingInput = base64url(json_encode($header)) . '.' . base64url(json_encode($payload));

    $signature = '';
    $ok = openssl_sign($signingInput, $signature, $key['private_key'], OPENSSL_ALGO_SHA256);
    if (!$ok) {
        return null;
    }

    return $signingInput . '.' . base64url($signature);
}
