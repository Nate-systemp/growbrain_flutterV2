// teacher-switcher.js - Handles teacher email switching functionality

// Initialize teacher switcher functionality when the document is loaded
document.addEventListener('DOMContentLoaded', function() {
  // Initialize teacher switcher when Firebase is loaded
  if (typeof firebase !== 'undefined') {
    initTeacherSwitcher();
  } else {
    // Wait for Firebase to load
    window.addEventListener('firebase-loaded', initTeacherSwitcher);
  }
});

// Global variables
let currentTeacherId = null;
let teachersList = [];
let teacherSwitcherModal = null;

function initTeacherSwitcher() {
  createTeacherSwitcherUI();
  loadTeachersList();
  
  // Add event listeners
  document.addEventListener('click', handleTeacherSwitcherClicks);
}

function createTeacherSwitcherUI() {
  // Create teacher switcher button in header
  const header = document.querySelector('header .user-info');
  if (!header) return;
  
  // Create container for both teacher switcher and school year selector
  const headerControls = document.createElement('div');
  headerControls.className = 'header-controls';
  headerControls.style.cssText = 'display: flex; align-items: center; gap: 15px;';
  
  // Create teacher switcher button
  const teacherSwitcherBtn = document.createElement('div');
  teacherSwitcherBtn.id = 'teacher-switcher-btn';
  teacherSwitcherBtn.className = 'teacher-switcher-btn';
  teacherSwitcherBtn.innerHTML = `
    <i class="fas fa-user-graduate"></i>
    <span id="current-teacher-name">Select Teacher</span>
    <i class="fas fa-chevron-down"></i>
  `;
  
  // Create school year selector
  const schoolYearSelector = document.createElement('div');
  schoolYearSelector.className = 'school-year-wrapper';
  schoolYearSelector.innerHTML = `
    <div id="school-year-selector-btn" class="school-year-selector-btn">
      <i class="fas fa-calendar-alt"></i>
      <span id="current-school-year">All Years</span>
      <i class="fas fa-chevron-down"></i>
    </div>
    <div id="school-year-dropdown" class="school-year-dropdown">
      <!-- Options will be populated by JavaScript -->
    </div>
  `;
  
  // Add both controls to container
  headerControls.appendChild(teacherSwitcherBtn);
  headerControls.appendChild(schoolYearSelector);
  
  // Insert before user info
  header.insertBefore(headerControls, header.firstChild);
  
  // Initialize school year options
  initHeaderSchoolYear();
  
  // Create teacher switcher modal
  createTeacherSwitcherModal();
}

function createTeacherSwitcherModal() {
  // Create modal HTML
  const modalHTML = `
    <div id="teacher-switcher-modal" class="modal" style="display: none;">
      <div class="modal-content teacher-switcher-modal-content">
        <span id="teacher-switcher-close" class="close">&times;</span>
        <h3>Switch Teacher Account</h3>
        <div class="teacher-search-container">
          <div class="search-input-wrapper">
            <i class="fas fa-search search-icon"></i>
            <input type="text" id="teacher-switcher-search" placeholder="Search by teacher name or email..." class="search-input">
          </div>
        </div>
        <div class="teachers-list-container">
          <div id="teachers-list" class="teachers-list">
            <div class="loading-spinner"></div>
            <span>Loading teachers...</span>
          </div>
        </div>
        <div class="teacher-switcher-actions">
          <button id="clear-teacher-selection" class="btn-secondary">Clear Selection</button>
          <button id="refresh-teachers-list" class="btn-primary">
            <i class="fas fa-sync-alt"></i> Refresh
          </button>
        </div>
      </div>
    </div>
  `;
  
  // Add modal to body
  document.body.insertAdjacentHTML('beforeend', modalHTML);
  
  // Get modal reference
  teacherSwitcherModal = document.getElementById('teacher-switcher-modal');
}

