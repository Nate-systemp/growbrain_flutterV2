<?php
session_start();
if (!isset($_SESSION['admin_username'])) {
    header("Location: login.php");
    exit();
}

// Use the profile picture from session
$profilePicture = isset($_SESSION['profile_picture']) ? $_SESSION['profile_picture'] : 'img/ITFRAME.jpg';
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>GrowBrain Dashboard</title>
  <link rel="stylesheet" href="styles/style.css" />
  <link rel="stylesheet" href="styles/activities.css" />
  <link rel="stylesheet" href="styles/ui.css" />
  <!-- Font Awesome for icons -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css" />
  <!-- Chart.js for charts -->
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <!-- jsPDF and html2canvas for PDF generation -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
  <!-- jsPDF AutoTable plugin for better PDF tables -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.5.25/jspdf.plugin.autotable.min.js"></script>
  <!-- Animation library -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/animate.css/4.1.1/animate.min.css" />
  <!-- Firebase SDKs (compat version) -->
  <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-firestore-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/9.6.1/firebase-auth-compat.js"></script>
  <!-- Custom Scripts -->
  <script src="scripts/firebase-config.js" defer></script>
  <script src="scripts/script.js" defer></script>
  <script src="scripts/admin_profile.js" defer></script>
  <script src="scripts/add_admin.js" defer></script>
  <script src="scripts/activities.js" defer></script>
  <script src="scripts/ui.js" defer></script>
  <!-- Add CSS Animations -->
  <style>
    /* Animation Effects */
    .fadeIn { animation: fadeIn 0.5s ease-in-out; }
    .slideIn { animation: slideIn 0.5s ease-in-out; }
    .pulseEffect { animation: pulse 2s infinite; }
    
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    
    @keyframes slideIn {
      from { transform: translateY(20px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }
    
    @keyframes pulse {
      0% { transform: scale(1); }
      50% { transform: scale(1.05); }
      100% { transform: scale(1); }
    }
    
    /* Highlighted values with counters */
    .highlight-value {
      position: relative;
      transition: color 0.3s ease;
      display: inline-block;
    }
    
    .highlight-value:hover {
      color: #4CAF50;
    }
    
    .counting {
      animation: countingEffect 1.5s ease-out;
    }
    
    @keyframes countingEffect {
      0% { opacity: 0.7; transform: scale(0.95); }
      50% { opacity: 1; transform: scale(1.15); }
      100% { opacity: 1; transform: scale(1); }
    }
    
    /* Enhanced hover effects */
    .stat-card {
      transition: all 0.3s ease;
      border-left: 3px solid transparent;
    }
    
    .stat-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 6px 12px rgba(0,0,0,0.1);
      border-left: 3px solid #4CAF50;
    }
    
    .floating-add-button {
      transition: all 0.3s ease;
    }
    
    .floating-add-button:hover {
      transform: rotate(90deg);
      box-shadow: 0 6px 12px rgba(0,0,0,0.15);
    }
    
    /* Improved table rows */
    table tbody tr {
      transition: all 0.2s ease;
    }
    
    table tbody tr:hover {
      background-color: rgba(76, 175, 80, 0.1);
    }
    
    /* Button animations */
    button {
      transition: all 0.2s ease;
      position: relative;
      overflow: hidden;
    }
    
    button:after {
      content: '';
      position: absolute;
      top: 50%;
      left: 50%;
      width: 5px;
      height: 5px;
      background: rgba(255, 255, 255, 0.5);
      opacity: 0;
      border-radius: 100%;
      transform: scale(1, 1) translate(-50%);
      transform-origin: 50% 50%;
    }
    
    button:focus:not(:active)::after {
      animation: ripple 1s ease-out;
    }
    
    @keyframes ripple {
      0% {
        transform: scale(0, 0);
        opacity: 0.5;
      }
      20% {
        transform: scale(25, 25);
        opacity: 0.5;
      }
      100% {
        opacity: 0;
        transform: scale(40, 40);
      }
    }
    
    /* Form field animations */
    input, select {
      transition: all 0.3s ease;
      border: 1px solid #ddd;
    }
    
    input:focus, select:focus {
      border-color: #4CAF50;
      box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.2);
    }
    
    /* Modal animations */
    .modal-content {
      animation: modalFadeIn 0.3s ease-in-out;
      transform-origin: top;
    }
    
    @keyframes modalFadeIn {
      from {
        opacity: 0;
        transform: translateY(-20px) scale(0.95);
      }
      to {
        opacity: 1;
        transform: translateY(0) scale(1);
      }
    }
    
    /* Improved sidebar navigation */
    .sidebar-item {
      transition: all 0.3s ease;
      position: relative;
    }
    
    .sidebar-item a {
      transition: all 0.3s ease;
    }
    
    .sidebar-item:hover a {
      color: #4CAF50;
    }
    
    .sidebar-item:before {
      content: '';
      position: absolute;
      left: 0;
      top: 0;
      height: 100%;
      width: 3px;
      background-color: #4CAF50;
      transform: scaleY(0);
      transition: transform 0.3s ease;
    }
    
    .sidebar-item.active:before, 
    .sidebar-item:hover:before {
      transform: scaleY(1);
    }
    
    /* Form field enhancements */
    .form-group {
      position: relative;
      margin-bottom: 20px;
    }
    
    .form-group label {
      position: relative;
      display: inline-block;
      margin-bottom: 8px;
      transition: all 0.3s ease;
    }
    
    .form-group input:focus + label,
    .form-group select:focus + label {
      color: #4CAF50;
    }
    
    .form-group input,
    .form-group select {
      width: 100%;
      padding: 10px 12px;
      border-radius: 4px;
      border: 1px solid #ddd;
      transition: all 0.3s ease;
      background-color: #f9f9f9;
    }
    
    .form-group input:focus,
    .form-group select:focus {
      outline: none;
      border-color: #4CAF50;
      box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.2);
      background-color: #fff;
    }
    
    /* Checkbox styling */
    .checkbox-label {
      display: flex;
      align-items: center;
      margin-bottom: 10px;
      cursor: pointer;
      user-select: none;
      transition: all 0.2s ease;
    }
    
    .checkbox-label:hover {
      color: #4CAF50;
    }
    
    .checkbox-label input[type="checkbox"] {
      position: relative;
      width: 18px;
      height: 18px;
      margin-right: 10px;
      cursor: pointer;
      appearance: none;
      border: 1px solid #ddd;
      border-radius: 3px;
      transition: all 0.3s ease;
    }
    
    .checkbox-label input[type="checkbox"]:checked {
      background-color: #4CAF50;
      border-color: #4CAF50;
    }
    
    .checkbox-label input[type="checkbox"]:checked::after {
      content: '✓';
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-size: 12px;
    }
    
    /* Button improvements */
    button {
      position: relative;
      overflow: hidden;
      cursor: pointer;
      transition: all 0.3s ease;
    }
    
    button:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    
    button:active {
      transform: translateY(0);
      box-shadow: 0 2px 6px rgba(0,0,0,0.1);
    }
    
    /* Loading indicator */
    .loading-spinner {
      display: inline-block;
      width: 20px;
      height: 20px;
      border: 3px solid rgba(255,255,255,.3);
      border-radius: 50%;
      border-top-color: #fff;
      animation: spin 1s ease-in-out infinite;
    }
    
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    
    /* Confirmation toast style */
    .confirmation-toast {
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: rgba(76, 175, 80, 0.9);
      color: white;
      padding: 12px 20px;
      border-radius: 4px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 9999;
      max-width: 300px;
      display: flex;
      align-items: center;
    }
    
    .confirmation-content {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    
    .confirmation-toast i {
      font-size: 20px;
    }
    
    .fadeOut {
      animation: fadeOut 0.5s forwards;
    }
    
    @keyframes fadeOut {
      from { opacity: 1; transform: translateY(0); }
      to { opacity: 0; transform: translateY(10px); }
    }
    
    /* Improve scrollbars */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }
    
    ::-webkit-scrollbar-track {
      background: #f1f1f1;
      border-radius: 10px;
    }
    
    ::-webkit-scrollbar-thumb {
      background: #888;
      border-radius: 10px;
    }
    
    ::-webkit-scrollbar-thumb:hover {
      background: #4CAF50;
    }
  </style>
