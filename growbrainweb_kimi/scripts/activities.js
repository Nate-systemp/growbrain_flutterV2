// activities.js - Handles activities section functionality

// Initialize activities functionality when the document is loaded
document.addEventListener('DOMContentLoaded', function() {
  // Initialize activities functionality when Firebase is loaded
  if (typeof firebase !== 'undefined') {
    initActivitiesSection();
  } else {
    // Wait for Firebase to load
    window.addEventListener('firebase-loaded', initActivitiesSection);
  }
});

function initActivitiesSection() {
  // Elements
  const activitiesTable = document.getElementById('activities-table');
  const activitiesSearch = document.getElementById('activities-search');
  const challengeFilter = document.getElementById('challenge-filter');
  const gameFilter = document.getElementById('game-filter');
  const dateRangeFilter = document.getElementById('date-range');
  const refreshButton = document.getElementById('refresh-activities');
  const exportButton = document.getElementById('export-activities');
  const paginationPrev = document.getElementById('pagination-prev');
  const paginationNext = document.getElementById('pagination-next');
  const paginationCurrent = document.getElementById('pagination-current');
  const paginationShowing = document.getElementById('pagination-showing');
  const paginationTotal = document.getElementById('pagination-total');
  const activityDetailsModal = document.getElementById('activity-details-modal');
  const activityDetailsClose = document.getElementById('activity-details-close');
  
  // Dashboard elements
  const totalGameSessions = document.getElementById('total-game-sessions');
  const mostPlayedChallenge = document.getElementById('most-played-challenge');
  const averageAccuracy = document.getElementById('average-accuracy');
  const averageTime = document.getElementById('average-time');
  
  // Charts
  let challengeDistributionChart;
  let weeklyActivityChart;
  
  // State variables
  let allRecords = [];
  let filteredRecords = [];
  let currentPage = 1;
  const recordsPerPage = 10;
  let gameTypes = new Set();
  
  // Master list of games from the Flutter project for accurate Game Type filtering
  const MASTER_GAMES = [
    'Who Moved?',
    'Light Tap',
    'Find Me',
    'Sound Match',
    'Rhyme Time',
    'Picture Words',
    'Match Cards',
    'Fruit Shuffle',
    'Object Hunt',
    'Puzzle',
    'TicTacToe',
    'Riddle Game'
  ];
  
  // Initialize
  // Pre-populate game filter with master list so it's available even before records load
  populateGameFilter();
  loadGameRecords();
  
  // Event listeners
  if (refreshButton) refreshButton.addEventListener('click', loadGameRecords);
  if (exportButton) exportButton.addEventListener('click', exportToCSV);
  if (activitiesSearch) activitiesSearch.addEventListener('input', filterRecords);
  if (challengeFilter) challengeFilter.addEventListener('change', filterRecords);
  if (gameFilter) gameFilter.addEventListener('change', filterRecords);
  if (dateRangeFilter) dateRangeFilter.addEventListener('change', filterRecords);
  if (paginationPrev) paginationPrev.addEventListener('click', () => navigatePage(-1));
  if (paginationNext) paginationNext.addEventListener('click', () => navigatePage(1));
  if (activityDetailsClose) activityDetailsClose.addEventListener('click', closeActivityDetailsModal);
  
  // Close modal on outside click
  window.addEventListener('click', function(event) {
    if (event.target === activityDetailsModal) {
      closeActivityDetailsModal();
    }
  });
  
  // Functions
  function loadGameRecords() {
    console.log('Starting loadGameRecords...');
    
    // Show loading state
    if (!activitiesTable) {
      console.error('Activities table not found');
      return;
    }
    
    const tbody = activitiesTable.querySelector('tbody');
    if (!tbody) {
      console.error('Table body not found');
      return;
    }
    
    tbody.innerHTML = `
      <tr class="loading-row">
        <td colspan="9"><div class="loading-spinner"></div> Loading records...</td>
      </tr>
    `;
    
    // Reset state
    allRecords = [];
    filteredRecords = [];
    gameTypes = new Set();
    currentPage = 1;
    
    // Check if teacher is selected
    const currentTeacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
    console.log('Current Teacher ID:', currentTeacherId);
    
    if (!currentTeacherId) {
      console.log('No teacher selected');
      tbody.innerHTML = `
        <tr>
          <td colspan="9" class="empty-message">
            <i class="fas fa-user-graduate"></i> Please select a teacher using the dropdown at the top to view activities
          </td>
        </tr>
      `;
      updateDashboardStats(0, '', 0, 0);
      // Ensure game filter still shows all master games
      populateGameFilter();
      return;
    }
    
    // Get data from Firestore for the selected teacher
    const db = firebase.firestore();
    
    // Load all students for this teacher first
    console.log('Loading students for teacher:', currentTeacherId);
    db.collection('teachers').doc(currentTeacherId).collection('students').get()
      .then((studentsSnapshot) => {
        console.log('Found students:', studentsSnapshot.size);
        if (studentsSnapshot.empty) {
          console.log('No students found for this teacher');
          showNoRecordsMessage();
          return;
        }
        
        const promises = [];
        
        // For each student, get their records
        studentsSnapshot.forEach((studentDoc) => {
          const studentData = studentDoc.data();
          
          // Check if student was created in the selected school year
          const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
          if (isDateInSelectedYear && !isDateInSelectedYear(studentData.createdAt)) {
            return; // Skip this student if not in selected year
          }
          
          const studentName = studentData.fullName || studentData.name || 'Unknown Student';
          
          const recordsPromise = db.collection('teachers')
            .doc(currentTeacherId)
            .collection('students')
            .doc(studentDoc.id)
            .collection('records')
            .get()
            .then((recordsSnapshot) => {
              recordsSnapshot.forEach((recordDoc) => {
                const data = recordDoc.data();
                  const record = {
                  id: recordDoc.id,
                  studentName: studentName,
                    challengeFocus: normalizeChallengeFocus(data.challengeFocus || 'N/A'),
                  gameKey: data.game || data.gameKey || 'Unknown Game',
                  accuracy: data.accuracy || 0,
                  completionTime: data.completionTime || 0,
                  difficultyText: data.difficulty || data.difficultyText || 'N/A',
                  date: data.date || 'Unknown',
                  lastPlayed: data.lastPlayed || data.game || 'Unknown',
                  errors: data.errors || 0,
                  recordId: recordDoc.id,
                  teacherId: currentTeacherId,
                  studentId: studentDoc.id
                };
                
                // Add to records array
                allRecords.push(record);
                
                // Track unique game types
                if (record.gameKey) {
                  gameTypes.add(record.gameKey);
                }
              });
            });
          
          promises.push(recordsPromise);
        });
        
        // Wait for all records to be loaded
        return Promise.all(promises);
      })
      .then(() => {
        if (allRecords.length === 0) {
          showNoRecordsMessage();
          return;
        }
        
        // Populate game filter
        populateGameFilter();
        
        // Update statistics
        updateStatistics();
        
        // Create/update charts
        createCharts();
        
        // Filter and display records
        filterRecords();
      })
      .catch((error) => {
        console.error("Error getting game records:", error);
        if (tbody) {
          tbody.innerHTML = `
            <tr>
              <td colspan="9" class="error-message">
                <i class="fas fa-exclamation-circle"></i> Error loading records. Please try again.
              </td>
            </tr>
          `;
        }
      });
  }

  // Expose reload to other modules (e.g., teacher-switcher)
  try {
    window.loadGameRecords = loadGameRecords;
  } catch (e) {
    console.warn('Unable to expose loadGameRecords globally:', e);
  }
  
  function showNoRecordsMessage() {
    if (!activitiesTable) return;
    
    const tbody = activitiesTable.querySelector('tbody');
    if (!tbody) return;
    
    tbody.innerHTML = `
      <tr>
        <td colspan="9" class="empty-message">
          <i class="fas fa-info-circle"></i> No game records found.
        </td>
      </tr>
    `;
    
    // Update counters
    updatePaginationInfo(0, 0);
    updateDashboardStats(0, '', 0, 0);
    // Keep game filter populated from master list
    populateGameFilter();
  }
  
  function populateGameFilter() {
    if (!gameFilter) return;
    
    // Clear existing options except the first one
    while (gameFilter.options.length > 1) {
      gameFilter.remove(1);
    }
    
    // Merge master list with any additional game keys found from records
    const combinedGames = Array.from(new Set([...
      MASTER_GAMES,
      ...Array.from(gameTypes)
    ])).sort((a, b) => a.localeCompare(b));

    // Add combined game types as options using display names directly
    combinedGames.forEach(game => {
      const option = document.createElement('option');
      option.value = game;
      option.textContent = game;
      gameFilter.appendChild(option);
    });
  }
  
  function filterRecords() {
    const searchTerm = activitiesSearch ? activitiesSearch.value.toLowerCase() : '';
    const challengeType = challengeFilter ? challengeFilter.value : '';
    const gameType = gameFilter ? gameFilter.value : '';
    const dateRange = dateRangeFilter ? dateRangeFilter.value : 'all';
    
    // Filter records based on criteria
    filteredRecords = allRecords.filter(record => {
      // Search term filter
      const matchesSearch = !searchTerm || 
        record.studentName.toLowerCase().includes(searchTerm);
      
      // Challenge focus filter
      const matchesChallenge = !challengeType || 
        record.challengeFocus.includes(challengeType);
      
      // Game type filter
      const matchesGame = !gameType || 
        record.gameKey === gameType;
      
      // Date range filter
      let matchesDate = true;
      if (dateRange !== 'all') {
        const recordDate = new Date(record.date);
        const today = new Date();
        
        if (dateRange === 'today') {
          matchesDate = isSameDay(recordDate, today);
        } else if (dateRange === 'week') {
          matchesDate = isThisWeek(recordDate, today);
        } else if (dateRange === 'month') {
          matchesDate = isSameMonth(recordDate, today);
        }
      }
      
      return matchesSearch && matchesChallenge && matchesGame && matchesDate;
    });
    
    // Sort by date (newest first)
    filteredRecords.sort((a, b) => {
      return new Date(b.date) - new Date(a.date);
    });
    
    // Update pagination and render
    currentPage = 1;
    updatePaginationInfo(filteredRecords.length, Math.ceil(filteredRecords.length / recordsPerPage));
    renderRecordsTable();
  }
  
  function renderRecordsTable() {
    if (!activitiesTable) return;
    
    const tbody = activitiesTable.querySelector('tbody');
    if (!tbody) return;
    
    tbody.innerHTML = '';
    
    if (filteredRecords.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="9" class="empty-message">
            <i class="fas fa-search"></i> No matching records found.
          </td>
        </tr>
      `;
      return;
    }
    
    // Calculate pagination
    const startIndex = (currentPage - 1) * recordsPerPage;
    const endIndex = Math.min(startIndex + recordsPerPage, filteredRecords.length);
    
    // Group records by student name
    const groupedRecords = {};
    filteredRecords.forEach(record => {
      if (!groupedRecords[record.studentName]) {
        groupedRecords[record.studentName] = [];
      }
      groupedRecords[record.studentName].push(record);
    });
    
    // Get student names for current page
    const studentNames = Object.keys(groupedRecords);
    const pageStudentNames = studentNames.slice(startIndex, endIndex);
    
    // Update pagination info - now based on unique students
    updatePaginationInfo(studentNames.length, Math.ceil(studentNames.length / recordsPerPage));
    
    // Create rows for each student
    pageStudentNames.forEach(studentName => {
      const studentRecords = groupedRecords[studentName];
      
      // Main student row
      const row = document.createElement('tr');
      row.className = 'student-main-row';
      row.dataset.studentName = studentName;
      
      // Calculate student statistics
      const totalAccuracy = studentRecords.reduce((sum, record) => sum + record.accuracy, 0);
      const avgAccuracy = studentRecords.length > 0 ? (totalAccuracy / studentRecords.length).toFixed(2) : '0.00';
      
      const totalTime = studentRecords.reduce((sum, record) => sum + record.completionTime, 0);
      const avgTime = studentRecords.length > 0 ? (totalTime / studentRecords.length).toFixed(2) : '0.00';
      
      // Get unique challenge focuses
      const challenges = new Set();
      studentRecords.forEach(record => {
        if (record.challengeFocus) {
          record.challengeFocus.split(',').forEach(challenge => {
            challenges.add(challenge.trim());
          });
        }
      });
      
      // Get most recent play date
      const sortedDates = [...studentRecords].sort((a, b) => {
        return new Date(b.date) - new Date(a.date);
      });
      const lastPlayedDate = sortedDates[0].date;
      const formattedLastPlayed = formatDate(lastPlayedDate);
      
      // Create the main student row
      row.innerHTML = `
        <td>
          <div class="student-name-cell">
            <span class="student-toggle" data-expanded="false">
              <i class="fas fa-chevron-right expand-icon"></i>
              ${escapeHtml(studentName)}
            </span>
            <span class="student-record-count">(${studentRecords.length} records)</span>
          </div>
        </td>
        <td>${Array.from(challenges).join(', ')}</td>
        <td>Multiple Games</td>
        <td>${avgAccuracy}%</td>
        <td>${avgTime} sec</td>
        <td>-</td>
        <td>Multiple Dates</td>
        <td>${formattedLastPlayed}</td>
        <td>
          <div class="action-buttons">
            <button class="btn-view btn-expand-records" title="View All Records">
              <i class="fas fa-list-alt"></i>
            </button>
          </div>
        </td>
      `;
      
      tbody.appendChild(row);
      
      // Create hidden container for individual records
      const detailsContainer = document.createElement('tr');
      detailsContainer.className = 'student-records-container';
      detailsContainer.style.display = 'none';
      
      const detailsCell = document.createElement('td');
      detailsCell.colSpan = 9;
      detailsCell.innerHTML = `
        <div class="student-records-details">
          <table class="nested-records-table">
            <thead>
              <tr>
                <th>Game</th>
                <th>Challenge Focus</th>
                <th>Accuracy</th>
                <th>Completion Time</th>
                <th>Difficulty</th>
                <th>Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              ${studentRecords.map(record => {
                // Format game name
                let gameName = formatGameDisplayName(record.gameKey);
                
                // Format date and time - handle Firestore timestamp or string
                let formattedDate = 'N/A';
                if (record.date) {
                  if (typeof record.date === 'object' && record.date.toDate) {
                    formattedDate = formatDate(record.date.toDate());
                  } else {
                    formattedDate = formatDate(record.date);
                  }
                }
                
                const formattedTime = formatTime(record.completionTime);
                
                return `
                  <tr>
                    <td>${escapeHtml(gameName)}</td>
                    <td>${escapeHtml(record.challengeFocus)}</td>
                    <td>${record.accuracy}%</td>
                    <td>${formattedTime}</td>
                    <td>${record.difficultyText}</td>
                    <td>${formattedDate}</td>
                    <td>
                      <button class="btn-view-detail" data-record-id="${record.id}" title="View Details">
                        <i class="fas fa-file-alt"></i>
                      </button>
                    </td>
                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      `;
      
      detailsContainer.appendChild(detailsCell);
      tbody.appendChild(detailsContainer);
    });
    
    // Add event listeners for expanding/collapsing student records
    const toggleButtons = tbody.querySelectorAll('.student-toggle, .btn-expand-records');
    toggleButtons.forEach(button => {
      button.addEventListener('click', function(e) {
        const studentRow = e.target.closest('.student-main-row');
        const studentName = studentRow.dataset.studentName;
        const detailsRow = studentRow.nextElementSibling;
        const isExpanded = detailsRow.style.display !== 'none';
        
        // Toggle expansion
        detailsRow.style.display = isExpanded ? 'none' : 'table-row';
        
        // Update icon
        const icon = studentRow.querySelector('.expand-icon');
        icon.className = isExpanded ? 'fas fa-chevron-right expand-icon' : 'fas fa-chevron-down expand-icon';
        
        // Update expanded state
        studentRow.querySelector('.student-toggle').dataset.expanded = !isExpanded;
      });
    });
    
    // Add event listeners to all view detail buttons
    const viewDetailButtons = tbody.querySelectorAll('.btn-view-detail');
    viewDetailButtons.forEach(button => {
      button.addEventListener('click', () => {
        const recordId = button.getAttribute('data-record-id');
        openActivityDetailsModal(recordId);
      });
    });
  }
  
  function updatePaginationInfo(totalRecords, totalPages) {
    if (paginationShowing) paginationShowing.textContent = totalRecords > 0 ? 
      `${Math.min((currentPage - 1) * recordsPerPage + 1, totalRecords)} - ${Math.min(currentPage * recordsPerPage, totalRecords)}` : 
      '0';
    
    if (paginationTotal) paginationTotal.textContent = totalRecords;
    if (paginationCurrent) paginationCurrent.textContent = currentPage;
    
    // Update navigation buttons
    if (paginationPrev) paginationPrev.disabled = currentPage <= 1;
    if (paginationNext) paginationNext.disabled = currentPage >= totalPages;
  }
  
  function navigatePage(direction) {
    currentPage += direction;
    renderRecordsTable();
  }
  
  function updateStatistics() {
    if (allRecords.length === 0) {
      updateDashboardStats(0, '', 0, 0);
      return;
    }
    
    // Calculate total sessions
    const totalSessions = allRecords.length;
    
    // Find most common challenge focus
    const challengeCounts = {};
    let maxCount = 0;
    let mostCommonChallenge = '';
    
    allRecords.forEach(record => {
      const challenges = record.challengeFocus.split(',').map(c => c.trim());
      
      challenges.forEach(challenge => {
        if (challenge) {
          challengeCounts[challenge] = (challengeCounts[challenge] || 0) + 1;
          if (challengeCounts[challenge] > maxCount) {
            maxCount = challengeCounts[challenge];
            mostCommonChallenge = challenge;
          }
        }
      });
    });
    
    // Calculate average accuracy
    const totalAccuracy = allRecords.reduce((sum, record) => sum + record.accuracy, 0);
    const avgAccuracy = totalSessions > 0 ? totalAccuracy / totalSessions : 0;
    
    // Calculate average completion time
    const totalTime = allRecords.reduce((sum, record) => sum + record.completionTime, 0);
    const avgTime = totalSessions > 0 ? totalTime / totalSessions : 0;
    
    // Update dashboard stats
    updateDashboardStats(totalSessions, mostCommonChallenge, avgAccuracy, avgTime);
  }
  
  function updateDashboardStats(totalSessions, mostCommonChallenge, avgAccuracy, avgTime) {
    if (totalGameSessions) totalGameSessions.textContent = totalSessions;
    if (mostPlayedChallenge) mostPlayedChallenge.textContent = mostCommonChallenge || '-';
    if (averageAccuracy) averageAccuracy.textContent = avgAccuracy.toFixed(2) + '%';
    if (averageTime) averageTime.textContent = avgTime.toFixed(2) + ' sec';
    
    // Add counting animation
    animateCounters();
  }
  
  function createCharts() {
    createChallengeDistributionChart();
    createWeeklyActivityChart();
  }
  
  function createChallengeDistributionChart() {
    const canvas = document.getElementById('challenge-distribution-chart');
    if (!canvas) return;
    
    // Calculate challenge distribution
    const challengeCounts = {};
    
    allRecords.forEach(record => {
      const challenges = record.challengeFocus.split(',').map(c => c.trim());
      
      challenges.forEach(challenge => {
        if (challenge) {
          challengeCounts[challenge] = (challengeCounts[challenge] || 0) + 1;
        }
      });
    });
    
    // Prepare data for chart
    const labels = Object.keys(challengeCounts);
    const data = Object.values(challengeCounts);
    const total = data.reduce((a, b) => a + b, 0);
    
    // Create soft gradients for segments
    const ctx = canvas.getContext('2d');
    const createGradient = (from, to) => {
      const g = ctx.createLinearGradient(0, 0, 0, canvas.height);
      g.addColorStop(0, from);
      g.addColorStop(1, to);
      return g;
    };
    const backgroundColors = [
      createGradient('rgba(76,175,80,0.95)', 'rgba(76,175,80,0.65)'),   // Attention
      createGradient('rgba(33,150,243,0.95)', 'rgba(33,150,243,0.65)'), // Memory
      createGradient('rgba(255,193,7,0.95)', 'rgba(255,193,7,0.65)'),   // Verbal
      createGradient('rgba(156,39,176,0.95)', 'rgba(156,39,176,0.65)')  // Logic
    ];
    
    // Destroy previous chart if exists
    if (window.challengeDistributionChart) {
      window.challengeDistributionChart.destroy();
    }
    
    // Plugin: center text inside doughnut
    const centerText = {
      id: 'centerText',
      afterDraw(chart) {
        const { ctx, chartArea: { width, height } } = chart;
        ctx.save();
        const x = chart.getDatasetMeta(0).data[0]?.x || width / 2;
        const y = chart.getDatasetMeta(0).data[0]?.y || height / 2;
        ctx.fillStyle = '#2c3e50';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.font = '600 18px Inter, Arial, sans-serif';
        ctx.fillText(`${total} Sessions`, x, y - 6);
        // Most common label
        let maxIdx = 0;
        for (let i = 1; i < data.length; i++) if (data[i] > data[maxIdx]) maxIdx = i;
        const topLabel = labels[maxIdx] || '';
        ctx.font = '500 12px Inter, Arial, sans-serif';
        ctx.fillStyle = '#6b7280';
        ctx.fillText(topLabel, x, y + 12);
        ctx.restore();
      }
    };

    // Plugin: draw percentage labels on arcs
    const arcLabels = {
      id: 'arcLabels',
      afterDatasetsDraw(chart) {
        const { ctx } = chart;
        const meta = chart.getDatasetMeta(0);
        ctx.save();
        ctx.font = '600 11px Inter, Arial, sans-serif';
        ctx.fillStyle = '#334155';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        meta.data.forEach((el, i) => {
          if (!data[i] || total === 0) return;
          const p = Math.round((data[i] / total) * 100);
          // Skip tiny slices to avoid clutter
          if (p < 8) return;
          const midAngle = (el.startAngle + el.endAngle) / 2;
          const r = Math.max(el.outerRadius - 12, (el.innerRadius + el.outerRadius) / 2 + 6);
          const x = el.x + Math.cos(midAngle) * r;
          const y = el.y + Math.sin(midAngle) * r;
          // Draw slight text shadow for readability
          ctx.strokeStyle = 'rgba(255,255,255,0.8)';
          ctx.lineWidth = 3;
          ctx.strokeText(`${p}%`, x, y);
          ctx.fillText(`${p}%`, x, y);
        });
        ctx.restore();
      }
    };

    // Create chart
    window.challengeDistributionChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          data: data,
          backgroundColor: backgroundColors.slice(0, labels.length),
          borderWidth: 2,
          borderColor: '#ffffff',
          hoverOffset: 6,
          spacing: 2,
          borderRadius: 8,
          radius: '85%'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'right',
            labels: {
              boxWidth: 12,
              padding: 15,
              generateLabels(chart) {
                const ds = chart.data.datasets[0];
                return chart.data.labels.map((l, i) => {
                  const v = ds.data[i] || 0;
                  const perc = total ? Math.round((v / total) * 100) : 0;
                  return {
                    text: `${l}  ${v} (${perc}%)`,
                    fillStyle: ds.backgroundColor[i],
                    strokeStyle: '#fff',
                    lineWidth: 1,
                  };
                });
              }
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const label = context.label || '';
                const value = context.parsed || 0;
                const percentage = total ? Math.round((value / total) * 100) : 0;
                return `${label}: ${value} (${percentage}%)`;
              }
            }
          }
        },
        cutout: '68%',
        animation: {
          duration: 800,
          animateRotate: true,
          animateScale: true,
        }
      }
    , plugins: [centerText, arcLabels]
    });
  }
  
  function createWeeklyActivityChart() {
    const canvas = document.getElementById('weekly-activity-chart');
    if (!canvas) return;
    
    // Get last 7 days
    const dates = [];
    const counts = [];
    
    for (let i = 6; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      date.setHours(0, 0, 0, 0);
      
      const dateStr = formatShortDate(date);
      const count = allRecords.filter(record => {
        const recordDate = new Date(record.date);
        return isSameDay(recordDate, date);
      }).length;
      
      dates.push(dateStr);
      counts.push(count);
    }
    
    // Destroy previous chart if exists
    if (window.weeklyActivityChart) {
      window.weeklyActivityChart.destroy();
    }
    
    // Create chart
    const ctx = canvas.getContext('2d');
    window.weeklyActivityChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: dates,
        datasets: [{
          label: 'Game Sessions',
          data: counts,
          backgroundColor: 'rgba(76, 175, 80, 0.7)',
          borderColor: 'rgba(76, 175, 80, 1)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0
            }
          }
        },
        plugins: {
          legend: {
            display: false
          }
        }
      }
    });
  }
  
  function openActivityDetailsModal(recordId) {
    const record = allRecords.find(r => r.id === recordId);
    if (!record || !activityDetailsModal) return;
    
    // Format game name
    let gameName = formatGameDisplayName(record.gameKey);
    
    // Update modal content
    document.getElementById('detail-student-name').textContent = record.studentName;
    document.getElementById('detail-game-name').textContent = gameName;
    document.getElementById('detail-challenge-focus').textContent = record.challengeFocus;
    document.getElementById('detail-difficulty').textContent = record.difficultyText;
    document.getElementById('detail-accuracy').textContent = record.accuracy + '%';
    document.getElementById('detail-completion-time').textContent = formatTime(record.completionTime);
    document.getElementById('detail-errors').textContent = record.errors || '0';
    document.getElementById('detail-date').textContent = formatDate(record.date);
    document.getElementById('detail-last-played').textContent = record.lastPlayed;
    document.getElementById('detail-record-id').textContent = record.recordId || record.id;
    
    // Show modal
    activityDetailsModal.style.display = 'block';
  }
  
  function closeActivityDetailsModal() {
    if (activityDetailsModal) {
      activityDetailsModal.style.display = 'none';
    }
  }
  
  function exportToCSV() {
    if (filteredRecords.length === 0) {
      alert('No records to export.');
      return;
    }
    
    // Create and export PDF using jsPDF
    try {
      const { jsPDF } = window.jspdf;
      const doc = new jsPDF('landscape');
      
      // Set document properties
      doc.setProperties({
        title: 'GrowBrain Game Records',
        subject: 'Student Game Activity Report',
        author: 'GrowBrain Admin Dashboard',
        keywords: 'game records, student activity',
        creator: 'GrowBrain App'
      });
      
      // Add title and date
      doc.setFontSize(18);
      doc.setTextColor(76, 175, 80); // Green color
      doc.text('GrowBrain Game Activity Records', 14, 22);
      
      doc.setFontSize(11);
      doc.setTextColor(100, 100, 100); // Gray color
      doc.text(`Generated on: ${new Date().toLocaleString()}`, 14, 30);
      
      // Add filtering information
      const challengeFilterValue = challengeFilter ? challengeFilter.options[challengeFilter.selectedIndex].text : 'All Challenges';
      const gameFilterValue = gameFilter ? gameFilter.options[gameFilter.selectedIndex].text : 'All Games';
      const dateRangeValue = dateRangeFilter ? dateRangeFilter.options[dateRangeFilter.selectedIndex].text : 'All Time';
      
      doc.setFontSize(10);
      doc.text(`Filters: ${challengeFilterValue} | ${gameFilterValue} | ${dateRangeValue}`, 14, 38);
      
      // Add statistics
      doc.setFontSize(12);
      doc.setTextColor(60, 60, 60);
      doc.text(`Total Records: ${filteredRecords.length}`, 14, 46);
      
      // Calculate averages
      if (filteredRecords.length > 0) {
        const totalAccuracy = filteredRecords.reduce((sum, record) => sum + record.accuracy, 0);
        const avgAccuracy = (totalAccuracy / filteredRecords.length).toFixed(2);
        
        const totalTime = filteredRecords.reduce((sum, record) => sum + record.completionTime, 0);
        const avgTime = (totalTime / filteredRecords.length).toFixed(2);
        
        doc.text(`Average Accuracy: ${avgAccuracy}% | Average Completion Time: ${avgTime} sec`, 14, 54);
      }
      
      // Add table
      const headers = [
        'Student Name',
        'Challenge Focus',
        'Game',
        'Accuracy (%)',
        'Time (sec)',
        'Difficulty',
        'Date',
        'Last Played'
      ];
      
      // Convert records to table data
      const tableData = filteredRecords.map(record => {
        const gameName = formatGameDisplayName(record.gameKey);
        
        // Format date properly for PDF
        let formattedDate = 'N/A';
        if (record.date) {
          if (typeof record.date === 'object' && record.date.toDate) {
            formattedDate = formatDate(record.date.toDate());
          } else {
            formattedDate = formatDate(record.date);
          }
        }
        
        return [
          record.studentName,
          record.challengeFocus,
          gameName,
          record.accuracy + '%',
          record.completionTime.toFixed(2),
          record.difficultyText,
          formattedDate,
          record.lastPlayed
        ];
      });
      
      // Define custom styles
      const styles = {
        headStyles: {
          fillColor: [76, 175, 80],
          textColor: 255,
          fontStyle: 'bold'
        },
        alternateRowStyles: {
          fillColor: [240, 240, 240]
        },
        columnStyles: {
          0: { cellWidth: 'auto' },  // Student Name
          1: { cellWidth: 'auto' },  // Challenge Focus
          2: { cellWidth: 'auto' },  // Game
          3: { cellWidth: 20, halign: 'center' },  // Accuracy
          4: { cellWidth: 25, halign: 'center' },  // Time
          5: { cellWidth: 20, halign: 'center' },  // Difficulty
          6: { cellWidth: 'auto' },  // Date
          7: { cellWidth: 'auto' }   // Last Played
        },
        margin: { top: 62 }
      };
      
      // Create the table
      doc.autoTable({
        head: [headers],
        body: tableData,
        ...styles,
        didDrawPage: function(data) {
          // Add page number
          doc.setFontSize(10);
          doc.text(`Page ${doc.internal.getCurrentPageInfo().pageNumber}`, data.settings.margin.left, doc.internal.pageSize.height - 10);
        }
      });
      
      // Add footer
      const totalPages = doc.internal.getNumberOfPages();
      for (let i = 1; i <= totalPages; i++) {
        doc.setPage(i);
        doc.setFontSize(8);
        doc.setTextColor(150, 150, 150);
        doc.text('GrowBrain Learning Dashboard - Confidential', doc.internal.pageSize.width / 2, doc.internal.pageSize.height - 5, { align: 'center' });
      }
      
      // Save the PDF
      doc.save(`GrowBrain_GameRecords_${formatDateForFilename(new Date())}.pdf`);
    } catch (error) {
      console.error("Error creating PDF:", error);
      alert('Error creating PDF. Please check the console for details.');
    }
  }
  
  // Helper functions
  function animateCounters() {
    const counters = document.querySelectorAll('.highlight-value');
    
    counters.forEach(counter => {
      // Skip if already animated
      if (counter.classList.contains('counted')) return;
      
      counter.classList.add('counting', 'counted');
    });
  }
  
  function isSameDay(date1, date2) {
    return date1.getFullYear() === date2.getFullYear() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getDate() === date2.getDate();
  }
  
  function isThisWeek(date, today) {
    const dayOfWeek = today.getDay();
    const firstDayOfWeek = new Date(today);
    firstDayOfWeek.setDate(today.getDate() - dayOfWeek);
    firstDayOfWeek.setHours(0, 0, 0, 0);
    
    const lastDayOfWeek = new Date(firstDayOfWeek);
    lastDayOfWeek.setDate(firstDayOfWeek.getDate() + 6);
    lastDayOfWeek.setHours(23, 59, 59, 999);
    
    return date >= firstDayOfWeek && date <= lastDayOfWeek;
  }
  
  function isSameMonth(date, today) {
    return date.getFullYear() === today.getFullYear() &&
           date.getMonth() === today.getMonth();
  }
  
  function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    
    try {
      let date;
      
      // Check if it's a Firestore timestamp
      if (typeof dateStr === 'object' && dateStr.toDate) {
        date = dateStr.toDate();
      } 
      // Otherwise treat as a string or Date
      else {
        date = new Date(dateStr);
      }
      
      return date.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (e) {
      console.error('Date formatting error:', e);
      return String(dateStr);
    }
  }
  
  function formatShortDate(date) {
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }
  
  function formatTime(seconds) {
    if (seconds === undefined || seconds === null) return 'N/A';
    return seconds.toFixed(2) + ' sec';
  }
  
  function formatDateForFilename(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  
  function escapeHtml(text) {
    if (!text) return '';
    return text
      .toString()
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
  
  function formatGameDisplayName(key) {
    if (!key) return '';
    if (typeof key !== 'string') return String(key);
    if (key.includes(' ')) return key.trim();
    return key.replace(/([A-Z])/g, ' $1').trim();
  }

  // Map legacy or synonym challenge names to our canonical categories
  function normalizeChallengeFocus(value) {
    if (!value) return '';
    const v = String(value).trim();
    // Per current requirement, treat any Auditory variants as Logic
    if (/auditory/i.test(v)) return 'Logic';
    // Keep canonical categories as-is
    if (/^memory$/i.test(v)) return 'Memory';
    if (/^attention$/i.test(v)) return 'Attention';
    if (/^logic$/i.test(v)) return 'Logic';
    if (/^verbal$/i.test(v)) return 'Verbal';
    return v;
  }
}