function loadTeachersList() {
  const db = firebase.firestore();
  
  // Load teachers from the teachers collection
  db.collection('teachers').get()
    .then((querySnapshot) => {
      teachersList = [];
      
      querySnapshot.forEach((doc) => {
        const teacherData = doc.data();
        teachersList.push({
          id: doc.id,
          name: teacherData.name || teacherData.fullName || 'Unknown Teacher',
          email: teacherData.email || 'No email',
          createdAt: teacherData.createdAt,
          lastLogin: teacherData.lastLogin
        });
      });
      
      // Sort teachers by name
      teachersList.sort((a, b) => a.name.localeCompare(b.name));
      
      // Update UI
      renderTeachersList();
      
      console.log(`Loaded ${teachersList.length} teachers`);
    })
    .catch((error) => {
      console.error("Error loading teachers:", error);
      showTeachersError("Failed to load teachers. Please try again.");
    });
}

function renderTeachersList(searchTerm = '') {
  const teachersListContainer = document.getElementById('teachers-list');
  if (!teachersListContainer) return;
  
  // Filter teachers based on search term
  const filteredTeachers = teachersList.filter(teacher => 
    teacher.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    teacher.email.toLowerCase().includes(searchTerm.toLowerCase())
  );
  
  if (filteredTeachers.length === 0) {
    teachersListContainer.innerHTML = `
      <div class="no-teachers-message">
        <i class="fas fa-user-slash"></i>
        <p>No teachers found</p>
      </div>
    `;
    return;
  }
  
  // Create teachers list HTML
  const teachersHTML = filteredTeachers.map(teacher => {
    const isSelected = teacher.id === currentTeacherId;
    const lastLoginText = teacher.lastLogin ? 
      formatDate(teacher.lastLogin) : 'Never logged in';
    
    return `
      <div class="teacher-item ${isSelected ? 'selected' : ''}" data-teacher-id="${teacher.id}">
        <div class="teacher-info">
          <div class="teacher-avatar">
            <i class="fas fa-user-graduate"></i>
          </div>
          <div class="teacher-details">
            <h4 class="teacher-name">${escapeHtml(teacher.name)}</h4>
            <p class="teacher-email">${escapeHtml(teacher.email)}</p>
            <p class="teacher-last-login">Last login: ${lastLoginText}</p>
          </div>
        </div>
        <div class="teacher-actions">
          ${isSelected ? 
            '<i class="fas fa-check-circle selected-icon"></i>' : 
            '<button class="btn-select-teacher">Select</button>'
          }
        </div>
      </div>
    `;
  }).join('');
  
  teachersListContainer.innerHTML = teachersHTML;
}

function showTeachersError(message) {
  const teachersListContainer = document.getElementById('teachers-list');
  if (!teachersListContainer) return;
  
  teachersListContainer.innerHTML = `
    <div class="teachers-error-message">
      <i class="fas fa-exclamation-triangle"></i>
      <p>${message}</p>
    </div>
  `;
}

function selectTeacher(teacherId) {
  const teacher = teachersList.find(t => t.id === teacherId);
  if (!teacher) return;
  
  // Update current teacher
  currentTeacherId = teacherId;
  
  // Update UI
  const currentTeacherNameEl = document.getElementById('current-teacher-name');
  if (currentTeacherNameEl) {
    currentTeacherNameEl.textContent = teacher.name;
  }
  
  // Store in localStorage for persistence
  localStorage.setItem('selectedTeacherId', teacherId);
  localStorage.setItem('selectedTeacherName', teacher.name);
  
  // Close modal
  closeTeacherSwitcherModal();
  
  // Reload data for the selected teacher
  reloadDashboardData();
  
  // Show success message
  showNotification(`Switched to ${teacher.name}'s account`, 'success');
}

