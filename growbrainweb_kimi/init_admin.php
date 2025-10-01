<?php
// This is a one-time script to initialize the admin collection in Firebase

// HTML form to create the first admin
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Initialize Admin</title>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
                font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            }

            body {
                background-color: #f5f5f5;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }

            .init-container {
                width: 100%;
                max-width: 500px;
                background: white;
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            }

            h2 {
                color: #1e293b;
                font-size: 24px;
                margin-bottom: 20px;
                text-align: center;
            }

            .warning {
                background-color: #fff3cd;
                color: #856404;
                padding: 12px;
                margin-bottom: 20px;
                border-radius: 6px;
                font-size: 14px;
                text-align: center;
            }

            .form-group {
                margin-bottom: 20px;
                position: relative;
            }

            .form-group label {
                display: block;
                margin-bottom: 8px;
                color: #64748b;
                font-size: 14px;
                font-weight: 500;
            }

            .form-group input {
                width: 100%;
                padding: 12px;
                font-size: 15px;
                border: 2px solid #e2e8f0;
                border-radius: 6px;
                background-color: #f9f9f9;
                transition: all 0.3s ease;
            }

            .form-group input:focus {
                outline: none;
                border-color: #3b82f6;
                background-color: #fff;
            }

            button {
                width: 100%;
                padding: 14px;
                background: linear-gradient(135deg, #3b82f6, #2563eb);
                color: white;
                border: none;
                border-radius: 6px;
                font-size: 16px;
                font-weight: 500;
                cursor: pointer;
                transition: all 0.3s ease;
                box-shadow: 0 4px 12px rgba(59, 130, 246, 0.25);
            }

            button:hover {
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(59, 130, 246, 0.35);
            }

            .success {
                background-color: #d1e7dd;
                color: #146c43;
                padding: 12px;
                margin-bottom: 20px;
                border-radius: 6px;
                font-size: 14px;
                text-align: center;
                display: none;
            }

            .error {
                background-color: #f8d7da;
                color: #b02a37;
                padding: 12px;
                margin-bottom: 20px;
                border-radius: 6px;
                font-size: 14px;
                text-align: center;
                display: none;
            }
        </style>
        <!-- Firebase SDKs -->
        <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js"></script>
        <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore-compat.js"></script>
    </head>
    <body>
        <div class="init-container">
            <h2>Create Initial Admin Account</h2>
            <div class="warning">
                <strong>Warning:</strong> This script should only be run once to set up the admin account.
            </div>
            <div id="success-message" class="success"></div>
            <div id="error-message" class="error"></div>
            <form id="init-form">
                <div class="form-group">
                    <label for="username">Username</label>
                    <input type="text" name="username" id="username" required>
                </div>
                <div class="form-group">
                    <label for="password">Password</label>
                    <input type="password" name="password" id="password" required>
                </div>
                <div class="form-group">
                    <label for="confirm-password">Confirm Password</label>
                    <input type="password" name="confirm-password" id="confirm-password" required>
                </div>
                <button type="submit">Create Admin Account</button>
            </form>
        </div>

        <script src="scripts/firebase-config.js"></script>
        <script>
            document.addEventListener('DOMContentLoaded', function() {
                const form = document.getElementById('init-form');
                const successMessage = document.getElementById('success-message');
                const errorMessage = document.getElementById('error-message');

                form.addEventListener('submit', function(e) {
                    e.preventDefault();
                    
                    const username = document.getElementById('username').value.trim();
                    const password = document.getElementById('password').value;
                    const confirmPassword = document.getElementById('confirm-password').value;
                    
                    // Basic validation
                    if (username === '' || password === '') {
                        showError('Username and password are required');
                        return;
                    }
                    
                    if (password !== confirmPassword) {
                        showError('Passwords do not match');
                        return;
                    }
                    
                    const db = firebase.firestore();
                    
                    // Check if collection already has admins
                    db.collection('growbrainadminAuth').get()
                        .then((snapshot) => {
                            if (!snapshot.empty) {
                                throw new Error('Admin account already exists. For security reasons, you cannot create another admin account using this tool.');
                            }
                            
                            // Create the admin document
                            return db.collection('growbrainadminAuth').add({
                                username: username,
                                password: password, // Note: In production, use proper password hashing
                                profilePicture: 'img/ITFRAME.jpg',
                                createdAt: new Date()
                            });
                        })
                        .then(() => {
                            showSuccess('Admin account created successfully! You can now log in.');
                            form.reset();
                            
                            // Redirect to login page after 3 seconds
                            setTimeout(() => {
                                window.location.href = 'login.php';
                            }, 3000);
                        })
                        .catch((error) => {
                            console.error('Error:', error);
                            showError(error.message);
                        });
                });
                
                function showSuccess(message) {
                    successMessage.textContent = message;
                    successMessage.style.display = 'block';
                    errorMessage.style.display = 'none';
                }
                
                function showError(message) {
                    errorMessage.textContent = message;
                    errorMessage.style.display = 'block';
                    successMessage.style.display = 'none';
                }
            });
        </script>
    </body>
    </html>
    <?php
    exit();
}
?> 