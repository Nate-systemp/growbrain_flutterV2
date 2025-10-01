<?php
session_start();
if(isset($_SESSION['admin_username'])) {
    header("Location: index.php");
    exit();
}

$error = "";
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login - GrowBrain Dashboard</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">
    <!-- Firebase SDKs -->
    <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore-compat.js"></script>
    <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-auth-compat.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Poppins', 'Segoe UI', system-ui, -apple-system, sans-serif;
        }

        body {
            background: linear-gradient(135deg, #1e293b, #0f172a);
            background-size: cover;
            background-position: center;
            background-attachment: fixed;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            position: relative;
            overflow: hidden;
        }

        body::before {
            content: '';
            position: absolute;
            width: 150%;
            height: 150%;
            background: url('img/paperbg.jpg') center/cover;
            filter: blur(10px) opacity(0.1);
            z-index: -1;
        }

        .login-container {
            width: 100%;
            max-width: 420px;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(16px);
            padding: 40px;
            border-radius: 24px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2),
                        0 0 0 1px rgba(255, 255, 255, 0.1);
            transform: translateY(0);
            animation: slideUp 0.8s cubic-bezier(0.2, 0.8, 0.2, 1);

        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .logo-container {
            text-align: center;
            margin-bottom: 30px;
        }

        .logo-container h2 {
            color: #1e293b;
            font-size: 32px;
            font-weight: 700;
            margin-top: 15px;
            background: linear-gradient(135deg, #1e293b, #3b82f6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            letter-spacing: -0.5px;
        }

        .form-group {
            margin-bottom: 28px;
            position: relative;
        }

        .form-group label {
            display: block;
            margin-bottom: 10px;
            color: #475569;
            font-size: 14px;
            font-weight: 600;
            transition: color 0.3s ease;
            letter-spacing: 0.3px;
        }

        .form-group i {
            position: absolute;
            left: 16px;
            top: 40px;
            color: #64748b;
            transition: all 0.3s ease;
            font-size: 18px;
        }

        .form-group input {
            width: 100%;
            padding: 14px 14px 14px 48px;
            font-size: 15px;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            background-color: rgba(255, 255, 255, 0.9);
            transition: all 0.3s ease;
        }

        .form-group input:focus {
            outline: none;
            border-color: #3b82f6;
            background-color: #fff;
        }

        .form-group input:focus + i {
            color: #3b82f6;
        }

        .error {
            background-color: #fee2e2;
            color: #ef4444;
            padding: 12px;
            border-radius: 8px;
            font-size: 14px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            animation: shake 0.5s ease;
        }

        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-5px); }
            75% { transform: translateX(5px); }
        }

        .error i {
            margin-right: 8px;
            font-size: 16px;
        }

        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #3b82f6, #2563eb);
            color: white;
            border: none;
            border-radius: 12px;
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

        button:active {
            transform: translateY(0);
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.25);
        }

        @media (max-width: 480px) {
            .login-container {
                padding: 30px 20px;
            }

            .logo-container h2 {
                font-size: 24px;
            }
        }

        /* Dark mode support */
        @media (prefers-color-scheme: dark) {
            .login-container {
                background: linear-gradient(145deg, rgba(30, 41, 59, 0.9), rgba(15, 23, 42, 0.8));
            }

            .logo-container h2 {
                color: #e2e8f0;
            }

            .form-group label {
                color: #94a3b8;
            }

            .form-group input {
                background-color: rgba(30, 41, 59, 0.9);
                border-color: #334155;
                color: #e2e8f0;
            }

            .form-group input:focus {
                background-color: rgba(30, 41, 59, 1);
                border-color: #3b82f6;
            }

            .error {
                background-color: rgba(239, 68, 68, 0.2);
                color: #fca5a5;
            }
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo-container">
            <h2>GrowBrain Dashboard</h2>
            <p style="color: #64748b; margin-top: 8px; font-size: 15px;">Welcome back! Please login to your account.</p>
        </div>
        <div id="error-container" style="display: none;" class="error">
            <i class="fas fa-exclamation-circle"></i>
            <span id="error-message"></span>
        </div>
        <form id="login-form">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" name="username" id="username" required autocomplete="username">
                <i class="fas fa-user"></i>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" name="password" id="password" required autocomplete="current-password">
                <i class="fas fa-lock"></i>
            </div>
            <button type="submit" id="login-btn">
                Sign In
            </button>
        </form>
    </div>

    <script src="scripts/firebase-config.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const loginForm = document.getElementById('login-form');
            const errorContainer = document.getElementById('error-container');
            const errorMessage = document.getElementById('error-message');
            const loginBtn = document.getElementById('login-btn');

            loginForm.addEventListener('submit', function(e) {
                e.preventDefault();
                
                // Show loading state
                loginBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Signing In...';
                loginBtn.disabled = true;
                errorContainer.style.display = 'none';
                
                const username = document.getElementById('username').value;
                const password = document.getElementById('password').value;
                
                // Get Firestore reference
                const db = firebase.firestore();
                
                // Check if user exists in growbrainadminAuth collection
                db.collection('growbrainadminAuth').where('username', '==', username)
                    .get()
                    .then((querySnapshot) => {
                        if (querySnapshot.empty) {
                            throw new Error('No user found with that username');
                        }
                        
                        const adminDoc = querySnapshot.docs[0];
                        const adminData = adminDoc.data();
                        
                        // Check if password matches (in a real implementation, use proper password hashing)
                        if (adminData.password !== password) {
                            throw new Error('Invalid password');
                        }
                        
                        // Set session via AJAX
                        return fetch('set_session.php', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json'
                            },
                            body: JSON.stringify({
                                username: username,
                                profilePicture: adminData.profilePicture || 'img/ITFRAME.jpg'
                            })
                        });
                    })
                    .then(response => response.json())
                    .then(data => {
                        if (data.success) {
                            // Animate the container before redirecting
                            document.querySelector('.login-container').style.animation = 'slideUp 0.6s ease reverse';
                            setTimeout(() => {
                                window.location.href = 'index.php';
                            }, 600);
                        } else {
                            throw new Error('Session creation failed');
                        }
                    })
                    .catch(error => {
                        console.error("Login error:", error);
                        errorMessage.textContent = error.message || 'Authentication failed';
                        errorContainer.style.display = 'flex';
                        loginBtn.innerHTML = 'Sign In';
                        loginBtn.disabled = false;
                    });
            });
        });
    </script>
</body>
</html>