function clearTeacherSelection() {
  currentTeacherId = null;
  
  // Update UI
  const currentTeacherNameEl = document.getElementById('current-teacher-name');
  if (currentTeacherNameEl) {
    currentTeacherNameEl.textContent = 'Select Teacher';
  }
  
  // Clear localStorage
  localStorage.removeItem('selectedTeacherId');
  localStorage.removeItem('selectedTeacherName');
  
  // Close modal
  closeTeacherSwitcherModal();
  
  // Clear dashboard data
  clearDashboardData();
  
  // Show message
  showNotification('Teacher selection cleared', 'info');
}

function reloadDashboardData() {
  if (!currentTeacherId) {
    clearDashboardData();
    return;
  }
  
  // Reload students data
  if (typeof loadStudents === 'function') {
    loadStudents();
  }
  
  // Reload activities data
  if (typeof loadGameRecords === 'function') {
    loadGameRecords();
  }
  
  // Reload dashboard statistics
  if (typeof loadDashboardStats === 'function') {
    loadDashboardStats();
  }

  // Rebuild additional analytics
  if (typeof buildTrendsAndSummaries === 'function') {
    buildTrendsAndSummaries();
  }
  
  // Update any other sections that depend on teacher data
  updateAllSections();
}

function clearDashboardData() {
  // Clear students table
  const studentsTable = document.getElementById('students-table');
  if (studentsTable) {
    const tbody = studentsTable.querySelector('tbody');
    if (tbody) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" class="empty-message">
            <i class="fas fa-user-graduate"></i> Please select a teacher to view students
          </td>
        </tr>
      `;
    }
  }
  
  // Stop student snapshot when clearing teacher
  try {
    if (typeof window.studentsUnsubscribe === 'function') {
      window.studentsUnsubscribe();
      window.studentsUnsubscribe = null;
    }
  } catch (e) {}

  // Clear activities table
  const activitiesTable = document.getElementById('activities-table');
  if (activitiesTable) {
    const tbody = activitiesTable.querySelector('tbody');
    if (tbody) {
      tbody.innerHTML = `
        <tr>
          <td colspan="9" class="empty-message">
            <i class="fas fa-user-graduate"></i> Please select a teacher to view activities
          </td>
        </tr>
      `;
    }
  }
  
  // Clear records table
  const recordsTable = document.getElementById('records-table');
  if (recordsTable) {
    const tbody = recordsTable.querySelector('tbody');
    if (tbody) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" class="empty-message">
            <i class="fas fa-user-graduate"></i> Please select a teacher to view records
          </td>
        </tr>
      `;
    }
  }
  
  // Reset dashboard stats
  const totalStudents = document.getElementById('total-students');
  const avgProgress = document.getElementById('avg-progress');
  if (totalStudents) totalStudents.textContent = '0';
  if (avgProgress) avgProgress.textContent = '0%';
  
  // Clear activity stats
  const totalGameSessions = document.getElementById('total-game-sessions');
  const mostPlayedChallenge = document.getElementById('most-played-challenge');
  const averageAccuracy = document.getElementById('average-accuracy');
  const averageTime = document.getElementById('average-time');
  
  if (totalGameSessions) totalGameSessions.textContent = '0';
  if (mostPlayedChallenge) mostPlayedChallenge.textContent = '-';
  if (averageAccuracy) averageAccuracy.textContent = '0%';
  if (averageTime) averageTime.textContent = '0 sec';

  // Reset newly added widgets
  const tsVal = document.getElementById('total-sessions-value');
  if (tsVal) tsVal.textContent = '0';
  const atVal = document.getElementById('avg-time-value');
  if (atVal) atVal.textContent = '0s';
  const gp = document.getElementById('game-performance-list');
  if (gp) gp.innerHTML = '';
  const so = document.getElementById('student-overview-list');
  if (so) so.innerHTML = '';
  const ids = ['best-streak-student','best-streak-count','top-game-name','top-game-accuracy','needs-focus-game','needs-focus-accuracy'];
  ids.forEach(id => { const el = document.getElementById(id); if (el) el.textContent = id.includes('count') ? '0 sessions' : '-'; });
}

