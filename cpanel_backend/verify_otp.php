<?php

require_once 'config.php';
require_once 'firebase_token.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$otp = trim($_POST['Otp'] ?? '');
$referenceNo = trim($_POST['referenceNo'] ?? '');

if ($otp === '' || $referenceNo === '') {
    echo json_encode(['statusCode' => 'FAILED', 'message' => 'Missing OTP or referenceNo']);
    exit;
}

$requestData = [
    'applicationId' => BDAPPS_APP_ID,
    'password' => BDAPPS_APP_PASSWORD,
    'referenceNo' => $referenceNo,
    'otp' => $otp
];

$ch = curl_init('https://developer.bdapps.com/subscription/otp/verify');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);

if ($responseJson === false) {
    $error = curl_error($ch);
    curl_close($ch);
    echo json_encode(['statusCode' => 'FAILED', 'message' => 'Connection error: ' . $error]);
    exit;
}
curl_close($ch);

$response = json_decode($responseJson, true);

if (!is_array($response)) {
    echo json_encode(['statusCode' => 'FAILED', 'message' => 'Invalid server response']);
    exit;
}

$statusCode = strtoupper((string)($response['statusCode'] ?? ''));

// "INITIAL CHARGING PENDING" settles to REGISTERED about 40 seconds later, so
// it counts as subscribed — the charge has already been accepted.
$subscriptionStatus = strtoupper(trim($response['subscriptionStatus'] ?? ''));
$isSubscribed = $subscriptionStatus === 'REGISTERED'
    || $subscriptionStatus === 'INITIAL CHARGING PENDING';

// The phone number is the Firebase uid. Null when the service-account key is
// missing: the learner is signed in with bdapps, only Firestore is out of
// reach. A wrong code never gets here, so no token is ever minted unverified.
$phone = '';
if (preg_match('/^tel:88(01[3-9][0-9]{8})$/', (string)($response['subscriberId'] ?? ''), $m)) {
    $phone = $m[1];
}

echo json_encode([
    'statusCode' => $response['statusCode'] ?? 'FAILED',
    'statusDetail' => $response['statusDetail'] ?? '',
    'subscriptionStatus' => $response['subscriptionStatus'] ?? '',
    'subscriberId' => $response['subscriberId'] ?? '',
    'version' => $response['version'] ?? '',
    'phone' => $phone,
    'isSubscribed' => $isSubscribed,
    'firebaseToken' => ($statusCode === 'S1000' && $phone !== '')
        ? firebase_custom_token($phone, ['phone' => $phone])
        : null
]);