</head>
<body>
  <div class="container">
    <!-- Sidebar Container: loaded dynamically -->
    <div id="sidebar-container"></div>

    <!-- Main Content -->
    <div class="main-content">
      <header>
        <div class="user-info">
          <span><?php echo htmlspecialchars($_SESSION['admin_username']); ?></span>
          <!-- Profile icon is clickable (id="profile-trigger") -->
          <div class="user-avatar" id="profile-trigger" style="cursor:pointer;">
            <img src="<?php echo htmlspecialchars($profilePicture); ?>?v=<?php echo time(); ?>" alt="User Avatar" />
          </div>
        </div>
      </header>
      <main>
        <!-- Dashboard Section -->
        <section id="dashboard-section">          <div class="stats-container">
            <div class="stat-card">
              <div class="stat-icon">
                <i class="fas fa-graduation-cap"></i>
              </div>
              <div class="stat-info">
                <span>Total Students Enrolled</span>
                <h2 id="total-students" class="highlight-value">0</h2>
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-icon">
                <i class="fas fa-chart-line"></i>
              </div>
              <div class="stat-info">
                <span>Average Progress Score</span>
                <h2 id="avg-progress" class="highlight-value">0%</h2>
              </div>
            </div>
          </div>
          <div class="chart-container">
            <h3>Student Progress Over Time</h3>
            <div class="chart-wrapper">
              <canvas id="progressChart"></canvas>
            </div>
            <div class="chart-legend">
              <div class="legend-item">
                <span class="legend-color" style="background-color: #4CAF50;"></span>
                <span>Improving : <span id="improving-count">0</span></span>
              </div>
              <div class="legend-item">
                <span class="legend-color" style="background-color: #FFC107;"></span>
                <span>Needs Attention : <span id="needs-attention-count">0</span></span>
              </div>
              <div class="legend-item">
                <span class="legend-color" style="background-color: #FF5722;"></span>
                <span>Struggling : <span id="struggling-count">0</span></span>
              </div>
            </div>
          </div>
        </section>

        <!-- Students Section (CRUD) -->
        <section id="students-section" style="display: none;">
          <h2>Manage Students</h2>
          <!-- Student Search moved outside -->
          <div class="student-search-container" style="margin-bottom: 20px;">
            <div class="search-input-wrapper">
              <i class="fas fa-search search-icon"></i>
              <input type="text" id="student-search" placeholder="Search by student name..." class="search-input">
            </div>
          </div>
          <div class="students-content">
            <div class="table-container student-table-container">
              <h3>Student List</h3>
              <br>
              <button id="open-student-form-btn" class="floating-add-button">
                <i class="fas fa-plus"></i>
              </button>
              <!-- Students Table -->
              <table id="students-table">
                <thead>
                  <tr>
                    <th style="width: 160px; padding-left: 16px;">Name</th>
                    <th style="width: 80px;">Age</th>
                    <th style="width: 80px;">Sex</th>
                    <th style="width: 180px;">Cognitive Challenges</th>
                    <th style="width: 120px;">Contact Number</th>
                    <th style="width: 140px;">Guardian Name</th>
                    <th style="width: 100px; padding-right: 16px;">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <!-- Data inserted dynamically by JavaScript -->
                </tbody>
              </table>
            </div>
          </div>
        </section>