function updateAllSections() {
  // This function will be called to update all sections when teacher changes
  // It can be extended to update specific sections as needed
  
  // Update students section
  if (document.getElementById('students-section').style.display !== 'none') {
    // Students section is visible, reload data
    if (typeof loadStudents === 'function') {
      loadStudents();
    }
  }
  
  // Update activities section - always reload to keep data fresh
  if (typeof loadGameRecords === 'function') {
    loadGameRecords();
  }
  
  // Update records section
  if (document.getElementById('records-section').style.display !== 'none') {
    // Records section is visible, reload data
    if (typeof loadStudentRecords === 'function') {
      loadStudentRecords();
    }
  }
}

function openTeacherSwitcherModal() {
  if (teacherSwitcherModal) {
    teacherSwitcherModal.style.display = 'block';
    
    // Focus on search input
    const searchInput = document.getElementById('teacher-switcher-search');
    if (searchInput) {
      setTimeout(() => searchInput.focus(), 100);
    }
  }
}

function closeTeacherSwitcherModal() {
  if (teacherSwitcherModal) {
    teacherSwitcherModal.style.display = 'none';
    
    // Clear search
    const searchInput = document.getElementById('teacher-switcher-search');
    if (searchInput) {
      searchInput.value = '';
      renderTeachersList();
    }
  }
}

function handleTeacherSwitcherClicks(event) {
  // Handle teacher switcher button click
  if (event.target.closest('#teacher-switcher-btn')) {
    openTeacherSwitcherModal();
    return;
  }
  
  // Handle school year selector button click
  if (event.target.closest('#school-year-selector-btn')) {
    toggleSchoolYearDropdown();
    return;
  }
  
  // Handle school year option selection
  if (event.target.classList.contains('school-year-option')) {
    const selectedValue = event.target.dataset.value;
    updateSchoolYearSelection(selectedValue);
    
    // Close dropdown
    const dropdown = document.getElementById('school-year-dropdown');
    if (dropdown) {
      dropdown.classList.remove('show');
    }
    document.removeEventListener('click', closeSchoolYearDropdown);
    return;
  }
  
  // Handle close modal
  if (event.target.id === 'teacher-switcher-close') {
    closeTeacherSwitcherModal();
    return;
  }
  
  // Handle teacher selection
  if (event.target.classList.contains('btn-select-teacher')) {
    const teacherItem = event.target.closest('.teacher-item');
    const teacherId = teacherItem.dataset.teacherId;
    selectTeacher(teacherId);
    return;
  }
  
  // Handle clear selection
  if (event.target.id === 'clear-teacher-selection') {
    clearTeacherSelection();
    return;
  }
  
  // Handle refresh teachers list
  if (event.target.id === 'refresh-teachers-list' || event.target.closest('#refresh-teachers-list')) {
    loadTeachersList();
    return;
  }
  
  // Handle search input
  if (event.target.id === 'teacher-switcher-search') {
    event.target.addEventListener('input', function() {
      renderTeachersList(this.value);
    });
    return;
  }
  
  // Close modal when clicking outside
  if (event.target === teacherSwitcherModal) {
    closeTeacherSwitcherModal();
    return;
  }
}

// Load saved teacher selection on page load
function loadSavedTeacherSelection() {
  const savedTeacherId = localStorage.getItem('selectedTeacherId');
  const savedTeacherName = localStorage.getItem('selectedTeacherName');
  
  if (savedTeacherId && savedTeacherName) {
    currentTeacherId = savedTeacherId;
    
    const currentTeacherNameEl = document.getElementById('current-teacher-name');
    if (currentTeacherNameEl) {
      currentTeacherNameEl.textContent = savedTeacherName;
    }
    
    // Reload data for the saved teacher
    setTimeout(() => {
      reloadDashboardData();
    }, 1000); // Wait for other scripts to load
  }
}

