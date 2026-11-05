<?php
/**
 * SafeScape 2.0 - The Right Call Cloud API: LOAD
 * Endpoint: GET /api/games/right-call/load?user_id=101
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$userId = isset($_GET['user_id']) ? trim($_GET['user_id']) : '';

if (empty($userId) || $userId === 'guest') {
    echo json_encode([
        "high_score" => 0,
        "total_calls_handled" => 0,
        "successful_calls" => 0,
        "failed_calls" => 0,
        "completed_scenarios" => []
    ]);
    exit;
}

$dbFile = __DIR__ . '/cloud_db.json';
$db = file_exists($dbFile) ? json_decode(file_get_contents($dbFile), true) : ["users" => []];

if (isset($db['users'][$userId])) {
    $u = $db['users'][$userId];
    echo json_encode([
        "user_id" => (int)$u['user_id'],
        "player_name" => $u['player_name'] ?? "Dispatcher_$userId",
        "high_score" => (int)($u['high_score'] ?? 0),
        "total_calls_handled" => (int)($u['total_calls_handled'] ?? 0),
        "successful_calls" => (int)($u['successful_calls'] ?? 0),
        "failed_calls" => (int)($u['failed_calls'] ?? 0),
        "completed_scenarios" => $u['completed_scenarios'] ?? []
    ]);
} else {
    // New user default record
    $newUser = [
        "user_id" => (int)$userId,
        "player_name" => "Dispatcher_$userId",
        "high_score" => 0,
        "total_calls_handled" => 0,
        "successful_calls" => 0,
        "failed_calls" => 0,
        "completed_scenarios" => [],
        "is_won" => false
    ];
    $db['users'][$userId] = $newUser;
    file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
    echo json_encode($newUser);
}