<!-- Updated Student Modal Form -->
<div id="student-modal" class="modal" style="display: none;">
  <div class="modal-content student-modal-content">
    <span id="student-modal-close" class="close">&times;</span>
    <h3 id="form-title">Add New Student</h3>
    <form id="student-form">
      <!-- Hidden field for document ID -->
      <input type="hidden" id="student-id" value="">
      <div class="form-group">
        <label for="student-name">Name:</label>
        <input type="text" id="student-name" placeholder="Enter student name" required>
      </div>
      <div class="form-group">
        <label for="student-age">Age:</label>
        <div class="age-input-container">
          <input type="number" id="student-age" placeholder="Enter age" required>
          <span class="age-suffix">years old</span>
        </div>
      </div>
      <div class="form-group">
        <label for="student-gender">sex:</label>
        <select id="student-gender" required>
          <option value="">Select sex</option>
          <option value="Male">Male</option>
          <option value="Female">Female</option>
          <option value="Other">Other</option>
        </select>
      </div>
      <div class="form-group">
        <label>Cognitive Challenges:</label>
        <div class="checkbox-container">
          <label class="checkbox-label">
            <input type="checkbox" class="cognitive-challenge" value="Attention"> Attention
          </label>
          <label class="checkbox-label">
            <input type="checkbox" class="cognitive-challenge" value="Logic"> Logic
          </label>
          <label class="checkbox-label">
            <input type="checkbox" class="cognitive-challenge" value="Memory"> Memory
          </label>
          <label class="checkbox-label">
            <input type="checkbox" class="cognitive-challenge" value="Verbal"> Verbal
          </label>
        </div>
      </div>
      <div class="form-group">
        <label for="student-contact">Contact Number:</label>
        <input type="text" id="student-contact" placeholder="Enter contact number" required>
      </div>
      <div class="form-group">
        <label for="student-guardian">Guardian Name:</label>
        <input type="text" id="student-guardian" placeholder="Enter guardian name" required>
      </div>
      <div class="form-actions">
        <button type="submit" id="submit-btn"><i class="fas fa-plus-circle"></i> Add Student</button>
        <button type="button" id="cancel-btn" style="display: none;"><i class="fas fa-times-circle"></i> Cancel</button>
      </div>
    </form>
  </div>
</div>