// Utility functions
function formatDate(dateValue) {
  if (!dateValue) return 'N/A';
  
  try {
    let date;
    
    // Handle Firestore timestamp
    if (typeof dateValue === 'object' && dateValue.toDate) {
      date = dateValue.toDate();
    } else {
      date = new Date(dateValue);
    }
    
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch (e) {
    return 'Invalid date';
  }
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

function showNotification(message, type = 'info') {
  // Create notification element
  const notification = document.createElement('div');
  notification.className = `notification notification-${type}`;
  notification.innerHTML = `
    <div class="notification-content">
      <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
      <span>${message}</span>
    </div>
  `;
  
  // Add to body
  document.body.appendChild(notification);
  
  // Show notification
  setTimeout(() => {
    notification.classList.add('show');
  }, 100);
  
  // Remove notification after 3 seconds
  setTimeout(() => {
    notification.classList.remove('show');
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification);
      }
    }, 300);
  }, 3000);
}

// Export functions for use in other scripts
window.teacherSwitcher = {
  getCurrentTeacherId: () => currentTeacherId,
  selectTeacher: selectTeacher,
  clearSelection: clearTeacherSelection,
  reloadData: reloadDashboardData,
  getCurrentSchoolYear: getCurrentSchoolYear,
  isDateInSelectedYear: isDateInSelectedYear,
  reloadAllSections: reloadAllSectionsWithYearFilter,
  refreshSchoolYears: initHeaderSchoolYear,
  testSchoolYears: () => window.testSchoolYears(),
  testDashboardValues: () => window.testDashboardValues()
};

function initHeaderSchoolYear() {
  const yearDropdown = document.getElementById('school-year-dropdown');
  if (!yearDropdown) return;
  
  // Show loading state
  yearDropdown.innerHTML = '<div class="school-year-option">Loading years...</div>';
  
  // Fetch available years from Firebase student data
  fetchAvailableSchoolYears().then(years => {
    // Create dropdown options
    let optionsHTML = '<div class="school-year-option" data-value="">All Years</div>';
    years.forEach(year => {
      optionsHTML += `<div class="school-year-option" data-value="${year}">${year}</div>`;
    });
    
    yearDropdown.innerHTML = optionsHTML;
    
    // Set current year as default
    const currentYear = new Date().getFullYear();
    const currentSchoolYear = `${currentYear}-${currentYear + 1}`;
    
    // Check if current school year exists in available years, otherwise use saved or default
    const savedYear = localStorage.getItem('selectedSchoolYear');
    let defaultYear = '';
    
    if (years.includes(currentSchoolYear)) {
      defaultYear = currentSchoolYear;
    } else if (savedYear && years.includes(savedYear)) {
      defaultYear = savedYear;
    } else if (years.length > 0) {
      defaultYear = years[years.length - 1]; // Use most recent year if current year not available
    }
    
    updateSchoolYearSelection(defaultYear);
  }).catch(error => {
    console.error('Error loading school years:', error);
    yearDropdown.innerHTML = '<div class="school-year-option" data-value="">All Years</div>';
  });
}

