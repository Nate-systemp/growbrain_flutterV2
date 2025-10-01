<?php
session_start();
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GrowBrain Setup</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
  <!-- Firebase SDKs -->
  <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore-compat.js"></script>
  <script src="scripts/firebase-config.js"></script>
  <script src="scripts/setup_firestore.js"></script>
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
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    
    .setup-container {
      width: 100%;
      max-width: 600px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      padding: 30px;
    }
    
    h1 {
      color: #4CAF50;
      margin-bottom: 20px;
      text-align: center;
    }
    
    .setup-section {
      margin-bottom: 30px;
    }
    
    h2 {
      color: #333;
      font-size: 20px;
      margin-bottom: 15px;
    }
    
    .setup-info {
      background-color: #e8f5e9;
      border-left: 4px solid #4CAF50;
      padding: 15px;
      margin-bottom: 20px;
    }
    
    .setup-warning {
      background-color: #fff3e0;
      border-left: 4px solid #ff9800;
      padding: 15px;
      margin-bottom: 20px;
    }
    
    .setup-steps {
      list-style-position: inside;
      margin-left: 10px;
    }
    
    .setup-steps li {
      margin-bottom: 10px;
    }
    
    .setup-action {
      display: flex;
      justify-content: center;
      margin-top: 20px;
    }
    
    .btn {
      background-color: #4CAF50;
      color: white;
      border: none;
      border-radius: 4px;
      padding: 10px 20px;
      font-size: 16px;
      cursor: pointer;
      transition: all 0.3s;
      text-decoration: none;
      display: inline-block;
    }
    
    .btn:hover {
      background-color: #388e3c;
      transform: translateY(-2px);
      box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    }
    
    .btn:active {
      transform: translateY(0);
    }
    
    .log-container {
      background-color: #f8f9fa;
      border: 1px solid #dee2e6;
      border-radius: 4px;
      padding: 15px;
      margin: 20px 0;
      max-height: 200px;
      overflow-y: auto;
      font-family: monospace;
    }
    
    .log-entry {
      padding: 5px 0;
    }
    
    .log-entry.success {
      color: #28a745;
    }
    
    .log-entry.error {
      color: #dc3545;
    }
    
    .log-entry.info {
      color: #17a2b8;
    }
  </style>
</head>
<body>
  <div class="setup-container">
    <h1>GrowBrain Setup</h1>
    
    <div class="setup-section">
      <h2>Firebase Initialization</h2>
      <div class="setup-info">
        <p>This page will help you set up the necessary Firebase collections for the GrowBrain application.</p>
      </div>
      
      <div class="setup-warning">
        <p><strong>Note:</strong> The setup should only be run once. Running it multiple times may create duplicate sample data.</p>
      </div>
      
      <div class="log-container" id="log-container">
        <div class="log-entry info">Initializing setup...</div>
      </div>
      
      <div class="setup-action">
        <a href="login.php" class="btn">Go to Login</a>
      </div>
    </div>
  </div>
  
  <script>
    // Capture console output to display in the log container
    (function() {
      const logContainer = document.getElementById('log-container');
      
      if (!logContainer) return;
      
      const originalConsoleLog = console.log;
      const originalConsoleError = console.error;
      const originalConsoleInfo = console.info;
      
      console.log = function(message) {
        addLogEntry(message, 'success');
        originalConsoleLog.apply(console, arguments);
      };
      
      console.error = function(message) {
        addLogEntry(message, 'error');
        originalConsoleError.apply(console, arguments);
      };
      
      console.info = function(message) {
        addLogEntry(message, 'info');
        originalConsoleInfo.apply(console, arguments);
      };
      
      function addLogEntry(message, type = 'info') {
        const entry = document.createElement('div');
        entry.className = `log-entry ${type}`;
        entry.textContent = message;
        
        logContainer.appendChild(entry);
        logContainer.scrollTop = logContainer.scrollHeight;
      }
      
      // Log initial message
      console.info('Setup script is running...');
      
      // Check Firebase connection
      setTimeout(() => {
        if (typeof firebase !== 'undefined') {
          console.info('Firebase SDK loaded successfully!');
          console.info('Initializing game records collection...');
        } else {
          console.error('Firebase SDK failed to load! Check your configuration.');
        }
      }, 1000);
    })();
  </script>
</body>
</html> 