<!-- Records Section -->
<section id="records-section" style="display: none;">
  <h2>Student Records</h2>
  
  <!-- Records Search -->
  <div class="records-search-container">
    <div class="search-input-wrapper">
      <i class="fas fa-search search-icon"></i>
      <input type="text" id="records-search" placeholder="Search by student name..." class="search-input">
    </div>
  </div>
  
  <!-- Records List -->
  <div class="records-content">
    <div class="table-container records-table-container">
      <h3>Student List</h3>
      <table id="records-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Age</th>
            <th>Sex</th>
            <th>Cognitive Challenges</th>
            <th>Contact Number</th>
            <th>Guardian Name</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <!-- Data inserted dynamically by JavaScript -->
        </tbody>
      </table>
    </div>
  </div>
</section>

<!-- Student Records Modal -->
<div id="records-modal" class="modal" style="display: none;">
  <div class="modal-content records-modal-content">
    <span id="records-modal-close" class="close">&times;</span>
    
    <h3 id="records-student-name">Student Name's Records</h3>
    
    <!-- Records Statistics -->
    <div class="records-stats">
      <div class="stat-card">
        <div class="stat-icon">
          <i class="fas fa-clock"></i>
        </div>
        <div class="stat-info">
          <span>Average Completion Time</span>
          <h3 id="avg-completion-time" class="highlight-value">0 sec</h3>
        </div>
      </div>
      
      <div class="stat-card">
        <div class="stat-icon">
          <i class="fas fa-bullseye"></i>
        </div>
        <div class="stat-info">
          <span>Average Accuracy</span>
          <h3 id="avg-accuracy" class="highlight-value">0.0%</h3>
        </div>
      </div>
    </div>
    
    <div class="records-actions" style="margin: 20px 0; text-align: right;">
      <button id="view-detailed-analytics-btn" class="btn-analytics">
        <i class="fas fa-chart-line"></i> View Detailed Analytics
      </button>
    </div>
    
    <!-- Records Details Table -->
    <div class="records-list-container">
      <h4>Session Details</h4>
      <table id="student-records-table">
        <thead>
          <tr>
            <th>Date</th>
            <th>Challenge Focus</th>
            <th>Difficulty</th>
            <th>Accuracy</th>
            <th>Completion Time</th>
            <th>Last Played</th>
          </tr>
        </thead>
        <tbody>
          <!-- Records data inserted dynamically by JavaScript -->
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Activities Section -->
<section id="activities-section" style="display: none;">
  <h2>Activities</h2>
  <!-- Activities Controls -->
  <div class="activities-controls">
    <div class="search-input-wrapper">
      <i class="fas fa-search search-icon"></i>
      <input type="text" id="activities-search" placeholder="Search by student name..." class="search-input">
    </div>
    <div class="activities-filters">
      <div class="filter-group">
        <label for="challenge-filter">Challenge Focus:</label>
        <select id="challenge-filter" class="filter-select">
          <option value="">All Challenges</option>
          <option value="Memory">Memory</option>
          <option value="Attention">Attention</option>
          <option value="Logic">Logic</option>
          <option value="Verbal">Verbal</option>
        </select>
      </div>
      <div class="filter-group">
        <label for="game-filter">Game Type:</label>
        <select id="game-filter" class="filter-select">
          <option value="">All Games</option>
          <!-- Will be populated dynamically -->
        </select>
      </div>
      <div class="filter-group">
        <label for="date-range">Date Range:</label>
        <select id="date-range" class="filter-select">
          <option value="all">All Time</option>
          <option value="today">Today</option>
          <option value="week">This Week</option>
          <option value="month">This Month</option>
        </select>
      </div>
    </div>
  </div>
  <!-- Activities Dashboard -->
  <div class="activities-dashboard">
    <div class="dashboard-cards">
      <div class="dashboard-card">
        <div class="card-icon"><i class="fas fa-gamepad"></i></div>
        <div class="card-content">
          <h4>Total Sessions</h4>
          <p id="total-game-sessions" class="highlight-value">0</p>
        </div>
      </div>
      <div class="dashboard-card">
        <div class="card-icon"><i class="fas fa-brain"></i></div>
        <div class="card-content">
          <h4>Most Played Challenge</h4>
          <p id="most-played-challenge" class="highlight-value">-</p>
        </div>
      </div>
      <div class="dashboard-card">
        <div class="card-icon"><i class="fas fa-bullseye"></i></div>
        <div class="card-content">
          <h4>Average Accuracy</h4>
          <p id="average-accuracy" class="highlight-value">0%</p>
        </div>
      </div>
      <div class="dashboard-card">
        <div class="card-icon"><i class="fas fa-stopwatch"></i></div>
        <div class="card-content">
          <h4>Average Time</h4>
          <p id="average-time" class="highlight-value">0 sec</p>
        </div>
      </div>
    </div>
    <div class="activities-charts">
      <div class="chart-container">
        <h4>Challenge Distribution</h4>
        <canvas id="challenge-distribution-chart"></canvas>
      </div>
      <div class="chart-container">
        <h4>Weekly Activity</h4>
        <canvas id="weekly-activity-chart"></canvas>
      </div>
    </div>
  </div>
  <!-- Activities List -->
  <div class="activities-content">
    <div class="table-container activities-table-container">
      <div class="table-header">
        <h3>Game Records</h3>
        <div class="table-actions">
          <button id="refresh-activities" class="btn-refresh" title="Refresh Data">
            <i class="fas fa-sync-alt"></i>
          </button>
                    <button id="export-activities" class="btn-export" title="Export to PDF">            <i class="fas fa-file-pdf"></i>          </button>
        </div>
      </div>
      <div class="table-responsive">
        <table id="activities-table">
          <thead>
            <tr>
              <th>Student Name</th>
              <th>Challenge Focus</th>
              <th>Game</th>
              <th>Accuracy</th>
              <th>Completion Time</th>
              <th>Difficulty</th>
              <th>Date</th>
              <th>Last Played</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <!-- Data inserted dynamically by JavaScript -->
            <tr class="loading-row">
              <td colspan="9"><div class="loading-spinner"></div> Loading records...</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="table-pagination">
        <div class="pagination-info">Showing <span id="pagination-showing">0</span> of <span id="pagination-total">0</span> records</div>
        <div class="pagination-controls">
          <button id="pagination-prev" disabled><i class="fas fa-chevron-left"></i></button>
          <span id="pagination-current">1</span>
          <button id="pagination-next" disabled><i class="fas fa-chevron-right"></i></button>
        </div>
      </div>
    </div>
  </div>
  <!-- Activity Details Modal -->
  <div id="activity-details-modal" class="modal">
    <div class="modal-content activity-modal-content">
      <span class="close" id="activity-details-close">&times;</span>
      <h3>Game Session Details</h3>
      <div class="activity-details-container">
        <div class="activity-detail-card student-info">
          <h4><i class="fas fa-user-graduate"></i> Student Information</h4>
          <p><strong>Name:</strong> <span id="detail-student-name">-</span></p>
        </div>
        <div class="activity-detail-card game-info">
          <h4><i class="fas fa-gamepad"></i> Game Information</h4>
          <p><strong>Game:</strong> <span id="detail-game-name">-</span></p>
          <p><strong>Challenge Focus:</strong> <span id="detail-challenge-focus">-</span></p>
          <p><strong>Difficulty Level:</strong> <span id="detail-difficulty">-</span></p>
        </div>
        <div class="activity-detail-card performance-info">
          <h4><i class="fas fa-chart-line"></i> Performance Metrics</h4>
          <div class="detail-metrics">
            <div class="detail-metric">
              <span class="metric-value" id="detail-accuracy">-</span>
              <span class="metric-label">Accuracy</span>
            </div>
            <div class="detail-metric">
              <span class="metric-value" id="detail-completion-time">-</span>
              <span class="metric-label">Completion Time</span>
            </div>
            <div class="detail-metric">
              <span class="metric-value" id="detail-errors">-</span>
              <span class="metric-label">Errors</span>
            </div>
          </div>
        </div>
        <div class="activity-detail-card session-info">
          <h4><i class="fas fa-clock"></i> Session Information</h4>
          <p><strong>Date:</strong> <span id="detail-date">-</span></p>
          <p><strong>Last Played:</strong> <span id="detail-last-played">-</span></p>
          <p><strong>Record ID:</strong> <span id="detail-record-id">-</span></p>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- Detailed Student Analytics Modal -->