function fetchAvailableSchoolYears() {
  return new Promise((resolve, reject) => {
    const db = firebase.firestore();
    const yearsSet = new Set();
    
    console.log('Fetching available school years from Firebase...');
    
    // First try to get students from teachers collection (current structure)
    db.collectionGroup('students').get()
      .then((querySnapshot) => {
        console.log('Found', querySnapshot.size, 'students total');
        
        querySnapshot.forEach((doc) => {
          const studentData = doc.data();
          console.log('Student data:', doc.id, studentData);
          
          if (studentData.createdAt) {
            try {
              let date;
              // Handle Firestore timestamp
              if (typeof studentData.createdAt === 'object' && studentData.createdAt.toDate) {
                date = studentData.createdAt.toDate();
                console.log('Firestore timestamp converted:', date);
              } else if (typeof studentData.createdAt === 'string') {
                date = new Date(studentData.createdAt);
                console.log('String date converted:', date);
              } else if (studentData.createdAt instanceof Date) {
                date = studentData.createdAt;
                console.log('Already a Date object:', date);
              } else {
                console.warn('Unknown createdAt format:', typeof studentData.createdAt, studentData.createdAt);
                return; // Skip this iteration
              }
              
              if (isNaN(date.getTime())) {
                console.warn('Invalid date created:', date, 'from', studentData.createdAt);
                return; // Skip this iteration
              }
              
              const year = date.getFullYear();
              console.log('Extracted year:', year, 'from date:', date);
              
              // School year runs from current year to next year (e.g., 2024-2025)
              const schoolYear = `${year}-${year + 1}`;
              yearsSet.add(schoolYear);
              console.log('Added school year:', schoolYear);
            } catch (e) {
              console.warn('Error parsing date for student', doc.id, ':', e, studentData.createdAt);
            }
          } else {
            console.log('Student', doc.id, 'has no createdAt field');
          }
        });
        
        // Convert set to sorted array (newest first)
        const availableYears = Array.from(yearsSet).sort((a, b) => {
          const yearA = parseInt(a.split('-')[0]);
          const yearB = parseInt(b.split('-')[0]);
          return yearB - yearA;
        });
        
        console.log('Final available school years:', availableYears);
        resolve(availableYears);
      })
      .catch((error) => {
        console.error("Error fetching students for school years:", error);
        
        // Fallback: try the old students collection structure
        console.log('Trying fallback: direct students collection...');
        db.collection('students').get()
          .then((fallbackSnapshot) => {
            console.log('Fallback found', fallbackSnapshot.size, 'students');
            
            fallbackSnapshot.forEach((doc) => {
              const studentData = doc.data();
              if (studentData.createdAt) {
                try {
                  let date;
                  if (typeof studentData.createdAt === 'object' && studentData.createdAt.toDate) {
                    date = studentData.createdAt.toDate();
                  } else {
                    date = new Date(studentData.createdAt);
                  }
                  
                  const year = date.getFullYear();
                  const schoolYear = `${year}-${year + 1}`;
                  yearsSet.add(schoolYear);
                } catch (e) {
                  console.warn('Fallback date parsing error:', e);
                }
              }
            });
            
            const availableYears = Array.from(yearsSet).sort((a, b) => {
              const yearA = parseInt(a.split('-')[0]);
              const yearB = parseInt(b.split('-')[0]);
              return yearB - yearA;
            });
            
            console.log('Fallback available school years:', availableYears);
            resolve(availableYears);
          })
          .catch((fallbackError) => {
            console.error('Fallback also failed:', fallbackError);
            reject(fallbackError);
          });
      });
  });
}

function updateSchoolYearSelection(selectedValue) {
  const currentSchoolYearEl = document.getElementById('current-school-year');
  const options = document.querySelectorAll('.school-year-option');
  
  // Update button text
  if (currentSchoolYearEl) {
    if (selectedValue === '' || !selectedValue) {
      currentSchoolYearEl.textContent = 'All Years';
    } else {
      currentSchoolYearEl.textContent = selectedValue;
    }
  }
  
  // Update selected option
  options.forEach(option => {
    option.classList.remove('selected');
    if (option.dataset.value === selectedValue) {
      option.classList.add('selected');
    }
  });
  
  // Store selected year
  if (selectedValue) {
    localStorage.setItem('selectedSchoolYear', selectedValue);
  } else {
    localStorage.removeItem('selectedSchoolYear');
  }
  
  console.log('School year changed to:', selectedValue || 'All Years');
  
  // Reload all data with the new school year filter
  reloadAllSectionsWithYearFilter();
}

