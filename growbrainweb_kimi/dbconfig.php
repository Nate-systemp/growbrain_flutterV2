<?php
// dbconfig.php

$servername = "localhost";
$username = "root"; // default for XAMPP
$password = "";     // default (empty) for XAMPP
$dbname = "growbrain_auth";

// Turn off mysqli internal error reporting
mysqli_report(MYSQLI_REPORT_OFF);

// Suppress warnings from the constructor with @
$conn = @new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    // Display a custom, user-friendly error page
    ob_start();
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Database Connection Error</title>
      <style>
          body {
              background-color: #f4f4f4;
              font-family: Arial, sans-serif;
              margin: 0;
              padding: 0;
          }
          .container {
              max-width: 600px;
              margin: 100px auto;
              background-color: #fff;
              padding: 20px;
              border: 1px solid #ddd;
              box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
              text-align: center;
          }
          h1 {
              color: #d9534f;
              margin-bottom: 20px;
          }
          p {
              color: #333;
              line-height: 1.6;
          }
          .error-detail {
              font-size: 0.9em;
              color: #777;
              margin-top: 15px;
          }
      </style>
    </head>
    <body>
      <div class="container">
          <h1>Database Connection Error</h1>
          <p>We are having trouble connecting to our database at the moment.</p>
          <p>Please try again later.</p>
      </div>
    </body>
    </html>
    <?php
    ob_end_flush();
    exit;
}
?>