<div id="student-analytics-modal" class="modal" style="display: none;">
  <div class="modal-content analytics-modal-content">
    <span id="analytics-modal-close" class="close">&times;</span>
    
    <h3 id="analytics-student-name">Student Dashboard: <span id="student-name-display"></span></h3>
    
    <div class="analytics-layout">
      <!-- Left Column - Student Info and Charts -->
      <div class="analytics-main-column">
        <div class="student-overview">
          <h4>Student Overview</h4>
          <div class="overview-stats">
            <div class="overview-stat">
              <span class="label">Total Sessions:</span>
              <span id="total-sessions-display" class="value"></span>
            </div>
            <div class="overview-stat">
              <span class="label">Challenge Categories:</span>
              <span id="challenge-categories-display" class="value"></span>
            </div>
          </div>
        </div>
        
        <div class="charts-row">
          <div class="analytics-chart-card">
            <h4>Accuracy Trends</h4>
            <div class="chart-container">
              <canvas id="accuracy-chart"></canvas>
            </div>
          </div>
          
          <div class="analytics-chart-card">
            <h4>Completion Time Trends</h4>
            <div class="chart-container">
              <canvas id="completion-time-chart"></canvas>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Right Column - Performance and Stats -->
      <div class="analytics-side-column">
        <div class="key-statistics">
          <h4>Key Statistics</h4>
          
          <div class="key-stat">
            <h3 id="avg-accuracy-percent" class="highlight-value">30.95%</h3>
            <p>Average Accuracy</p>
          </div>
          
          <div class="key-stat">
            <h3 id="avg-completion-seconds" class="highlight-value">4.02 sec</h3>
            <p>Average Completion Time</p>
          </div>
          
          <div class="key-stat">
            <h3 id="total-sessions-count" class="highlight-value">2</h3>
            <p>Total Sessions</p>
          </div>
        </div>
        
        <div class="performance-chart-container">
          <h4>Overall Performance</h4>
          <div class="chart-container donut-container">
            <canvas id="performance-chart"></canvas>
          </div>
        </div>
        
        <div class="recent-sessions">
          <h4>Recent Sessions</h4>
          <div id="recent-sessions-list">
            <!-- Recent sessions will be displayed here -->
          </div>
        </div>
      </div>
    </div>
  </div>
