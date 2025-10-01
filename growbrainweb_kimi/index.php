<?php
session_start();
if (!isset($_SESSION['admin_username'])) {
    header("Location: login.php");
    exit();
}

// Use the profile picture and username from session
$profilePicture = isset($_SESSION['profile_picture']) ? $_SESSION['profile_picture'] : 'img/ITFRAME.jpg';
$username = isset($_SESSION['admin_username']) ? $_SESSION['admin_username'] : 'Admin';
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
  <link rel="stylesheet" href="styles/teacher-switcher.css" />
  <link rel="stylesheet" href="styles/dashboard.css" />
  <link rel="stylesheet" href="styles/dashboard-simple.css" />
  <link rel="stylesheet" href="styles/managestudents.css" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
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
  <script src="scripts/teacher-switcher.js" defer></script>
  <script src="scripts/script.js" defer></script>
  <script src="scripts/admin_profile.js" defer></script>
  <script src="scripts/add_admin.js" defer></script>
  <script src="scripts/activities.js" defer></script>
  <script src="scripts/ui.js" defer></script>

  <!-- Sidebar Toggle Script -->
  <script>
    document.addEventListener('DOMContentLoaded', function() {
      const sidebarToggle = document.getElementById('sidebar-toggle');
      const container = document.querySelector('.container');
      const overlay = document.createElement('div');
      overlay.className = 'sidebar-overlay';
      document.body.appendChild(overlay);

      function toggleSidebar() {
        container.classList.toggle('sidebar-active');
        if (container.classList.contains('sidebar-active')) {
          overlay.style.display = 'block';
          setTimeout(() => overlay.style.opacity = '1', 0);
        } else {
          overlay.style.opacity = '0';
          setTimeout(() => overlay.style.display = 'none', 300);
        }
      }

      sidebarToggle.addEventListener('click', toggleSidebar);
      overlay.addEventListener('click', toggleSidebar);

      // Close sidebar on window resize if in mobile view
      window.addEventListener('resize', function() {
        if (window.innerWidth > 768 && container.classList.contains('sidebar-active')) {
          container.classList.remove('sidebar-active');
          overlay.style.display = 'none';
        }
      });
    });
  </script>

  <!-- Add CSS Animations -->
  <style>
    /* Cognitive Needs Styles */
    .cognitive-needs-container {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 15px;
      margin-top: 10px;
    }

    .cognitive-need-item {
      display: flex;
      align-items: center;
      gap: 10px;
      cursor: pointer;
      padding: 8px;
      border-radius: 4px;
      transition: background-color 0.2s;
    }

    .cognitive-need-item:hover {
      background-color: rgba(76, 175, 80, 0.05);
    }

    .cognitive-need-item input[type="checkbox"] {
      width: 18px;
      height: 18px;
      cursor: pointer;
    }

    .cognitive-need-item span {
      font-size: 0.95rem;
      color: #333;
    }

    /* Activities Section Styles */
    .activities-controls {
      margin-bottom: 30px;
      display: flex;
      flex-wrap: wrap;
      gap: 20px;
      align-items: flex-start;
    }

    .activities-filters {
      display: flex;
      gap: 15px;
      flex-wrap: wrap;
    }

    .filter-group {
      display: flex;
      flex-direction: column;
      gap: 5px;
    }

    .filter-select {
      padding: 8px;
      border: 1px solid #ddd;
      border-radius: 4px;
      min-width: 150px;
    }

    .activities-stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }

    .activities-charts {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }

    .activities-charts .chart-container { scroll-margin-top: 90px; }

    .activities-charts h4 {
      margin-top: 0;
      margin-bottom: 15px;
      color: #333;
    }

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
    
    /* Enhanced Dashboard Styles */
    .dashboard-content {
      padding: 20px;
      display: grid;
      gap: 24px;
    }

    .stats-container {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 20px;
      margin-bottom: 24px;
    }

    .stat-card {
      background: white;
      border-radius: 12px;
      padding: 24px;
      display: flex;
      align-items: flex-start;
      gap: 16px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.05);
      transition: all 0.3s ease;
    }

    .stat-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 15px rgba(0,0,0,0.1);
    }

    .stat-icon {
      background: rgba(76, 175, 80, 0.1);
      padding: 12px;
      border-radius: 10px;
      color: #4CAF50;
      font-size: 1.5rem;
    }

    .stat-info {
      flex: 1;
    }

    .stat-info span {
      color: #666;
      font-size: 0.9rem;
      display: block;
      margin-bottom: 5px;
    }

    .stat-info h2 {
      font-size: 2rem;
      margin: 0;
      color: #333;
      font-weight: 600;
    }

    .stat-trend {
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 0.8rem;
      margin-top: 8px;
      color: #666;
    }

    .stat-trend.positive {
      color: #4CAF50;
    }

    .stat-trend.negative {
      color: #f44336;
    }

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
    
    /* Enhanced Header and Sidebar Layout */
    .container {
      display: grid;
      grid-template-columns: 250px 1fr;
      min-height: 100vh;
      background: #f5f7fa;
      position: relative;
    }

    /* Sidebar Toggle Button - Hidden by default for desktop */
    .sidebar-toggle {
      display: none;
    }

    #sidebar-container {
      position: fixed;
      top: 0;
      left: 0;
      height: 100%;
      width: 250px;
      background: #1a237e;
      z-index: 1000;
      bottom: 0;
    }

    .main-content {
      position: relative;
      padding: 0;
      background: #f5f7fa;
      margin-left: 250px;
      padding-left: -250px;
      height: 100vh;
      overflow-y: auto;
      overflow-x: hidden;
    }

    header {
      position: fixed;
      top: 0;
      left: 250px;
      right: 0;
      z-index: 100;
      background: white;
      padding: 15px 30px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      display: flex;
      justify-content: flex-end;
      align-items: center;
      margin-bottom: 20px;
      width: calc(100% - 250px);
    }

    /* Desktop View - No Changes Above 1024px */
    @media (min-width: 1025px) {
      .container,
      #sidebar-container,
      .main-content,
      header {
        /* Ensure desktop view stays fixed */
        position: fixed !important;
        width: 250px !important;
        left: 0 !important;
        transform: none !important;
      }

      #sidebar-container {
        position: fixed !important;
        width: 250px !important;
        left: 0 !important;
        transform: none !important;
      }

      .main-content {
        margin-left: 250px !important;
        width: calc(100% - 250px) !important;
      }

      header {
        left: 250px !important;
        width: calc(100% - 250px) !important;
      }

      .sidebar-toggle {
        display: none !important;
      }
    }

    /* Responsive Design - Only affects mobile/tablet */
    @media (max-width: 1024px) {
      .stats-container {
        grid-template-columns: repeat(2, 1fr);
      }
      
      .quick-actions-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }

    @media (max-width: 768px) {
      .container {
        grid-template-columns: 1fr;
      }

      .sidebar-toggle {
        display: block;
        position: fixed;
        top: 15px;
        left: 15px;
        z-index: 1100;
        background: #4CAF50;
        color: white;
        border: none;
        width: 40px;
        height: 40px;
        border-radius: 50%;
        cursor: pointer;
        box-shadow: 0 2px 5px rgba(0,0,0,0.2);
      }

      #sidebar-container {
        left: -250px;
        transition: left 0.3s ease;
        height: 100%;
        min-height: 100vh;
        bottom: 0;
      }

      .sidebar-active #sidebar-container {
        left: 0;
      }

      .main-content {
        margin-left: 0;
        width: 100%;
        transition: margin-left 0.3s ease;
      }

      header {
        left: 0;
        width: 100%;
        padding: 15px 60px;
        transition: left 0.3s ease, width 0.3s ease;
        position: fixed;
        top: 0;
        z-index: 1000;
      }

      .main-content > main {
        padding-top: 80px;
      }

      .stats-container {
        grid-template-columns: 1fr;
      }

      .chart-container {
        overflow-x: auto;
      }

      .quick-actions-grid {
        grid-template-columns: 1fr;
      }

      .records-header {
        flex-direction: column;
        align-items: stretch;
        gap: 15px;
      }
      
      .records-header > div {
        flex-direction: column;
        align-items: stretch;
        gap: 10px;
      }
      
      .records-header button {
        width: 100%;
        justify-content: center;
      }

      .search-input-wrapper {
        max-width: none;
      }

      .table-container {
        margin: 0;
        padding: 0;
        width: 100%;
        background: #f5f7fa;
      }

      .student-table-container {
        padding-top: 10px;
        padding-bottom: 20px;
      }

      /* Hide table headers on mobile */
      #students-table thead {
        display: none;
      }

      /* Convert table rows to cards */
      #students-table tbody tr {
        display: block;
        background: white;
        margin: 15px;
        padding: 20px;
        border-radius: 12px;
        box-shadow: 0 4px 8px rgba(0,0,0,0.1);
      }

      #students-table tbody td {
        display: flex;
        align-items: center;
        padding: 12px 0;
        text-align: left;
        border: none;
        border-bottom: 1px solid #f0f0f0;
      }

      #students-table tbody td:last-child {
        border-bottom: none;
        margin-top: 10px;
        justify-content: flex-end;
      }

      /* Add labels before content */
      #students-table tbody td::before {
        content: attr(data-label);
        font-weight: 600;
        min-width: 120px;
        padding-right: 15px;
        color: #444;
      }

      /* Style student name differently */
      #students-table tbody td:first-child {
        font-size: 1.1em;
        font-weight: 600;
        color: #2c3e50;
        border-bottom: 2px solid #f0f0f0;
        margin-bottom: 10px;
      }

      /* Style action buttons */
      #students-table tbody td:last-child .btn-edit,
      #students-table tbody td:last-child .btn-delete {
        padding: 8px 16px;
        margin: 0 5px;
        border-radius: 6px;
      }

      /* Style for student cards */
      .student-card {
        display: flex;
        flex-direction: column;
        gap: 8px;
      }

      .student-card-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 10px;
        padding-bottom: 10px;
        border-bottom: 1px solid #eee;
      }

      .student-name {
        font-size: 1.1rem;
        font-weight: 600;
        color: #2c3e50;
      }

      .student-info-row {
        display: flex;
        align-items: center;
        gap: 8px;
        color: #666;
      }

      #students-table thead {
        position: sticky;
        top: 0;
        background: white;
        z-index: 10;
      }

      #students-table tbody tr:nth-child(even) {
        background: rgba(0,0,0,0.02);
      }

      .floating-add-button {
        position: fixed;
        bottom: 20px;
        right: 20px;
        z-index: 1000;
        width: 56px;
        height: 56px;
        border-radius: 50%;
        background: #4CAF50;
        color: white;
        border: none;
        box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .search-input-wrapper {
        position: relative;
        width: 100%;
        max-width: none;
        margin-bottom: 15px;
      }
    }

    @media (max-width: 480px) {
      .user-info span {
        display: none;
      }

      header {
        padding: 15px 20px 15px 70px;
      }

      .header-controls {
        flex-direction: column;
        gap: 8px;
        align-items: flex-start;
      }

      .teacher-switcher-btn {
        padding: 6px 12px;
        font-size: 12px;
      }

      .school-year-selector {
        flex-direction: column;
        align-items: flex-start;
        gap: 4px;
      }

      .school-year-selector label {
        font-size: 12px;
        margin-right: 0;
      }

      .school-year-selector select {
        min-width: 100px;
        font-size: 12px;
        padding: 6px 10px;
      }
    }

      .chart-legend {
        flex-direction: column;
        align-items: flex-start;
      }

      /* Enhanced mobile styles for student list */
      .student-table-container {
        margin: 0 -15px;
        padding: 15px;
        background: #f5f7fa;
      }

      .student-table-header {
        margin-bottom: 20px;
      }

      .student-actions {
        display: flex;
        gap: 10px;
        justify-content: flex-end;
        margin-top: 10px;
        padding-top: 10px;
        border-top: 1px solid #eee;
      }

      .student-actions button {
        background: none;
        border: none;
        width: 40px;
        height: 40px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #666;
        transition: all 0.3s ease;
      }

      .btn-edit {
        background: rgba(76, 175, 80, 0.1) !important;
        color: #4CAF50 !important;
      }

      .btn-delete {
        background: rgba(244, 67, 54, 0.1) !important;
        color: #f44336 !important;
      }

      .student-info-row {
        display: flex;
        align-items: center;
        padding: 8px 0;
        border-bottom: 1px solid #f5f5f5;
      }

      .student-info-row:last-child {
        border-bottom: none;
      }

      /* Enhance search on mobile */
      .search-input-wrapper {
        margin: 15px;
        width: calc(100% - 30px);
        background: white;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      }

      .search-input {
        width: 100%;
        height: 45px;
        font-size: 16px;
        padding: 12px 45px;
        border: none;
        border-radius: 8px;
        background: transparent;
      }

      .search-icon {
        left: 15px;
        font-size: 18px;
        color: #666;
      }

      .student-table-header {
        margin: 15px;
        padding-right: 15px !important;
      }

      .student-table-header h3 {
        font-size: 1.4em;
        color: #2c3e50;
      }
    }

    /* Sidebar Overlay */
    .sidebar-overlay {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.5);
      z-index: 999;
      opacity: 0;
      transition: opacity 0.3s ease;
    }

    /* Main content padding with header space */
    .main-content > main {
      padding: 20px;
      margin-top: 70px;
    }

    /* Improved sidebar navigation */
    .sidebar-item {
      transition: all 0.3s ease;
      position: relative;
      margin: 5px 0;
    }
    
    .sidebar-item a {
      transition: all 0.3s ease;
      padding: 12px 20px;
      display: flex;
      align-items: center;
      gap: 10px;
      border-radius: 8px;
      margin: 0 10px;
    }
    
    .sidebar-item:hover a {
      color: #4CAF50;
      background: rgba(76, 175, 80, 0.1);
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
    
    /* Enhanced Teacher Section Styles */
    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 2rem;
      padding: 0 1rem;
    }

    .teacher-search-container {
      background: white;
      padding: 1.5rem;
      border-radius: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
      margin-bottom: 2rem;
    }

    .teacher-filters {
      display: flex;
      gap: 1rem;
      margin-top: 1rem;
    }

    .filter-select {
      padding: 0.5rem 1rem;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      background: white;
      color: #333;
      cursor: pointer;
      transition: all 0.3s ease;
    }

    .filter-select:hover {
      border-color: #4CAF50;
    }

    .teachers-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1.5rem;
      margin-bottom: 2rem;
    }

    .teacher-card {
      background: white;
      border-radius: 12px;
      padding: 1.5rem;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
      transition: all 0.3s ease;
    }

    .teacher-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 16px rgba(0,0,0,0.1);
    }

    .teacher-profile {
      display: flex;
      align-items: center;
      gap: 1rem;
      margin-bottom: 1rem;
    }

    .teacher-avatar {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      object-fit: cover;
      border: 2px solid #4CAF50;
    }

    .teacher-info h4 {
      margin: 0;
      color: #2c3e50;
      font-size: 1.1rem;
    }

    .teacher-info p {
      margin: 0.25rem 0;
      color: #666;
      font-size: 0.9rem;
    }

    .teacher-stats {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 1rem;
      margin-top: 1rem;
    }

    .stat-item {
      text-align: center;
      padding: 0.5rem;
      background: #f8f9fa;
      border-radius: 8px;
    }

    .stat-value {
      font-size: 1.2rem;
      font-weight: 600;
      color: #4CAF50;
    }

    .stat-label {
      font-size: 0.8rem;
      color: #666;
    }

    .modern-table {
      width: 100%;
      border-collapse: separate;
      border-spacing: 0;
      background: white;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }

    .modern-table th {
      background: #f8f9fa;
      padding: 1rem;
      font-weight: 600;
      color: #2c3e50;
      text-align: left;
      border-bottom: 2px solid #e0e0e0;
    }

    .modern-table td {
      padding: 1rem;
      border-bottom: 1px solid #e0e0e0;
      color: #333;
    }

    .modern-table tr:last-child td {
      border-bottom: none;
    }

    .modern-table tr:hover {
      background: #f8f9fa;
    }

    .teacher-status {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 500;
    }

    .status-active {
      background: rgba(76, 175, 80, 0.1);
      color: #4CAF50;
    }

    .status-inactive {
      background: rgba(244, 67, 54, 0.1);
      color: #f44336;
    }

    .teacher-pagination {
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 1rem;
      margin-top: 2rem;
    }

    .pagination-btn {
      padding: 0.5rem 1rem;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      background: white;
      color: #333;
      cursor: pointer;
      transition: all 0.3s ease;
    }

    .pagination-btn:hover {
      background: #4CAF50;
      color: white;
      border-color: #4CAF50;
    }

    #page-info {
      font-size: 0.9rem;
      color: #666;
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

    /* Header Controls Styles */
    .header-controls {
      display: flex;
      align-items: center;
      gap: 15px;
    }

    .teacher-switcher-btn {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 15px;
      background: rgba(76, 175, 80, 0.1);
      border-radius: 20px;
      cursor: pointer;
      transition: all 0.3s ease;
      border: 1px solid rgba(76, 175, 80, 0.2);
    }

    .teacher-switcher-btn:hover {
      background: rgba(76, 175, 80, 0.15);
      border-color: rgba(76, 175, 80, 0.3);
    }

    .teacher-switcher-btn i {
      color: #4CAF50;
    }

    .teacher-switcher-btn span {
      font-weight: 500;
      color: #2c3e50;
      font-size: 14px;
    }

    .school-year-selector {
      display: flex;
      align-items: center;
    }

    .school-year-selector label {
      font-weight: 500;
      color: #4a5568;
      font-size: 14px;
      margin-right: 8px;
    }

    .school-year-selector select {
      padding: 8px 12px;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      background: white;
      font-size: 14px;
      min-width: 120px;
      transition: all 0.3s ease;
    }

    .school-year-selector select:focus {
      outline: none;
      border-color: #4CAF50;
      box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.1);
    }

    /* Enhanced User Info Styles */
    .user-info {
      display: flex;
      align-items: center;
      gap: 15px;
      padding: 5px 15px;
      background: rgba(76, 175, 80, 0.1);
      border-radius: 30px;
      transition: all 0.3s ease;
    }

    .user-info:hover {
      background: rgba(76, 175, 80, 0.15);
    }

    .user-info span {
      font-weight: 500;
      color: #2c3e50;
    }

    .user-avatar {
      width: 35px;
      height: 35px;
      border-radius: 50%;
      overflow: hidden;
      border: 2px solid #4CAF50;
      transition: all 0.3s ease;
    }

    .user-avatar:hover {
      transform: scale(1.1);
      box-shadow: 0 0 15px rgba(76, 175, 80, 0.3);
    }

    .user-avatar img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    
    @keyframes fadeOut {
      from { opacity: 1; transform: translateY(0); }
      to { opacity: 0; transform: translateY(10px); }
    }
    
    /* Records Header Styling */
    .records-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
      gap: 20px;
      position: relative;
      z-index: 1;
    }

    .records-header h3 {
      margin: 0;
      font-size: 1.5rem;
      color: #2c3e50;
      font-weight: 600;
      flex-shrink: 0;
    }
    
    /* Ensure school year dropdown appears above other elements */
    .school-year-wrapper {
      z-index: 1001;
    }
    
    /* Add/Action Button Styling */
    .records-header .btn-primary {
      transition: all 0.3s ease;
      font-weight: 500;
      font-size: 14px;
      height: 40px;
      min-width: 120px;
    }
    
    .records-header .btn-primary:hover {
      background: #45a049 !important;
      transform: translateY(-1px);
      box-shadow: 0 4px 8px rgba(0,0,0,0.15);
    }

    .search-input-wrapper {
      position: relative;
      flex: 1;
      max-width: 400px;
    }

    .search-icon {
      position: absolute;
      left: 12px;
      top: 50%;
      transform: translateY(-50%);
      color: #666;
    }

    .search-input {
      width: 100%;
      padding: 10px 10px 10px 35px;
      border: 1px solid #e0e0e0;
      border-radius: 8px;
      font-size: 0.9rem;
      transition: all 0.3s ease;
    }

    .search-input:focus {
      outline: none;
      border-color: #4CAF50;
      box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.1);
    }

    /* Enhanced Chart Container */
    .chart-container {
      background: white;
      border-radius: 12px;
      padding: 15px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.05);
      margin: 15px;
      overflow: hidden;
    }

    @media (min-width: 768px) {
      .chart-container {
        padding: 24px;
        margin: 0;
      }
    }

    .chart-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }

    .chart-actions {
      display: flex;
      gap: 10px;
    }

    .chart-filter-btn {
      padding: 8px 16px;
      border: 1px solid #e0e0e0;
      border-radius: 20px;
      background: white;
      color: #666;
      cursor: pointer;
      transition: all 0.3s ease;
    }

    .chart-filter-btn.active,
    .chart-filter-btn:hover {
      background: #4CAF50;
      color: white;
      border-color: #4CAF50;
    }

    .chart-wrapper {
      margin: 20px 0;
      position: relative;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
    }

    .chart-legend {
      display: flex;
      justify-content: center;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 20px;
      padding: 0 10px;
    }

    .legend-item {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .legend-color {
      width: 12px;
      height: 12px;
      border-radius: 3px;
    }

    .legend-label {
      font-size: 0.9rem;
      color: #666;
    }

    /* Quick Actions */
    .quick-actions-container {
      background: white;
      border-radius: 12px;
      padding: 24px;
      margin-top: 24px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.05);
    }

    .quick-actions-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 16px;
      margin-top: 16px;
    }

    .quick-action-btn {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 10px;
      padding: 20px;
      background: #f8f9fa;
      border: none;
      border-radius: 10px;
      cursor: pointer;
      transition: all 0.3s ease;
    }

    .quick-action-btn:hover {
      background: #4CAF50;
      color: white;
      transform: translateY(-5px);
    }

    .quick-action-btn i {
      font-size: 1.5rem;
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
  <!-- Sidebar Toggle Button -->
  <button class="sidebar-toggle" id="sidebar-toggle">
    <i class="fas fa-bars"></i>
  </button>

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
        <section id="dashboard-section">
          <!-- Floating Background Elements -->
          <div class="floating-element">
            <i class="fas fa-brain" style="font-size: 3rem; color: rgba(255,255,255,0.1);"></i>
          </div>
          <div class="floating-element">
            <i class="fas fa-graduation-cap" style="font-size: 2.5rem; color: rgba(255,255,255,0.1);"></i>
          </div>
          <div class="floating-element">
            <i class="fas fa-chart-line" style="font-size: 2rem; color: rgba(255,255,255,0.1);"></i>
          </div>
          
          <!-- Dashboard Content -->
          <div class="dashboard-content">
            <!-- Stats Container -->
            <div class="stats-container">
              <div class="stat-card">
                <div class="stat-icon">
                  <i class="fas fa-graduation-cap"></i>
                </div>
                <div class="stat-info">
                  <span>Total Students Enrolled</span>
                  <h2 id="total-students" class="highlight-value">0</h2>
                  <div class="progress-indicator">
                    <div class="progress-bar" style="width: 75%;"></div>
                  </div>
                </div>
              </div>
              <div class="stat-card">
                <div class="stat-icon">
                  <i class="fas fa-chart-line"></i>
                </div>
                <div class="stat-info">
                  <span>Average Accuracy</span>
                  <h2 id="avg-progress" class="highlight-value">0%</h2>
                  <div class="progress-indicator">
                    <div class="progress-bar" style="width: 60%;"></div>
                  </div>
                </div>
              </div>
              <!-- Newly added stat cards -->
              <div class="stat-card">
                <div class="stat-icon">
                  <i class="fas fa-gamepad"></i>
                </div>
                <div class="stat-info">
                  <span>Total Sessions</span>
                  <h2 id="total-sessions-value" class="highlight-value">0</h2>
                  <div class="progress-indicator">
                    <div class="progress-bar" id="total-sessions-bar" style="width: 0%;"></div>
                  </div>
                </div>
              </div>
              <div class="stat-card">
                <div class="stat-icon">
                  <i class="fas fa-stopwatch"></i>
                </div>
                <div class="stat-info">
                  <span>Average Time</span>
                  <h2 id="avg-time-value" class="highlight-value">0s</h2>
                  <div class="progress-indicator">
                    <div class="progress-bar" id="avg-time-bar" style="width: 0%;"></div>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Enhanced Chart Container -->
            <div class="chart-container">
              <h3>Student Progress Distribution</h3>
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

            <!-- Performance Trends Line Chart -->
            <div class="chart-container">
              <h3>Performance Trends</h3>
              <div class="chart-wrapper">
                <canvas id="performanceTrendsChart"></canvas>
              </div>
            </div>

            <!-- Accuracy and Completion Time Summary -->
             <div class="stats-container">
              <div class="chart-container">
                <h3>Accuracy</h3>
                <div class="chart-wrapper">
                  <canvas id="accuracySummaryChart"></canvas>
                </div>
              </div>
              <div class="chart-container">
                <h3>Completion Time</h3>
                <div class="chart-wrapper">
                  <canvas id="completionTimeSummaryChart"></canvas>
                </div>
              </div>
            </div>

            <!-- Game Performance -->
            <div class="chart-container">
              <h3>Game Performance</h3>
              <div id="game-performance-list"></div>
            </div>

            <!-- Key Insights -->
            <div class="chart-container">
              <h3>Key Insights</h3>
              <div class="stats-container">
                <div class="stat-card">
                  <div class="stat-icon"><i class="fas fa-trophy"></i></div>
                  <div class="stat-info">
                    <span>Best Streak</span>
                    <h2 id="best-streak-student">-</h2>
                    <div class="stat-trend"><span id="best-streak-count">0 sessions</span></div>
                  </div>
                </div>
                <div class="stat-card">
                  <div class="stat-icon"><i class="fas fa-star"></i></div>
                  <div class="stat-info">
                    <span>Top Game</span>
                    <h2 id="top-game-name">-</h2>
                    <div class="stat-trend"><span id="top-game-accuracy">0.0%</span></div>
                  </div>
                </div>
                <div class="stat-card">
                  <div class="stat-icon"><i class="fas fa-flag"></i></div>
                  <div class="stat-info">
                    <span>Needs Focus</span>
                    <h2 id="needs-focus-game">-</h2>
                    <div class="stat-trend"><span id="needs-focus-accuracy">0.0%</span></div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Student Overview -->
            <div class="chart-container">
              <h3>Student Overview</h3>
              <div id="student-overview-list"></div>
            </div>
          </div>
        </section>

        <!-- Students Section (CRUD) -->
        <section id="students-section" style="display: none;">
          <h2>Manage Students</h2>
                    <div class="students-content">
            <div class="table-container student-table-container">
              <div class="records-header">
                <h3 style="margin:0;">Student List</h3>
                <div style="display: flex; align-items: center; gap: 15px;">
                  <div class="search-input-wrapper">
                    <i class="fas fa-search search-icon"></i>
                    <input type="text" id="student-search" placeholder="Search by student name..." class="search-input">
                  </div>
                  <button id="open-student-form-btn" class="btn btn-primary" style="background: #4CAF50; color: white; border: none; padding: 10px 16px; border-radius: 8px; display: flex; align-items: center; gap: 8px; cursor: pointer; white-space: nowrap;">
                    <i class="fas fa-plus"></i>
                    Add Student
                  </button>
                </div>
              </div>
              <!-- Students Table -->
              <table id="students-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Age</th>
                    <th>Sex</th>
                    <th>Cognitive Needs</th>
                    <th>Contact Number</th>
                    <th>Guardian Name</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <!-- Template for JavaScript to use -->
                  <template id="student-row-template">
                    <tr class="student-card">
                      <td data-label="Name" class="student-card-header">
                        <span class="student-name"></span>
                      </td>
                      <td data-label="Age" class="student-info-row"></td>
                      <td data-label="Sex" class="student-info-row"></td>
                      <td data-label="Cognitive Needs" class="student-info-row"></td>
                      <td data-label="Contact Number" class="student-info-row"></td>
                      <td data-label="Guardian Name" class="student-info-row"></td>
                      <td data-label="Actions" class="student-actions">
                        <button class="btn-edit"><i class="fas fa-edit"></i></button>
                        <button class="btn-delete"><i class="fas fa-trash"></i></button>
                      </td>
                    </tr>
                  </template>
                  <!-- Data will be inserted here by JavaScript -->
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
        <label>Cognitive Needs:</label>
        <div class="cognitive-needs-container">
          <label class="cognitive-need-item">
            <input type="checkbox" class="cognitive-need" name="attention" value="true">
            <span>Attention</span>
          </label>
          <label class="cognitive-need-item">
            <input type="checkbox" class="cognitive-need" name="logic" value="true">
            <span>Logic</span>
          </label>
          <label class="cognitive-need-item">
            <input type="checkbox" class="cognitive-need" name="memory" value="true">
            <span>Memory</span>
          </label>
          <label class="cognitive-need-item">
            <input type="checkbox" class="cognitive-need" name="verbal" value="true">
            <span>Verbal</span>
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
  
  <!-- Records List -->
  <div class="records-content">
    <div class="table-container records-table-container">
      <div class="records-header">
        <h3>Student List</h3>
        <div class="search-input-wrapper">
          <i class="fas fa-search search-icon"></i>
          <input type="text" id="records-search" placeholder="Search by student name..." class="search-input">
        </div>
      </div>
      <table id="records-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Age</th>
            <th>Sex</th>
            <th>Cognitive Needs</th>
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
            <th>Game</th>
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

  <!-- Activities Stats Cards -->
      <div class="activities-stats" style="position: sticky; top: 70px; z-index: 5; background: #f5f7fa; padding-top: 10px;">
    <div class="stat-card">
      <div class="stat-icon">
        <i class="fas fa-gamepad"></i>
      </div>
      <div class="stat-info">
        <span>Total Sessions</span>
        <h2 id="total-game-sessions" class="highlight-value">0</h2>
      </div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">
        <i class="fas fa-brain"></i>
      </div>
      <div class="stat-info">
        <span>Most Played Challenge</span>
        <h2 id="most-played-challenge" class="highlight-value">-</h2>
      </div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">
        <i class="fas fa-bullseye"></i>
      </div>
      <div class="stat-info">
        <span>Average Accuracy</span>
        <h2 id="average-accuracy" class="highlight-value">0%</h2>
      </div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">
        <i class="fas fa-stopwatch"></i>
      </div>
      <div class="stat-info">
        <span>Average Time</span>
        <h2 id="average-time" class="highlight-value">0 sec</h2>
      </div>
    </div>
  </div>

  <!-- Activities Charts -->
      <div class="activities-charts" style="min-height: 360px;">
    <div class="chart-container">
      <h4>Challenge Distribution</h4>
      <canvas id="challenge-distribution-chart"></canvas>
    </div>
    <div class="chart-container">
      <h4>Weekly Activity</h4>
      <canvas id="weekly-activity-chart"></canvas>
    </div>
  </div>
  <!-- Activities Table Content -->
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
          <button id="open-flutter-app" class="btn-export" title="Open Flutter App">
            <i class="fas fa-external-link-alt"></i>
          </button>
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

            <!-- Add the Weekly Activity Chart -->
            <div class="analytics-chart-card">
              <h4>Weekly Activity</h4>
              <div class="chart-container">
                <canvas id="weekly-activity-chart"></canvas>
              </div>
            </div>
          </div>      <!-- Right Column - Performance and Stats -->
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
          <div class="admin-header" style="display:flex; align-items:center; justify-content: space-between; margin-bottom: 12px;">
            <h2 style="margin:0;">Admin Management</h2>
            <button id="add-admin-button" class="floating-add-button" style="position: static; width: 40px; height: 40px;">
              <i class="fas fa-plus"></i>
            </button>
          </div>
          <div id="admin-list-container">            <p>Total Admins: <span id="admin-count">0</span></p>            <ul class="admin-list" id="admin-list">              <!-- Admin list will be populated by JavaScript -->            </ul>            <script>              // Load admin list from Firebase              document.addEventListener('DOMContentLoaded', function() {                const db = firebase.firestore();                db.collection('growbrainadminAuth').get()                  .then((querySnapshot) => {                    const adminCount = querySnapshot.size;                    document.getElementById('admin-count').textContent = adminCount;                                        const adminList = document.getElementById('admin-list');                    adminList.innerHTML = '';                                        querySnapshot.forEach((doc) => {                      const adminData = doc.data();                      const username = adminData.username;                      const profilePic = adminData.profilePicture || 'img/default image.jpg';                                            const li = document.createElement('li');                      li.innerHTML = `                        <div class='admin-profile-wrap'>                          <img src='${profilePic}' alt='Profile Picture of ${username}' class='admin-profile-pic' />                        </div>                        <span class='admin-username'>${username}</span>                      `;                      adminList.appendChild(li);                    });                  })                  .catch((error) => {                    console.error("Error getting admin list:", error);                  });              });            </script>
          </div>
          
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
          <div class="teachers-content">
            <div class="table-container teacher-table-container">
              <div class="records-header">
                <h3 style="margin:0;">Teacher List</h3>
                <div style="display: flex; align-items: center; gap: 15px;">
                  <div class="search-input-wrapper">
                    <i class="fas fa-search search-icon"></i>
                    <input type="text" id="teacher-search" placeholder="Search by teacher name or email..." class="search-input">
                  </div>
                  <button id="open-teacher-form-btn" class="btn btn-primary" style="background: #4CAF50; color: white; border: none; padding: 10px 16px; border-radius: 8px; display: flex; align-items: center; gap: 8px; cursor: pointer; white-space: nowrap;">
                    <i class="fas fa-plus"></i>
                    Add Teacher
                  </button>
                </div>
              </div>
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
    
    // Function to show different sections (for quick actions)
    function showSection(sectionId) {
      // Hide all sections
      document.querySelectorAll('main section').forEach(section => {
        section.style.display = 'none';
      });
      
      // Show the selected section
      const targetSection = document.getElementById(sectionId);
      if (targetSection) {
        targetSection.style.display = 'block';
        
        // Update sidebar active state
        document.querySelectorAll('.sidebar-item').forEach(item => {
          item.classList.remove('active');
        });
        
        // Find and activate corresponding sidebar item
        const sidebarItem = document.querySelector(`[data-target="${sectionId}"]`);
        if (sidebarItem) {
          sidebarItem.classList.add('active');
        }
        
        // Load section-specific data
        if (sectionId === 'students-section') {
          if (typeof loadStudents === 'function') {
            loadStudents();
          }
        } else if (sectionId === 'activities-section') {
          if (typeof loadActivities === 'function') {
            loadActivities();
          }
        } else if (sectionId === 'records-section') {
          if (typeof loadStudentRecords === 'function') {
            loadStudentRecords();
          }
        }
      }
    }
    
    // Enhanced progress bar animation
    document.addEventListener('DOMContentLoaded', function() {
      // Animate progress bars when dashboard loads
      setTimeout(() => {
        const progressBars = document.querySelectorAll('.progress-bar');
        progressBars.forEach(bar => {
          const width = bar.style.width;
          bar.style.width = '0%';
          setTimeout(() => {
            bar.style.width = width;
          }, 100);
        });
      }, 1000);
    });
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