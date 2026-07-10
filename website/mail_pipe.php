#!/usr/local/bin/php -q
<?php
/* ==========================================================================
   Orbita Go — cPanel Email Pipe Script (mail_pipe.php)
   ========================================================================== */

// 1. Read raw email from standard input
$email_raw = "";
$fd = fopen("php://stdin", "r");
while (!feof($fd)) {
    $email_raw .= fread($fd, 1024);
}
fclose($fd);

// 2. Parse raw email headers and body
$lines = explode("\n", $email_raw);
$from = "unknown@orbitago.uz";
$subject = "(No Subject)";
$body = "";
$is_header = true;

foreach ($lines as $line) {
    if ($is_header) {
        if (trim($line) === "") {
            $is_header = false;
            continue;
        }
        if (preg_match('/^From:\s*(.*)$/i', $line, $matches)) {
            $raw_from = trim($matches[1]);
            // Clean "Name <email@domain.com>" to "email@domain.com"
            if (preg_match('/<([^>]+)>/', $raw_from, $email_match)) {
                $from = trim($email_match[1]);
            } else {
                $from = $raw_from;
            }
        }
        if (preg_match('/^Subject:\s*(.*)$/i', $line, $matches)) {
            $subject = trim($matches[1]);
            // Decode MIME encoded subjects (like UTF-8)
            if (function_exists('mb_decode_mimeheader')) {
                $subject = mb_decode_mimeheader($subject);
            }
        }
    } else {
        $body .= $line . "\n";
    }
}

// 3. Get target account from command line arguments
$account = isset($argv[1]) ? trim($argv[1]) : "info@orbitago.uz";

// 4. Clean up body
$body = trim($body);

// 5. Build payload
$payload = array(
    "account" => $account,
    "from" => $from,
    "subject" => $subject,
    "body" => $body
);

// 6. Post via cURL to the VPS API Webhook
$webhook_url = "https://api.orbitago.uz/api/admin/emails/incoming?token=orbita-email-webhook-token-2026";
$ch = curl_init($webhook_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json'));
curl_setopt($ch, CURLOPT_TIMEOUT, 10);
curl_exec($ch);
curl_close($ch);