</div>


        <!-- Settings Section -->
        <section id="settings-section" style="display: none;">
          <h2>Setting</h2>
          <div class="settings-container">
            <label for="dark-mode-toggle">Dark Mode:</label>
            <label class="switch">
              <input type="checkbox" id="dark-mode-toggle">
              <span class="slider"></span>
            </label>
          </div>
        </section>

        <!-- Add Admin Section -->
        <section id="add-admin-section" style="display: none;">
          <h2>Admin Management</h2>
          <div id="admin-list-container">            <p>Total Admins: <span id="admin-count">0</span></p>            <ul class="admin-list" id="admin-list">              <!-- Admin list will be populated by JavaScript -->            </ul>            <script>              // Load admin list from Firebase              document.addEventListener('DOMContentLoaded', function() {                const db = firebase.firestore();                db.collection('growbrainadminAuth').get()                  .then((querySnapshot) => {                    const adminCount = querySnapshot.size;                    document.getElementById('admin-count').textContent = adminCount;                                        const adminList = document.getElementById('admin-list');                    adminList.innerHTML = '';                                        querySnapshot.forEach((doc) => {                      const adminData = doc.data();                      const username = adminData.username;                      const profilePic = adminData.profilePicture || 'img/default image.jpg';                                            const li = document.createElement('li');                      li.innerHTML = `                        <div class='admin-profile-wrap'>                          <img src='${profilePic}' alt='Profile Picture of ${username}' class='admin-profile-pic' />                        </div>                        <span class='admin-username'>${username}</span>                      `;                      adminList.appendChild(li);                    });                  })                  .catch((error) => {                    console.error("Error getting admin list:", error);                  });              });            </script>
          </div>
          
          <!-- Floating Add Admin Button -->
          <button id="add-admin-button" class="floating-add-button">
            <i class="fas fa-plus"></i>
          </button>
          
          <!-- Add Admin Modal -->
          <div id="add-admin-modal" class="modal">
            <div class="modal-content">
              <span class="close" id="add-admin-modal-close">&times;</span>
              <h3>Add New Admin</h3>
              <form id="admin-form">
                <div class="form-group">
                  <label for="admin-username">Username:</label>
                  <input type="text" id="admin-username" name="username" placeholder="Enter admin username" required>
                </div>
                <div class="form-group">
                  <label for="admin-password">Password:</label>
                  <input type="password" id="admin-password" name="password" placeholder="Enter password" required>
                </div>
                <div class="modal-actions">
                  <button type="submit" class="btn-save">Add Admin</button>
                  <button type="button" class="btn-cancel" id="add-admin-cancel">Cancel</button>
                </div>
              </form>
            </div>
          </div>
        </section>

        <!-- Teacher Emails Section -->
        <section id="teacher-emails-section" style="display: none;">
          <h2>Manage Teachers</h2>
          <!-- Teacher Search moved outside -->
          <div class="teacher-search-container" style="margin-bottom: 20px;">
            <div class="search-input-wrapper">
              <i class="fas fa-search search-icon"></i>
              <input type="text" id="teacher-search" placeholder="Search by teacher name or email..." class="search-input">
            </div>
          </div>
          <div class="teachers-content">
            <div class="table-container teacher-table-container">
              <h3>Teacher List</h3>
              <!-- Floating Add Teacher Button -->
              <button id="open-teacher-form-btn" class="floating-add-button">
                <i class="fas fa-plus"></i>
              </button>
              <table id="teacher-table">
                <thead>
                  <tr>
                    <th>Created At</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Password</th>
                    <th>PIN</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <!-- Data inserted dynamically by JavaScript -->
                </tbody>
              </table>
            </div>
          </div>
        </section>

        <!-- Teacher Modal Form -->
        <div id="teacher-modal" class="modal" style="display: none;">
          <div class="modal-content teacher-modal-content">
            <span id="teacher-modal-close" class="close">&times;</span>
            <h3 id="teacher-form-title">Add New Teacher</h3>
            <form id="teacher-form">
              <div class="form-group">
                <label for="teacher-name">Name:</label>
                <input type="text" id="teacher-name" placeholder="Enter teacher name" required>
              </div>
              <div class="form-group">
                <label for="teacher-email">Email:</label>
                <input type="email" id="teacher-email" placeholder="Enter email" required>
              </div>
              <div class="form-group">
                <label for="teacher-password">Password:</label>
                <input type="password" id="teacher-password" placeholder="Enter password" required>
              </div>
              <div class="form-group">
                <label for="teacher-pin">PIN (6 digits):</label>
                <input type="text" id="teacher-pin" placeholder="Enter 6-digit PIN" maxlength="6" pattern="\d{6}" required>
              </div>
              <div class="form-actions">
                <button type="submit" id="teacher-submit-btn" class="btn-save">Add Teacher</button>
                <button type="button" id="teacher-cancel-btn" class="btn-cancel">Cancel</button>
              </div>
            </form>
          </div>
        </div>

