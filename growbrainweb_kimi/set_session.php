<?php
session_start();
header('Content-Type: application/json');

// Get JSON data from POST request
$jsonData = file_get_contents('php://input');
$data = json_decode($jsonData, true);

if (!$data || !isset($data['username'])) {
    echo json_encode(['success' => false, 'message' => 'Invalid data provided']);
    exit();
}

// Set session variables
$_SESSION['admin_username'] = $data['username'];
$_SESSION['profile_picture'] = $data['profilePicture'] ?? 'img/ITFRAME.jpg';

// Return success response
echo json_encode(['success' => true, 'message' => 'Session created successfully']);
?> 