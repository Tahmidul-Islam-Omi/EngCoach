<?php

require_once 'config.php';
require_once 'firebase_token.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

function bdapps_normalize_mobile($raw) {
    $digits = preg_replace('/\D+/', '', $raw);
    if (strpos($digits, '880') === 0 && strlen($digits) === 13) {
        $digits = '0' . substr($digits, 3);
    } elseif (strpos($digits, '88') === 0 && strlen($digits) === 12) {
        $digits = '0' . substr($digits, 2);
    }
    return $digits;
}

$digits = bdapps_normalize_mobile($_POST['user_mobile'] ?? '');

if (!preg_match('/^01[3-9][0-9]{8}$/', $digits)) {
    echo json_encode(['error' => 'Invalid mobile number format']);
    exit;
}

$subscriberId = 'tel:88' . $digits;

$requestData = [
    'version' => '1.0',
    'applicationId' => BDAPPS_APP_ID,
    'password' => BDAPPS_APP_PASSWORD,
    'subscriberId' => $subscriberId
];

$ch = curl_init('https://developer.bdapps.com/subscription/getStatus');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);
$curlError = curl_error($ch);
curl_close($ch);

if ($responseJson === false) {
    echo json_encode(['error' => 'Connection failed', 'details' => $curlError]);
    exit;
}

$response = json_decode($responseJson, true);

if (!is_array($response)) {
    echo json_encode(['error' => 'Invalid response']);
    exit;
}

$status = strtoupper(trim($response['subscriptionStatus'] ?? ''));

// "INITIAL CHARGING PENDING" counts as subscribed. It is the state for the
// 40-60 seconds after a successful verify, and the charge has already been
// accepted — treating it as unsubscribed would throw a learner who just paid
// straight onto the "your subscription has stopped" screen.
$isSubscribed = $status === 'REGISTERED' || $status === 'INITIAL CHARGING PENDING';

// An already-subscribed number is signed in here, with no code: bdapps
// refuses a subscription OTP to an existing subscriber (E1351), so there is
// no second factor available on this path.
//
// !! KNOWN GAP, deliberate, revisit before production !!
// This means anyone who types a subscribed number receives a Firebase token
// for it, and can read and write that learner's data — which also makes the
// Firestore rules unenforceable. Closing it means sending our own code over
// the bdapps MT SMS API (SMSSender in sdk_file.php) and checking it before
// the token is minted.
echo json_encode([
    'subscriptionStatus' => $status,
    'isSubscribed' => $isSubscribed,
    'statusCode' => $response['statusCode'] ?? null,
    'statusDetail' => $response['statusDetail'] ?? null,
    'version' => $response['version'] ?? null,
    'subscriberId' => $subscriberId,
    'phone' => $digits,
    'firebaseToken' => $isSubscribed
        ? firebase_custom_token($digits, ['phone' => $digits])
        : null
]);