<!-- Delete Confirmation Modal for Teachers -->
<div id="delete-teacher-modal" class="modal">
  <div class="modal-content">
    <h3>Confirm Delete</h3>
    <p>Are you sure you want to delete this teacher account? This action cannot be undone.</p>
    <div class="modal-actions">
      <button id="confirm-delete-teacher" class="btn-delete">Delete</button>
      <button id="cancel-delete-teacher" class="btn-cancel">Cancel</button>
    </div>
  </div>
</div>

<!-- Edit PIN Modal -->
<div id="edit-pin-modal" class="modal">
  <div class="modal-content">
    <span class="close" id="edit-pin-modal-close">&times;</span>
    <h3>Edit PIN</h3>
    <div class="form-group">
      <label for="edit-pin-input">New PIN (6 digits):</label>
      <input type="text" id="edit-pin-input" maxlength="6" pattern="\d{6}" required>
    </div>
    <div class="modal-actions">
      <button id="edit-pin-save" class="btn-save">Save</button>
      <button id="edit-pin-cancel" class="btn-cancel">Cancel</button>
    </div>
  </div>
</div>

<!-- Edit Name Modal -->
<div id="edit-name-modal" class="modal">
  <div class="modal-content">
    <span class="close" id="edit-name-modal-close">&times;</span>
    <h3>Edit Name</h3>
    <div class="form-group">
      <label for="edit-name-input">New Name:</label>
      <input type="text" id="edit-name-input" required>
    </div>
    <div class="modal-actions">
      <button id="edit-name-save" class="btn-save">Save</button>
      <button id="edit-name-cancel" class="btn-cancel">Cancel</button>
    </div>
  </div>
</div>

<!-- Edit Teacher Modal -->
<div id="edit-teacher-modal" class="modal">
  <div class="modal-content">
    <span class="close" id="edit-teacher-modal-close">&times;</span>
    <h3>Edit Teacher Information</h3>
    <div class="form-group">
      <label for="edit-teacher-name">Name:</label>
      <input type="text" id="edit-teacher-name" required>
    </div>
    <div class="form-group">
      <label for="edit-teacher-pin">PIN (6 digits):</label>
      <input type="text" id="edit-teacher-pin" maxlength="6" pattern="\d{6}" required>
    </div>
    <div class="modal-actions">
      <button id="edit-teacher-save" class="btn-save">Save</button>
      <button id="edit-teacher-cancel" class="btn-cancel">Cancel</button>
    </div>
  </div>
