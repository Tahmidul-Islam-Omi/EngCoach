<?php

require_once 'config.php';

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
    if (strlen($digits) === 13 && substr($digits, 0, 2) === '88') {
        $digits = substr($digits, 2);
    }
    return $digits;
}

$rawMobile = trim($_POST['user_mobile'] ?? $_POST['subscriberId'] ?? '');

if ($rawMobile === '') {
    echo json_encode(['error' => 'Mobile number required']);
    exit;
}

$digits = bdapps_normalize_mobile($rawMobile);

if (strlen($digits) !== 11 || $digits[0] !== '0') {
    echo json_encode(['error' => 'Invalid mobile format']);
    exit;
}

$subscriberId = 'tel:88' . $digits;

$requestData = [
    'applicationId' => BDAPPS_APP_ID,
    'password' => BDAPPS_APP_PASSWORD,
    'subscriberId' => $subscriberId,
    'version' => '1.0',
    'action' => '0'
];

$ch = curl_init('https://developer.bdapps.com/subscription/send');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);
$curlError = curl_error($ch);
curl_close($ch);

if ($responseJson === false) {
    echo json_encode(['success' => false, 'error' => $curlError, 'subscriberId' => $subscriberId]);
    exit;
}

$response = json_decode($responseJson, true);

if (!is_array($response)) {
    echo json_encode(['success' => false, 'error' => 'Invalid response', 'subscriberId' => $subscriberId]);
    exit;
}

$statusCode = strtoupper((string)($response['statusCode'] ?? ''));
$subscriptionStatus = strtoupper((string)($response['subscriptionStatus'] ?? 'UNKNOWN'));

echo json_encode([
    'success' => $statusCode === 'S1000' || $subscriptionStatus === 'UNREGISTERED',
    'subscriberId' => $subscriberId,
    'statusCode' => $response['statusCode'] ?? null,
    'statusDetail' => $response['statusDetail'] ?? null,
    'subscriptionStatus' => $response['subscriptionStatus'] ?? null
]);