function reloadAllSectionsWithYearFilter() {
  console.log('Reloading all sections with year filter...');
  
  // Clear any cached chart data first
  if (typeof window.progressChart !== 'undefined' && window.progressChart) {
    window.progressChart.data.datasets.forEach(dataset => {
      dataset.data = [0];
    });
    window.progressChart.update();
  }
  
  // Destroy and recreate activity charts to avoid stale data
  if (typeof window.challengeDistributionChart !== 'undefined' && window.challengeDistributionChart) {
    window.challengeDistributionChart.destroy();
    window.challengeDistributionChart = null;
  }
  
  if (typeof window.weeklyActivityChart !== 'undefined' && window.weeklyActivityChart) {
    window.weeklyActivityChart.destroy();
    window.weeklyActivityChart = null;
  }
  
  // Reset dashboard stats to prevent showing stale data
  const totalStudentsEl = document.getElementById('total-students');
  const avgProgressEl = document.getElementById('avg-progress');
  if (totalStudentsEl) totalStudentsEl.textContent = '0';
  if (avgProgressEl) avgProgressEl.textContent = '0%';
  
  // Clear Key Insights data
  const topGameNameEl = document.getElementById('top-game-name');
  const topGameAccEl = document.getElementById('top-game-accuracy');
  const needsFocusGameEl = document.getElementById('needs-focus-game');
  const needsFocusAccEl = document.getElementById('needs-focus-accuracy');
  const bestStreakNameEl = document.getElementById('best-streak-student');
  const bestStreakCountEl = document.getElementById('best-streak-count');
  
  if (topGameNameEl) topGameNameEl.textContent = '-';
  if (topGameAccEl) topGameAccEl.textContent = '0%';
  if (needsFocusGameEl) needsFocusGameEl.textContent = '-';
  if (needsFocusAccEl) needsFocusAccEl.textContent = '0%';
  if (bestStreakNameEl) bestStreakNameEl.textContent = '-';
  if (bestStreakCountEl) bestStreakCountEl.textContent = '0 sessions';
  
  // Clear Game Performance list
  const gamePerformanceList = document.getElementById('game-performance-list');
  if (gamePerformanceList) gamePerformanceList.innerHTML = '<p>Loading...</p>';
  
  // Clear Student Overview list
  const studentOverviewList = document.getElementById('student-overview-list');
  if (studentOverviewList) studentOverviewList.innerHTML = '<p>Loading...</p>';
  
  // Clear progress indicators
  const improvingCount = document.getElementById('improving-count');
  const needsAttentionCount = document.getElementById('needs-attention-count');
  const strugglingCount = document.getElementById('struggling-count');
  
  if (improvingCount) improvingCount.textContent = '0';
  if (needsAttentionCount) needsAttentionCount.textContent = '0';
  if (strugglingCount) strugglingCount.textContent = '0';
  
  // Clear additional stats
  const totalSessionsValue = document.getElementById('total-sessions-value');
  const avgTimeValue = document.getElementById('avg-time-value');
  
  if (totalSessionsValue) totalSessionsValue.textContent = '0';
  if (avgTimeValue) avgTimeValue.textContent = '0s';
  
  // Reload dashboard statistics
  if (typeof loadDashboardStats === 'function') {
    loadDashboardStats();
  }
  
  // Reload students data
  if (typeof loadStudents === 'function') {
    loadStudents();
  }
  
  // Reload activities/game records data
  if (typeof loadGameRecords === 'function') {
    loadGameRecords();
  }
  
  // Reload records data
  if (typeof loadStudentRecords === 'function') {
    loadStudentRecords();
  }
  
  // Update additional analytics (this should be called after all data is loaded)
  setTimeout(() => {
    if (typeof buildTrendsAndSummaries === 'function') {
      buildTrendsAndSummaries();
    }
  }, 1000);
}

// Function to get current selected school year
function getCurrentSchoolYear() {
  return localStorage.getItem('selectedSchoolYear') || '';
}