</div>

      </main>
    </div>
  </div>

 

 <!-- Profile Modal -->
 <div id="profile-modal" class="modal">
    <div class="modal-content">
      <span class="close">&times;</span>
      <h2>User Profile</h2>
      <div class="profile-info">
        <img src="<?php echo htmlspecialchars($profilePicture); ?>?v=<?php echo time(); ?>" alt="Profile Picture" class="profile-pic" />
        <p><?php echo htmlspecialchars($_SESSION['admin_username']); ?></p>
      </div>
      <div class="profile-actions">
        <a href="logout.php" class="btn logout-btn">Logout</a>
        <button id="edit-profile-btn" class="btn edit-profile-btn">Edit Profile</button>
      </div>
      <div id="profile-edit-section" style="display: none;">
        <form id="profile-form" enctype="multipart/form-data">
          <div class="form-group">
            <label for="profile-username">Username:</label>
            <input type="text" id="profile-username" name="username" value="<?php echo htmlspecialchars($_SESSION['admin_username']); ?>" data-current-username="<?php echo htmlspecialchars($_SESSION['admin_username']); ?>" required>
          </div>
          <div class="form-group">
            <label for="profile-password">Password:</label>
            <input type="password" id="profile-password" name="password" placeholder="Enter new password" required>
          </div>
          <div class="form-group profile-picture-group">
            <label for="profile-picture">Profile Picture:</label>
            <div class="profile-picture-preview">
              <img id="profile-picture-preview-img" src="<?php echo htmlspecialchars($profilePicture); ?>?v=<?php echo time(); ?>" alt="Profile Picture">
            </div>
            <input type="file" id="profile-picture" name="profile_picture" accept="image/*">
          </div>
          <div class="form-actions">
            <button type="submit" id="profile-save-btn" class="modern-save-btn">Save Changes</button>
          </div>
        </form>
      </div>
    </div>
  </div>

  <!-- Custom Confirmation Dialog -->
  <div id="confirm-dialog" class="confirm-dialog" style="display: none;">
    <div class="confirm-dialog-content">
      <p id="confirm-message">Are you sure you want to delete this student?</p>
      <div class="confirm-actions">
        <button id="confirm-yes" class="btn confirm-yes">Yes</button>
        <button id="confirm-no" class="btn confirm-no">No</button>
      </div>
    </div>
  </div>

  <!-- Custom Result Window / Toast -->
  <div id="result-window" class="result-window" style="display: none;">
    <span id="result-message"></span>
    <button id="close-result-btn">&times;</button>
  </div>

  <script>
    // Load the sidebar from sidebar.php
    fetch('sidebar.php')
      .then(response => response.text())
      .then(data => {
        document.getElementById('sidebar-container').innerHTML = data;
        initSidebar();
      })
      .catch(error => console.error('Error loading sidebar:', error));
  </script>
</body>
</html>

<style>
.student-name-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

.student-name-cell span {
  flex: 1;
}

.btn-view-inline {
  background: none;
  border: none;
  color: #2196F3;
  font-size: 14px;
  padding: 0;
  cursor: pointer;
  opacity: 0.7;
  transition: all 0.2s;
}

.btn-view-inline:hover {
  opacity: 1;
  transform: scale(1.2);
}

.student-name-cell:hover .btn-view-inline {
  opacity: 1;
}
</style>

<style>
/* Student Records Grouping Styles */
.student-main-row {
  background-color: #f5f5f5;
  transition: background-color 0.2s ease;
}

.student-main-row:hover {
  background-color: rgba(76, 175, 80, 0.1);
}

.student-name-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.student-toggle {
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 500;
  color: #333;
}

.expand-icon {
  transition: transform 0.2s ease;
  font-size: 12px;
  color: #666;
}

.student-toggle[data-expanded="true"] .expand-icon {
  transform: rotate(90deg);
}

.student-record-count {
  font-size: 12px;
  color: #888;
  font-weight: normal;
}

.student-records-container {
  background-color: #f9f9f9;
}

.student-records-details {
  padding: 15px;
}

.nested-records-table {
  width: 100%;
  border-collapse: collapse;
  border: 1px solid #eee;
  font-size: 13px;
}

.nested-records-table th {
  background-color: #e9e9e9;
  padding: 8px 12px;
  text-align: left;
  font-weight: 600;
  color: #555;
  border-bottom: 1px solid #ddd;
}

.nested-records-table td {
  padding: 8px 12px;
  border-bottom: 1px solid #eee;
  color: #444;
}

.nested-records-table tr:last-child td {
  border-bottom: none;
}

.nested-records-table tr:hover {
  background-color: rgba(76, 175, 80, 0.05);
}

.btn-view-detail {
  background: none;
  border: none;
  color: #2196F3;
  padding: 4px;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.2s;
}

.btn-view-detail:hover {
  background-color: rgba(33, 150, 243, 0.1);
  transform: scale(1.1);
}

.btn-expand-records {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
}

/* Show a hand cursor on the entire student row to indicate it's expandable */
.student-main-row td {
  cursor: pointer;
}
</style>