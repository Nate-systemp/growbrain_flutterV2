<?php
session_start();
header('Content-Type: application/json');

if(!isset($_SESSION['admin_username'])) {
    http_response_code(401);
    echo json_encode(array("message" => "Unauthorized"));
    exit();
}

// Get posted data
$newUsername = isset($_POST['username']) ? trim($_POST['username']) : '';
$newPassword = isset($_POST['password']) ? trim($_POST['password']) : '';

if(empty($newUsername) || empty($newPassword)) {
    http_response_code(400);
    echo json_encode(array("message" => "All fields are required."));
    exit();
}

// The current username is stored in the session.
$currentUsername = $_SESSION['admin_username'];

// The JavaScript file will handle the actual update in Firestore.
// Here we just update the session and return a success message.
$_SESSION['admin_username'] = $newUsername;

echo json_encode(array("message" => "Profile updated successfully"));
?>