// Function to check if a date falls within the selected school year
function isDateInSelectedYear(date) {
  const selectedYear = getCurrentSchoolYear();
  if (!selectedYear) {
    console.log('No school year selected, showing all data');
    return true; // Show all if no year selected
  }
  
  try {
    let dateObj;
    // Handle Firestore timestamp
    if (typeof date === 'object' && date.toDate) {
      dateObj = date.toDate();
    } else if (date) {
      dateObj = new Date(date);
    } else {
      console.log('No date provided, including in results');
      return true; // Include if no date
    }
    
    if (isNaN(dateObj.getTime())) {
      console.warn('Invalid date:', date, 'including in results');
      return true;
    }
    
    const year = dateObj.getFullYear();
    const selectedYearStart = parseInt(selectedYear.split('-')[0]);
    const selectedYearEnd = parseInt(selectedYear.split('-')[1]);
    
    // Check if the date falls within the school year range
    const isInRange = year >= selectedYearStart && year <= selectedYearEnd;
    
    console.log(`Date check: ${dateObj.toISOString()} (${year}) vs ${selectedYear} = ${isInRange}`);
    
    return isInRange;
  } catch (e) {
    console.warn('Error checking date against school year:', e, 'including in results');
    return true;
  }
}

function toggleSchoolYearDropdown() {
  const dropdown = document.getElementById('school-year-dropdown');
  if (!dropdown) return;
  
  dropdown.classList.toggle('show');
  
  // Close dropdown when clicking outside
  if (dropdown.classList.contains('show')) {
    setTimeout(() => {
      document.addEventListener('click', closeSchoolYearDropdown);
    }, 0);
  }
}

function closeSchoolYearDropdown(event) {
  const dropdown = document.getElementById('school-year-dropdown');
  const button = document.getElementById('school-year-selector-btn');
  
  if (dropdown && !dropdown.contains(event.target) && !button.contains(event.target)) {
    dropdown.classList.remove('show');
    document.removeEventListener('click', closeSchoolYearDropdown);
  }
}

// Test function to manually check Firebase data - call this from browser console
window.testSchoolYears = function() {
  console.log('=== MANUAL SCHOOL YEAR TEST ===');
  const db = firebase.firestore();
  
  // Test collectionGroup query
  db.collectionGroup('students').get()
    .then((snapshot) => {
      console.log('CollectionGroup students found:', snapshot.size);
      snapshot.forEach((doc) => {
        const data = doc.data();
        console.log('Student:', doc.id, {
          fullName: data.fullName || data.name,
          createdAt: data.createdAt,
          createdAtType: typeof data.createdAt
        });
      });
    })
    .catch(err => console.error('CollectionGroup error:', err));
    
  // Test direct students collection
  db.collection('students').get()
    .then((snapshot) => {
      console.log('Direct students collection found:', snapshot.size);
      snapshot.forEach((doc) => {
        const data = doc.data();
        console.log('Direct student:', doc.id, {
          fullName: data.fullName || data.name,
          createdAt: data.createdAt,
          createdAtType: typeof data.createdAt
        });
      });
    })
    .catch(err => console.error('Direct collection error:', err));
    
  // Force refresh school years
  fetchAvailableSchoolYears().then(years => {
    console.log('Fetched years result:', years);
  }).catch(err => {
    console.error('Fetch years error:', err);
  });
};

// Test function to check current dashboard values
window.testDashboardValues = function() {
  console.log('=== CURRENT DASHBOARD VALUES ===');
  
  const elements = [
    'total-students', 'avg-progress', 
    'top-game-name', 'top-game-accuracy',
    'needs-focus-game', 'needs-focus-accuracy',
    'best-streak-student', 'best-streak-count',
    'improving-count', 'needs-attention-count', 'struggling-count',
    'total-sessions-value', 'avg-time-value'
  ];
  
  elements.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      console.log(`${id}: "${el.textContent}"`);
    } else {
      console.log(`${id}: NOT FOUND`);
    }
  });
  
  const currentYear = getCurrentSchoolYear();
  console.log('Current selected school year:', currentYear || 'All Years');
};

// Load saved selection when page loads
document.addEventListener('DOMContentLoaded', function() {
  setTimeout(loadSavedTeacherSelection, 500);
});