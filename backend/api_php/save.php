<?php
/**
 * SafeScape 2.0 - The Right Call Cloud API: SAVE
 * Endpoint: POST /api/games/right-call/save
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$input = file_get_contents('php://input');
$payload = json_decode($input, true);

if (!$payload || !isset($payload['user_id'])) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Invalid payload"]);
    exit;
}

$userId = (string)$payload['user_id'];
if ($userId === '0' || $userId === 'guest') {
    echo json_encode(["status" => "saved", "note" => "Guest progress received"]);
    exit;
}

$dbFile = __DIR__ . '/cloud_db.json';
$db = file_exists($dbFile) ? json_decode(file_get_contents($dbFile), true) : ["users" => []];

$existing = $db['users'][$userId] ?? [
    "user_id" => (int)$userId,
    "player_name" => "User_$userId",
    "high_score" => 0,
    "total_calls_handled" => 0,
    "successful_calls" => 0,
    "failed_calls" => 0,
    "completed_scenarios" => []
];

// Update profile metrics
$existing['high_score'] = max((int)($existing['high_score'] ?? 0), (int)($payload['score'] ?? 0));
$existing['total_calls_handled'] = max((int)($existing['total_calls_handled'] ?? 0), (int)($payload['calls_handled'] ?? 0));
$existing['successful_calls'] = max((int)($existing['successful_calls'] ?? 0), (int)($payload['successful_calls'] ?? 0));
$existing['failed_calls'] = max((int)($existing['failed_calls'] ?? 0), (int)($payload['failed_calls'] ?? 0));

if (isset($payload['completed_scenarios']) && is_array($payload['completed_scenarios'])) {
    $existing['completed_scenarios'] = array_values(array_unique(array_merge(
        $existing['completed_scenarios'] ?? [],
        $payload['completed_scenarios']
    )));
}

if (!empty($payload['is_won'])) {
    $existing['is_won'] = true;
    $existing['won_at'] = date('c');
}

$existing['last_saved'] = date('c');
$db['users'][$userId] = $existing;

file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));

http_response_code(200);
echo json_encode([
    "status" => "saved",
    "user_id" => (int)$userId,
    "high_score" => $existing['high_score'],
    "total_calls" => $existing['total_calls_handled']
]);
