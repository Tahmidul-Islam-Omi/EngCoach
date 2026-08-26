<?php

require_once 'config.php';
require_once 'sdk_file.php';

$logger = new Logger();

try {
    $receiver = new SMSReceiver();
    $sender = new SMSSender('https://developer.bdapps.com/sms/send', BDAPPS_APP_ID, BDAPPS_APP_PASSWORD);
    $sender->setencoding('8');

    $address = $receiver->getAddress();
    $rawMessage = trim($receiver->getMessage());

    $parts = explode(' ', $rawMessage);
    array_shift($parts);
    $message = trim(implode(' ', $parts));

    $sender->sms('EngCoach: you said [' . $message . ']', $address);

    file_put_contents('sms_log.txt', date('Y-m-d') . ' | ' . $address . ' | ' . $message . "\n", FILE_APPEND);
} catch (SMSServiceException $e) {
    $logger->WriteLog($e->getErrorCode() . ' ' . $e->getErrorMessage());
}
