<?php

date_default_timezone_set("Asia/Dhaka");

$data = json_decode(file_get_contents('php://input'));

$timeStamp = $data->timeStamp ?? '';
$status = $data->status ?? '';
$applicationId = $data->applicationId ?? '';
$subscriberId = $data->subscriberId ?? '';

$log = date('Y-m-d H:i:s') . " | TimeStamp:$timeStamp | Status:$status | AppId:$applicationId | SubscriberId:$subscriberId\n";
file_put_contents('subscription_notifications.log', $log, FILE_APPEND);

header('Content-Type: application/json');
echo json_encode(['statusCode' => 'S1000', 'statusDetail' => 'Notification received']);
