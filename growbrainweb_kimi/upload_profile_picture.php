<?php
session_start();

if (!isset($_SESSION['admin_username'])) {
    http_response_code(403);
    echo json_encode(['status' => 'error', 'message' => 'Unauthorized']);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['profile_picture'])) {
    // Define the upload directory (make sure this folder exists and is writable)
    $uploadDir = 'img/';
    $file = $_FILES['profile_picture'];

    if ($file['error'] === UPLOAD_ERR_OK) {
        // Validate file type
        $allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
        $filename = basename($file['name']);
        $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
        if (!in_array($ext, $allowedExtensions)) {
            echo json_encode(['status' => 'error', 'message' => 'Invalid file type.']);
            exit();
        }

        // Generate a unique filename to prevent overwriting
        $uniqueFilename = uniqid('profile_') . '.' . $ext;
        $destination = $uploadDir . $uniqueFilename;

        // Move the uploaded file to the destination folder
        if (move_uploaded_file($file['tmp_name'], $destination)) {
            // Update the session with the new profile picture path
            $_SESSION['profile_picture'] = $destination;
            
            echo json_encode(['status' => 'success', 'file' => $destination]);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'File upload failed.']);
        }
    } else {
        echo json_encode(['status' => 'error', 'message' => 'File error: ' . $file['error']]);
    }
} else {
    echo json_encode(['status' => 'error', 'message' => 'Invalid request.']);
}
?>
