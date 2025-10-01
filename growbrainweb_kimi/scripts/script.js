// ------------------------------
// Firebase and Firestore Initialization
// ------------------------------
const db = firebase.firestore();
// Active listeners we want to clean up when reloading sections
let studentsUnsubscribe = null;

// Utility: normalize various truthy representations from Firestore (boolean or string)
function isTrueLike(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value === 1;
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase();
    return v === 'true' || v === '1' || v === 'yes';
  }
  return false;
}

// ------------------------------
// DOMContentLoaded Initialization
// ------------------------------
document.addEventListener('DOMContentLoaded', function () {
  loadDashboardData();
  initChart();
  loadStudents();
  initStudentForm();
  initDarkMode();
  initProfileModal();
  initTeacherForm();      // Only one initTeacherForm is used now.
  loadTeacherEmails();
  loadTeacherCount();
  // NEW: Load student progress for chart and update dashboard counts
  loadStudentProgress();
  initAdminModal(); // Ensure admin modal is initialized
  initSidebar(); // Initialize sidebar navigation
  // Initialize extra analytics charts
  initPerformanceTrendsChart();
  initAccuracySummaryChart();
  initCompletionTimeSummaryChart();
  
    // Initialize activities 
  if (typeof initActivitiesSection === 'function') {
    initActivitiesSection();
  }

  // Event listener: Open student modal with smooth scroll & animation
  const openBtn = document.getElementById('open-student-form-btn');
  if (openBtn) {
    openBtn.addEventListener('click', function () {
      openStudentModal();
    });
  }
  
  // Event listener: Close the student modal when clicking the close (×) button
  const modalClose = document.getElementById('student-modal-close');
  if (modalClose) {
    modalClose.addEventListener('click', function () {
      document.getElementById('student-modal').style.display = 'none';
      clearStudentForm();
    });
  }
  
  // Close the student modal when clicking outside the modal content
  window.addEventListener('click', function(e) {
    const modal = document.getElementById('student-modal');
    if (e.target === modal) {
      modal.style.display = 'none';
      clearStudentForm();
    }
  });
  
  // Initialize detailed analytics modal functionality
  initStudentAnalyticsModal();
  
  // Student search functionality
  const studentSearchInput = document.getElementById('student-search');
  const studentSearchBtn = document.getElementById('student-search-btn');
  if (studentSearchBtn) {
    studentSearchBtn.addEventListener('click', function () {
      filterStudents(studentSearchInput.value.toLowerCase());
    });
  }
  // Optionally, filter as you type
  if (studentSearchInput) {
    studentSearchInput.addEventListener('input', function () {
      filterStudents(this.value.toLowerCase());
    });
  }

  // Activities search functionality
  const activitiesSearchInput = document.getElementById('activities-search');
  if (activitiesSearchInput) {
    activitiesSearchInput.addEventListener('input', function() {
      filterActivities(this.value.toLowerCase());
    });
  }

  // Build summaries and trend charts on first load too
  buildTrendsAndSummaries();

  // Create Account Modal logic (for teachers)
  const createAccountBtn = document.getElementById('create-account-btn');
  const createAccountModal = document.getElementById('create-account-modal');
  const createAccountModalClose = document.getElementById('create-account-modal-close');
  const createAccountCancel = document.getElementById('create-account-cancel');
  const createAccountForm = document.getElementById('create-account-form');

  // Open the Create Account Modal
  if (createAccountBtn) {
    createAccountBtn.addEventListener('click', function () {
      createAccountModal.style.display = 'block';
    });
  }

  // Close the Create Account Modal
  if (createAccountModalClose) {
    createAccountModalClose.addEventListener('click', function () {
      createAccountModal.style.display = 'none';
    });
  }

  if (createAccountCancel) {
    createAccountCancel.addEventListener('click', function () {
      createAccountModal.style.display = 'none';
    });
  }

  // Handle Create Account Form Submission
  if (createAccountForm) {
    createAccountForm.addEventListener('submit', async function (e) {
      e.preventDefault();

      const name = document.getElementById('create-name').value.trim();
      const email = document.getElementById('create-email').value.trim();
      const password = document.getElementById('create-password').value;
      const pin = document.getElementById('create-pin').value.trim();

      if (!name || !email || !password || !pin) {
        showResultMessage('Please fill in all fields', true);
        return;
      }

      if (pin.length !== 6 || isNaN(pin)) {
        showResultMessage('PIN must be a 6-digit number.', true);
        return;
      }

      const result = await createTeacherAccount(name, email, password, pin);
      showResultMessage(result.message, !result.success);
      
      if (result.success) {
        createAccountModal.style.display = 'none';
        createAccountForm.reset();
        loadTeacherEmails(); // Refresh the list
      }
    });
  }
  
  // Teacher Modal open/close logic will be handled by initTeacherForm()
  
  // Event listeners for teacher and student search fields
  const teacherSearchInput = document.getElementById('teacher-search');
  if (teacherSearchInput) {
    teacherSearchInput.addEventListener('input', function() {
      filterTeachers(this.value);
    });
  }

  // Records search functionality
  const recordsSearch = document.getElementById('records-search');
  if (recordsSearch) {
    recordsSearch.addEventListener('input', function() {
      filterRecords(this.value.toLowerCase());
    });
  }
});

// ------------------------------
// Dashboard Functions (Stats & Chart)
// ------------------------------
function loadDashboardData() {
  document.getElementById('total-students').textContent = '0';
  document.getElementById('avg-progress').textContent = '0%';
  document.getElementById('improving-count').textContent = '0';
  document.getElementById('needs-attention-count').textContent = '0';
  document.getElementById('struggling-count').textContent = '0';
  const ts = document.getElementById('total-sessions-value');
  if (ts) ts.textContent = '0';
  const at = document.getElementById('avg-time-value');
  if (at) at.textContent = '0s';
}

function initChart() {
  const ctx = document.getElementById('progressChart').getContext('2d');
  const defaultData = {
    labels: ['Progress'],
    datasets: [
      {
        label: 'Improving',
        data: [0],
        backgroundColor: 'rgba(76, 175, 80, 0.7)', // Green
        borderColor: 'rgba(76, 175, 80, 1)',
        borderWidth: 1
      },
      {
        label: 'Needs Attention',
        data: [0],
        backgroundColor: 'rgba(255, 193, 7, 0.7)', // Amber
        borderColor: 'rgba(255, 193, 7, 1)',
        borderWidth: 1
      },
      {
        label: 'Struggling',
        data: [0],
        backgroundColor: 'rgba(244, 67, 54, 0.7)', // Red
        borderColor: 'rgba(244, 67, 54, 1)',
        borderWidth: 1
      }
    ]
  };

  window.progressChart = new Chart(ctx, {
    type: 'bar',
    data: defaultData,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          title: {
            display: true,
            text: 'Number of Students'
          },
          ticks: {
            precision: 0
          }
        },
        x: {
          title: {
            display: true,
            text: ''
          }
        }
      }
    }
  });
}

function updateChart(improving, needsAttention, struggling) {
  if (window.progressChart) {
    window.progressChart.data.datasets[0].data = [improving];
    window.progressChart.data.datasets[1].data = [needsAttention];
    window.progressChart.data.datasets[2].data = [struggling];
    window.progressChart.update();
  }
}

// ------------------------------
// Additional analytics charts
// ------------------------------
let performanceTrendsChart, accuracySummaryChart, completionTimeSummaryChart;

function initPerformanceTrendsChart() {
  const el = document.getElementById('performanceTrendsChart');
  if (!el) return;
  const ctx = el.getContext('2d');
  performanceTrendsChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: [],
      datasets: [{
        label: 'Avg Accuracy %',
        data: [],
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59,130,246,0.15)',
        fill: true,
        tension: 0.3,
        pointRadius: 3
      }]
    },
    options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true, max: 100 } } }
  });
}

function initAccuracySummaryChart() {
  const el = document.getElementById('accuracySummaryChart');
  if (!el) return;
  const ctx = el.getContext('2d');
  accuracySummaryChart = new Chart(ctx, {
    type: 'bar',
    data: { labels: ['hello'], datasets: [{ label: 'Accuracy', data: [0], backgroundColor: '#22c55e' }] },
    options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true, max: 100 } } }
  });
}

function initCompletionTimeSummaryChart() {
  const el = document.getElementById('completionTimeSummaryChart');
  if (!el) return;
  const ctx = el.getContext('2d');
  completionTimeSummaryChart = new Chart(ctx, {
    type: 'bar',
    data: { labels: ['hello'], datasets: [{ label: 'Time (s)', data: [0], backgroundColor: '#8b5cf6' }] },
    options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: true } } }
  });
}

// ------------------------------
// Load Student Progress Data from Firestore and Classify
// ------------------------------
function loadStudentProgress() {
  const teacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
  let improvingCount = 0, needsAttentionCount = 0, strugglingCount = 0;
  let globalTotalAccuracy = 0;
  let globalRecordCount = 0;
  let totalSessions = 0;
  let totalTimeSeconds = 0;

  const setDashboardNumbers = () => {
    const globalAvgAccuracy = (globalRecordCount > 0)
      ? parseFloat((globalTotalAccuracy / globalRecordCount).toFixed(1))
      : 0;
    const avgEl = document.getElementById('avg-progress');
    if (avgEl) avgEl.textContent = globalAvgAccuracy + '%';
    updateChart(improvingCount, needsAttentionCount, strugglingCount);
    const imp = document.getElementById('improving-count');
    const need = document.getElementById('needs-attention-count');
    const strg = document.getElementById('struggling-count');
    if (imp) imp.textContent = improvingCount;
    if (need) need.textContent = needsAttentionCount;
    if (strg) strg.textContent = strugglingCount;
    // keep total-students in sync even if reload happens later in flow
    const totalEl = document.getElementById('total-students');
    if (totalEl && !totalEl.textContent) {
      totalEl.textContent = '0';
    }
    const ts = document.getElementById('total-sessions-value');
    if (ts) ts.textContent = String(totalSessions);
    const at = document.getElementById('avg-time-value');
    if (at) at.textContent = (totalSessions > 0 ? (totalTimeSeconds / totalSessions).toFixed(1) : '0') + 's';
  };

  // If no teacher selected, reset
  if (!teacherId) {
    const totalEl = document.getElementById('total-students');
    if (totalEl) totalEl.textContent = '0';
    improvingCount = needsAttentionCount = strugglingCount = 0;
    globalTotalAccuracy = globalRecordCount = 0;
    setDashboardNumbers();
    return;
  }

  db.collection('teachers').doc(teacherId).collection('students').get()
    .then((studentsSnap) => {
      // Deduplicate students by normalized name to avoid double counting (e.g., id and fullName docs)
      const nameToDoc = new Map();
      const uniqueDocs = [];
      studentsSnap.forEach((doc) => {
        const data = doc.data() || {};
        const key = String((data.fullName || data.name || doc.id) || '')
          .trim()
          .toLowerCase();
        if (!nameToDoc.has(key)) {
          nameToDoc.set(key, doc);
          uniqueDocs.push(doc);
        }
      });

      // Filter students by selected school year before counting
      const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
      const filteredDocs = isDateInSelectedYear ? 
        uniqueDocs.filter(doc => isDateInSelectedYear((doc.data() || {}).createdAt)) : 
        uniqueDocs;

      const totalEl = document.getElementById('total-students');
      if (totalEl) totalEl.textContent = String(filteredDocs.length);

      const perStudentPromises = [];

      uniqueDocs.forEach((studentDoc) => {
        const sid = studentDoc.id;
        const studentData = studentDoc.data() || {};
        
        // Check if student was created in the selected school year
        const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
        if (isDateInSelectedYear && !isDateInSelectedYear(studentData.createdAt)) {
          return; // Skip this student if not in selected year
        }
        
        const getRecords = db.collection('teachers')
          .doc(teacherId)
          .collection('students')
          .doc(sid)
          .collection('records')
          .get()
          .then((recSnap) => {
            if (!recSnap.empty) return recSnap;
            // Legacy fallbacks: sessions under root by id or by name
            return db.collection('students').doc(sid).collection('sessions').get()
              .then((legacy) => {
                if (!legacy.empty) return legacy;
                const name = (studentData.fullName || studentData.name || sid);
                return db.collection('students').doc(name).collection('sessions').get();
              });
          })
          .then((snap) => {
            let sum = 0, cnt = 0;
            snap.forEach((d) => {
              const r = d.data();
              const acc = parseFloat(r.accuracy);
              if (!isNaN(acc)) {
                sum += acc;
                cnt += 1;
              }
              const t = parseFloat(r.completionTime || r.timeSeconds || r.time || r.durationSeconds);
              if (!isNaN(t)) totalTimeSeconds += t;
            });
            const avg = cnt > 0 ? (sum / cnt) : 0;
            if (cnt > 0) {
              globalTotalAccuracy += sum;
              globalRecordCount += cnt;
              totalSessions += cnt;
              if (avg >= 85) improvingCount++;
              else if (avg >= 60) needsAttentionCount++;
              else strugglingCount++;
            }
          })
          .catch((err) => console.warn('Progress fallback error for', sid, err));

        perStudentPromises.push(getRecords);
      });

      return Promise.all(perStudentPromises).then(setDashboardNumbers);
    })
    .catch((error) => {
      console.error('Error loading dashboard progress:', error);
      // Still reset numbers to avoid stale UI
      const totalEl = document.getElementById('total-students');
      if (totalEl) totalEl.textContent = '0';
      improvingCount = needsAttentionCount = strugglingCount = 0;
      globalTotalAccuracy = globalRecordCount = 0;
      setDashboardNumbers();
    });
}

// Wrapper used by teacher-switcher
function loadDashboardStats() {
  loadStudentProgress();
  // Also refresh charts that depend on session times/accuracy trend
  buildTrendsAndSummaries();
}

// Build trend line and summaries (top game, needs focus, game performance list, student overview)
function buildTrendsAndSummaries() {
  const teacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
  if (!teacherId) return;
  const trendDateTo = new Map();
  const gameToStats = new Map();
  const studentToAgg = new Map();

  db.collection('teachers').doc(teacherId).collection('students').get().then((studentsSnap) => {
    const promises = [];
    studentsSnap.forEach((studentDoc) => {
      const sid = studentDoc.id;
      const studentData = studentDoc.data() || {};
      
      // Check if student was created in the selected school year
      const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
      if (isDateInSelectedYear && !isDateInSelectedYear(studentData.createdAt)) {
        return; // Skip this student if not in selected year
      }
      
      const name = (studentData.fullName || studentData.name || sid);
      const p = db.collection('teachers').doc(teacherId).collection('students').doc(sid).collection('records').get()
        .then((snap) => {
          snap.forEach((d) => {
            const r = d.data() || {};
            // Flutter uses 'accuracy' (number) 0-100; accept string fallback
            const accRaw = r.accuracy;
            const acc = typeof accRaw === 'number' ? accRaw : parseFloat(accRaw);
            if (isNaN(acc)) {
              // Treat missing/invalid as 0
              acc = 0;
            }
            const timeS = Number(parseFloat(r.timeSeconds || r.time || r.durationSeconds).toFixed(2)) || 0;
            const game = r.game || r.gameName || 'Unknown';
            const dateKey = (r.date && r.date.toDate) ? r.date.toDate().toISOString().slice(5,10) : (typeof r.date === 'string' ? r.date.slice(5,10) : '');

            // trend by date
            if (!trendDateTo.has(dateKey)) trendDateTo.set(dateKey, { sum: 0, cnt: 0 });
            const td = trendDateTo.get(dateKey); td.sum += acc; td.cnt += 1;

            // per game stats
            if (!gameToStats.has(game)) gameToStats.set(game, { sum: 0, cnt: 0 });
            const gs = gameToStats.get(game); gs.sum += acc; gs.cnt += 1;

            // per student overview
            if (!studentToAgg.has(name)) studentToAgg.set(name, { accSum: 0, cnt: 0, timeSum: 0 });
            const sa = studentToAgg.get(name); sa.accSum += acc; sa.cnt += 1; sa.timeSum += timeS;
          });
        });
      promises.push(p);
    });
    return Promise.all(promises).then(() => {
      // Update trend chart
      if (performanceTrendsChart) {
        const labels = Array.from(trendDateTo.keys());
        const data = labels.map((k) => {
          const v = trendDateTo.get(k); return v && v.cnt ? Number((v.sum / v.cnt).toFixed(1)) : 0;
        });
        performanceTrendsChart.data.labels = labels;
        performanceTrendsChart.data.datasets[0].data = data;
        performanceTrendsChart.update();
      }

      // Accuracy and time summary charts use simple single bars from global average of last compute
      if (accuracySummaryChart) {
        const all = Array.from(gameToStats.values());
        const avg = all.length ? (all.reduce((s, g) => s + g.sum, 0) / all.reduce((s, g) => s + g.cnt, 0)) : 0;
        accuracySummaryChart.data.labels = ['hello'];
        accuracySummaryChart.data.datasets[0].data = [Number(avg.toFixed(1))];
        accuracySummaryChart.update();
      }
      if (completionTimeSummaryChart) {
        // Estimate from studentToAgg
        const all = Array.from(studentToAgg.values());
        const avgT = all.length ? (all.reduce((s, v) => s + v.timeSum, 0) / all.reduce((s, v) => s + v.cnt, 0)) : 0;
        completionTimeSummaryChart.data.labels = ['hello'];
        completionTimeSummaryChart.data.datasets[0].data = [Number(avgT.toFixed(1))];
        completionTimeSummaryChart.update();
      }

      // Game Performance list
      const gp = document.getElementById('game-performance-list');
      if (gp) {
        const items = Array.from(gameToStats.entries()).map(([game, v]) => {
          const pct = v.cnt ? Number((v.sum / v.cnt).toFixed(1)) : 0;
          return `<div style="margin:8px 0;background:#f1f5f9;border-radius:8px;overflow:hidden">
            <div style="padding:8px 12px;display:flex;justify-content:space-between;align-items:center">
              <span>${game}</span>
              <span>${pct}%</span>
            </div>
            <div style="height:8px;background:#e5e7eb"><div style="height:8px;width:${pct}%;background:#cbd5e1"></div></div>
          </div>`;
        }).join('');
        gp.innerHTML = items || '<p>No data</p>';
      }

      // Key Insights
      const topGame = Array.from(gameToStats.entries()).sort((a,b)=> (b[1].sum/b[1].cnt) - (a[1].sum/a[1].cnt))[0];
      const worstGame = Array.from(gameToStats.entries()).sort((a,b)=> (a[1].sum/a[1].cnt) - (b[1].sum/b[1].cnt))[0];
      const bestStreakStudent = Array.from(studentToAgg.entries()).sort((a,b)=> b[1].cnt - a[1].cnt)[0];
      const topGameNameEl = document.getElementById('top-game-name');
      const topGameAccEl = document.getElementById('top-game-accuracy');
      const needsFocusGameEl = document.getElementById('needs-focus-game');
      const needsFocusAccEl = document.getElementById('needs-focus-accuracy');
      const bestStreakNameEl = document.getElementById('best-streak-student');
      const bestStreakCountEl = document.getElementById('best-streak-count');
      if (topGame) { topGameNameEl && (topGameNameEl.textContent = topGame[0]); topGameAccEl && (topGameAccEl.textContent = `${((topGame[1].sum/topGame[1].cnt)||0).toFixed(1)}%`); }
      if (worstGame) { needsFocusGameEl && (needsFocusGameEl.textContent = worstGame[0]); needsFocusAccEl && (needsFocusAccEl.textContent = `${((worstGame[1].sum/worstGame[1].cnt)||0).toFixed(1)}%`); }
      if (bestStreakStudent) { bestStreakNameEl && (bestStreakNameEl.textContent = bestStreakStudent[0]); bestStreakCountEl && (bestStreakCountEl.textContent = `${bestStreakStudent[1].cnt} sessions`); }

      // Student Overview
      const so = document.getElementById('student-overview-list');
      if (so) {
        const items = Array.from(studentToAgg.entries()).map(([name,v]) => {
          const acc = v.cnt ? (v.accSum / v.cnt) : 0;
          const time = v.cnt ? (v.timeSum / v.cnt) : 0;
          return `<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 12px;border:1px solid #e5e7eb;border-radius:8px;margin:6px 0;background:#fff">
            <div style="display:flex;align-items:center;gap:10px"><div style="width:36px;height:36px;border-radius:50%;background:#e2e8f0;display:flex;align-items:center;justify-content:center;font-weight:600">${name.charAt(0).toUpperCase()}</div><div><div style="font-weight:600">${name}</div><div style="font-size:12px;color:#64748b">${v.cnt} sessions</div></div></div>
            <div style="display:flex;gap:8px"><span style="background:#d1fae5;color:#065f46;padding:4px 8px;border-radius:999px;font-size:12px">${acc.toFixed(1)}%</span><span style="background:#ede9fe;color:#4c1d95;padding:4px 8px;border-radius:999px;font-size:12px">${time.toFixed(1)}s</span></div>
          </div>`;
        }).join('');
        so.innerHTML = items || '<p>No students</p>';
      }
    });
  });
}

// ------------------------------
// Student Management (CRUD)
// ------------------------------
function initStudentForm() {
  const studentForm = document.getElementById('student-form');
  const cancelBtn = document.getElementById('cancel-btn');

  studentForm.addEventListener('submit', function (e) {
    e.preventDefault();
    const id = document.getElementById('student-id').value;
    const currentTeacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
    if (!currentTeacherId) {
      showResultMessage('Please select a teacher before adding or updating a student.', true);
      return;
    }
    
    // Build boolean needs (top-level fields only) using direct checkbox states
    const getNeed = (k) => {
      const el = document.querySelector(`.cognitive-need[name="${k}"]`);
      return el ? !!el.checked : false;
    };
    const attention = getNeed('attention');
    const logic = getNeed('logic');
    const memory = getNeed('memory');
    const verbal = getNeed('verbal');
    
    const fullName = document.getElementById('student-name').value.trim();
    const genderValue = document.getElementById('student-gender').value;
    const ageValue = document.getElementById('student-age').value;

    const studentData = {
      // Keep both keys for web + Flutter compatibility
      name: fullName,
      fullName: fullName,
      age: ageValue ? Number(ageValue) : null,
      gender: genderValue,
      sex: genderValue,
      contactNumber: document.getElementById('student-contact').value.trim(),
      guardianName: document.getElementById('student-guardian').value.trim()
    };
    // Attach top-level booleans
    studentData.attention = attention;
    studentData.logic = logic;
    studentData.memory = memory;
    studentData.verbal = verbal;

    if (id) {
      // Update existing under teacher path only (no extra collections)
      // When updating, also remove nested cognitiveNeeds field if it exists
      const updateData = { ...studentData, cognitiveNeeds: firebase.firestore.FieldValue.delete() };
      db.collection('teachers').doc(currentTeacherId).collection('students').doc(id)
        .set(updateData, { merge: true })
        .then(function () {
          clearStudentForm();
          showResultMessage('Student updated successfully!', false);
        })
        .catch(function (error) {
          console.error('Update student error:', error);
          showResultMessage('Error updating student: ' + error.message, true);
        });
    } else {
      // Create new under teacher path only (no extra collections)
      db.collection('teachers').doc(currentTeacherId).collection('students')
        .add({
          ...studentData,
          createdAt: firebase.firestore.FieldValue.serverTimestamp(),
          totalGamesPlayed: 0,
          averageAccuracy: 0,
          favoriteGame: ''
        })
        .then(function () {
          clearStudentForm();
          showResultMessage('Student added successfully!', false);
          loadStudents();
        })
        .catch(function (error) {
          console.error('Add student error:', error);
          showResultMessage('Error adding student: ' + error.message, true);
        });
    }
  });

  cancelBtn.addEventListener('click', function () {
    clearStudentForm();
  });
}

function clearStudentForm() {
  document.getElementById('student-id').value = '';
  document.getElementById('student-name').value = '';
  document.getElementById('student-age').value = '';
  document.getElementById('student-gender').value = '';
  document.querySelectorAll('.cognitive-need').forEach(checkbox => {
    checkbox.checked = false;
  });
  document.getElementById('student-contact').value = '';
  document.getElementById('student-guardian').value = '';
  document.getElementById('submit-btn').textContent = 'Add Student';
  document.getElementById('form-title').textContent = 'Add New Student';
  document.getElementById('cancel-btn').style.display = 'none';
  const modal = document.getElementById('student-modal');
  if (modal) {
    modal.style.display = 'none';
  }
}

function loadStudents() {
  const currentTeacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
  
  const tbody = document.querySelector('#students-table tbody');
  
  if (!currentTeacherId) {
    tbody.innerHTML = `
      <tr>
        <td colspan="7" class="empty-message">
          <i class="fas fa-user-graduate"></i> Please select a teacher to view students
        </td>
      </tr>
    `;
    return;
  }

  // Clean up previous listener if any
  if (typeof studentsUnsubscribe === 'function') {
    try { studentsUnsubscribe(); } catch (e) {}
    studentsUnsubscribe = null;
  }

  // Listen to students for the selected teacher (no orderBy to avoid missing-field issues)
  const queryRef = db.collection('teachers').doc(currentTeacherId).collection('students');
  studentsUnsubscribe = queryRef.onSnapshot(function (snapshot) {
      tbody.innerHTML = '';
      
      if (snapshot.empty) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">No students found for this teacher</td></tr>';
        return;
      }

      // Collect and sort by name client-side
      const rows = snapshot.docs.map(d => ({ id: d.id, data: d.data() }));
      rows.sort((a, b) => {
        const an = (a.data.fullName || a.data.name || '').toString().toLowerCase();
        const bn = (b.data.fullName || b.data.name || '').toString().toLowerCase();
        return an.localeCompare(bn);
      });

      rows.forEach(({ id, data }) => {
        // Check if student was created in the selected school year
        const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
        if (isDateInSelectedYear && !isDateInSelectedYear(data.createdAt)) {
          return; // Skip this student if not in selected year
        }
        
        const studentName = data.fullName || data.name || 'Unknown';
        const needsDisplay = formatCognitiveNeeds(data);
        const row = document.createElement('tr');
        row.innerHTML = `
          <td style="padding-left: 16px;">${studentName}</td>
          <td>${data.age || ''}</td>
          <td>${data.sex || data.gender || ''}</td>
          <td>${needsDisplay}</td>
          <td>${data.contactNumber || ''}</td>
          <td>${data.guardianName || ''}</td>
          <td style="position: relative; padding-right: 16px;">
            <div class="action-buttons">
              <button class="edit-teacher-btn" onclick="editStudent('${id}')" title="Edit">
                <i class="fas fa-edit"></i>
              </button>
              <button class="delete-pin-btn" onclick="deleteStudent('${id}')" title="Delete">
                <i class="fas fa-trash"></i>
              </button>
            </div>
          </td>`;
        tbody.appendChild(row);
      });
    });
}

// Return display string for a student's cognitive challenges, supporting array or boolean map
function formatCognitiveNeeds(student) {
  // Prioritize top-level boolean needs
  const orderTop = ['Attention', 'Logic', 'Memory', 'Verbal'];
  const selectedTop = orderTop.filter(cat => isTrueLike(student[cat.toLowerCase()]));
  if (selectedTop.length > 0) return selectedTop.join(', ');

  // Legacy nested map support (if still present)
  if (student.cognitiveNeeds && typeof student.cognitiveNeeds === 'object') {
    const m = student.cognitiveNeeds;
    const order = ['Attention', 'Logic', 'Memory', 'Verbal'];
    const selected = order.filter(cat => !!m[cat.toLowerCase()]);
    if (selected.length > 0) return selected.join(', ');
  }

  // Explicitly ignore game-related fields
  if (Array.isArray(student.challenges) && student.challenges.length > 0) {
    const validChallenges = student.challenges.filter(challenge => 
      ['Attention', 'Logic', 'Memory', 'Verbal'].includes(challenge)
    );
    if (validChallenges.length > 0) return validChallenges.join(', ');
  }

  return 'None';
}

window.editStudent = function (id) {
  const currentTeacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
  db.collection('teachers').doc(currentTeacherId).collection('students').doc(id).get().then(function(doc) {
    if (doc.exists) {
      const student = doc.data();
      openStudentModal();
      document.getElementById('student-id').value = id;
      document.getElementById('student-name').value = student.fullName || student.name || '';
      document.getElementById('student-age').value = (student.age !== undefined && student.age !== null) ? student.age : '';
      document.getElementById('student-gender').value = student.sex || student.gender || '';
      document.querySelectorAll('.cognitive-need').forEach(checkbox => {
        checkbox.checked = false;
      });
      // Use top-level booleans (single source of truth)
      ['attention','logic','memory','verbal'].forEach(key => {
        const checkbox = document.querySelector(`.cognitive-need[name="${key}"]`);
        if (!checkbox) return;
        checkbox.checked = isTrueLike(student[key]);
      });
      document.getElementById('student-contact').value = student.contactNumber || student.contact || '';
      document.getElementById('student-guardian').value = student.guardianName || student.guardian || '';
      document.getElementById('submit-btn').textContent = 'Update Student';
      document.getElementById('form-title').textContent = 'Edit Student';
      document.getElementById('cancel-btn').style.display = 'inline-block';
    } else {
      showResultMessage('Student not found!', true);
    }
  }).catch(function(error) {
    showResultMessage('Error getting student: ' + error, true);
  });
};

window.deleteStudent = function (id) {
  const confirmDialog = document.getElementById('delete-teacher-modal');
  const confirmBtn = document.getElementById('confirm-delete-teacher');
  const cancelBtn = document.getElementById('cancel-delete-teacher');

  confirmDialog.style.display = 'block';

  confirmBtn.onclick = function () {
    const currentTeacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
    if (!currentTeacherId) {
      showResultMessage('Please select a teacher first.', true);
      return;
    }

    // Delete subcollection records then the student document
    deleteStudentRecords(currentTeacherId, id)
      .then(() => db.collection('teachers').doc(currentTeacherId).collection('students').doc(id).delete())
      .then(function () {
        showResultMessage('Student and all associated records deleted successfully!', false);
        confirmDialog.style.display = 'none';
      })
      .catch(function (error) {
        console.error('Error in delete operation:', error);
        showResultMessage('Error deleting student: ' + error.message, true);
      });
  };

  cancelBtn.onclick = function () {
    confirmDialog.style.display = 'none';
  };

  window.onclick = function(event) {
    if (event.target == confirmDialog) {
      confirmDialog.style.display = 'none';
    }
  }
};

// Helper function to delete all sessions for a student
// Delete all records for a student under the teacher path and mirror roots
async function deleteStudentRecords(teacherId, studentId) {
  try {
    const recordsRef = db.collection('teachers')
      .doc(teacherId)
      .collection('students')
      .doc(studentId)
      .collection('records');

    const snapshot = await recordsRef.get();
    
    // If there are no sessions, return immediately
    if (snapshot.empty) {
      console.log('No records found for student:', studentId);
      return;
    }
    
    // Create a batch to perform multiple deletes
    const batch = db.batch();
    
    // Add each record document to the batch deletion
    snapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Commit the batch deletion
    return await batch.commit();
  } catch (error) {
    console.error('Error deleting student records:', error);
    throw error; // Re-throw to handle in the calling function
  }
}

// Remove legacy gameRecords deletion and sessions usage; everything is under teachers/.../records now

function filterStudents(searchTerm) {
  const rows = document.querySelectorAll('#students-table tbody tr');
  searchTerm = searchTerm.toLowerCase();
  
  rows.forEach(row => {
    const name = row.querySelector('td:first-child').textContent.toLowerCase();
    row.style.display = name.includes(searchTerm) ? '' : 'none';
  });
}

function openStudentModal() {
  const modal = document.getElementById('student-modal');
  modal.style.display = 'block';
  modal.classList.add('slide-in-animation');
  modal.scrollIntoView({ behavior: 'smooth' });
  setTimeout(() => {
    modal.classList.remove('slide-in-animation');
  }, 500);
}

// ------------------------------
// Custom Result Window Functionality
// ------------------------------
function showResultMessage(message, isError = false) {
  const resultWindow = document.getElementById('result-window');
  const resultMessage = document.getElementById('result-message');
  const closeBtn = document.getElementById('close-result-btn');

  resultMessage.textContent = message;
  if (isError) {
    resultWindow.classList.remove('success');
    resultWindow.classList.add('error');
  } else {
    resultWindow.classList.remove('error');
    resultWindow.classList.add('success');
  }
  resultWindow.style.display = 'flex';

  closeBtn.onclick = function () {
    resultWindow.style.display = 'none';
  };

  setTimeout(function () {
    resultWindow.style.display = 'none';
  }, 3000);
}

// ------------------------------
// Teacher Emails Management (CRUD)
// ------------------------------
async function createTeacherAccount(teacherName, teacherEmail, teacherPassword, teacherPin) {
  try {
    // First check if email exists in Firebase Authentication
    const existingUser = await firebase.auth().fetchSignInMethodsForEmail(teacherEmail);
    if (existingUser.length > 0) {
      throw new Error('This email is already registered in Firebase Authentication');
    }

    // Check if email exists in Firestore
    const emailCheck = await db.collection('teachers').where('email', '==', teacherEmail).get();
    if (!emailCheck.empty) {
      throw new Error('This email already exists in the database');
    }

    // Create user in Firebase Authentication
    const userCredential = await firebase.auth().createUserWithEmailAndPassword(teacherEmail, teacherPassword);
    const user = userCredential.user;

    // Add teacher to Firestore using the auth UID as document ID in teachers collection
    await db.collection('teachers').doc(user.uid).set({
      name: teacherName,
      email: teacherEmail,
      password: teacherPassword,
      pin: teacherPin,
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      uid: user.uid
    });

    return { success: true, message: 'Teacher account created successfully!' };
  } catch (error) {
    console.error('Error creating teacher:', error);
    return { success: false, message: error.message };
  }
}

// This is the single consolidated initTeacherForm function.
// All duplicate logic has been removed.
function initTeacherForm() {
  const form = document.getElementById('teacher-form');
  const openTeacherFormBtn = document.getElementById('open-teacher-form-btn');
  const teacherModal = document.getElementById('teacher-modal');
  const teacherModalClose = document.getElementById('teacher-modal-close');
  const teacherCancelBtn = document.getElementById('teacher-cancel-btn');

  if (openTeacherFormBtn && teacherModal) {
    openTeacherFormBtn.addEventListener('click', function() {
      clearTeacherForm();
      teacherModal.style.display = 'block';
      teacherModal.classList.add('slide-in-animation');
      setTimeout(() => {
        teacherModal.classList.remove('slide-in-animation');
      }, 500);
    });
  }

  if (teacherModalClose && teacherModal) {
    teacherModalClose.addEventListener('click', function() {
      teacherModal.style.display = 'none';
      clearTeacherForm();
    });
  }

  if (teacherCancelBtn) {
    teacherCancelBtn.addEventListener('click', function() {
      teacherModal.style.display = 'none';
      clearTeacherForm();
    });
  }

  // Close modal when clicking outside
  window.addEventListener('click', function(e) {
    if (e.target === teacherModal) {
      teacherModal.style.display = 'none';
      clearTeacherForm();
    }
  });

  // Form submission handler
  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();

      const teacherName = document.getElementById('teacher-name').value.trim();
      const teacherEmail = document.getElementById('teacher-email').value.trim();
      const teacherPassword = document.getElementById('teacher-password').value.trim();
      const teacherPin = document.getElementById('teacher-pin').value.trim();

      if (!teacherName || !teacherEmail || !teacherPassword || !teacherPin) {
        showResultMessage('Please fill in all fields', true);
        return;
      }

      if (teacherPin.length !== 6 || isNaN(teacherPin)) {
        showResultMessage('PIN must be a 6-digit number', true);
        return;
      }

      try {
        // Check if the email already exists in Firebase Authentication
        const existingUser = await firebase.auth().fetchSignInMethodsForEmail(teacherEmail);
        if (existingUser.length > 0) {
          showResultMessage('A teacher with this email already exists in Firebase Authentication', true);
          return;
        }

        // Check if the email already exists in Firestore
        const emailCheck = await db.collection('teachers').where('email', '==', teacherEmail).get();
        if (!emailCheck.empty) {
          showResultMessage('A teacher with this email already exists in Firestore', true);
          return;
        }

        // Create user in Firebase Authentication
        const userCredential = await firebase.auth().createUserWithEmailAndPassword(teacherEmail, teacherPassword);
        const user = userCredential.user;

        // Add teacher to Firestore using the auth UID as document ID in teachers collection
        await db.collection('teachers').doc(user.uid).set({
          name: teacherName,
          email: teacherEmail,
          password: teacherPassword,
          pin: teacherPin,
          createdAt: firebase.firestore.FieldValue.serverTimestamp(),
          uid: user.uid
        });

        // Display the password to the user (optional)
        showResultMessage(`Teacher added successfully! Password: ${teacherPassword}`, false);

        teacherModal.style.display = 'none';
        clearTeacherForm();
        loadTeacherEmails(); // Refresh the table

      } catch (error) {
        console.error('Error creating teacher:', error);
        showResultMessage('Error creating teacher: ' + error.message, true);
      }
    });
  }
}

function clearTeacherForm() {
  const teacherForm = document.getElementById('teacher-form');
  if (teacherForm) {
    document.getElementById('teacher-name').value = '';
    document.getElementById('teacher-email').value = '';
    document.getElementById('teacher-password').value = '';
    document.getElementById('teacher-pin').value = '';
  }
}

function filterTeachers(searchTerm) {
  const rows = document.querySelectorAll('#teacher-table tbody tr');
  searchTerm = searchTerm.toLowerCase();
  
  rows.forEach(row => {
    const name = row.querySelector('td:nth-child(2)').textContent.toLowerCase();
    const email = row.querySelector('td:nth-child(3)').textContent.toLowerCase();
    row.style.display = (name.includes(searchTerm) || email.includes(searchTerm)) ? '' : 'none';
  });
}

function loadTeacherEmails() {
  db.collection('teachers').orderBy('createdAt', 'desc').get()
    .then(function (snapshot) {
      const tbody = document.querySelector('#teacher-table tbody');
      tbody.innerHTML = '';
      
      if (snapshot.empty) {
        const emptyRow = document.createElement('tr');
        emptyRow.innerHTML = '<td colspan="6" class="text-center">No teachers found</td>';
        tbody.appendChild(emptyRow);
        return;
      }

      snapshot.forEach(function (doc) {
        const teacher = doc.data();
        const createdAtStr = teacher.createdAt ? 
          (teacher.createdAt.toDate ? teacher.createdAt.toDate().toLocaleString() : teacher.createdAt) 
          : '';

        const row = document.createElement('tr');
        row.innerHTML = `
          <td>${createdAtStr}</td>
          <td>${teacher.name || ''}</td>
          <td>${teacher.email || ''}</td>
          <td>${teacher.password || ''}</td>
          <td>${teacher.pin || ''}</td>
          <td>
            <div class="action-buttons">
              <button class="edit-teacher-btn" title="Edit">
                <i class="fas fa-edit"></i>
              </button>
              <button class="delete-pin-btn" title="Delete">
                <i class="fas fa-trash"></i>
              </button>
            </div>
          </td>`;

        const editBtn = row.querySelector('.edit-teacher-btn');
        const deleteBtn = row.querySelector('.delete-pin-btn');
        
        editBtn.addEventListener('click', () => {
          showEditTeacherModal(doc.id, teacher);
        });

        deleteBtn.addEventListener('click', () => {
          showDeleteTeacherModal(doc.id, teacher.email);
        });

        tbody.appendChild(row);
      });
    })
    .catch(function (error) {
      console.error("Error loading teachers:", error);
      showResultMessage("Error loading teachers: " + error.message, true);
    });
}

function showEditTeacherModal(teacherId, teacher) {
  const modal = document.getElementById('edit-teacher-modal');
  const nameInput = document.getElementById('edit-teacher-name');
  const pinInput = document.getElementById('edit-teacher-pin');
  const saveBtn = document.getElementById('edit-teacher-save');
  const closeBtn = document.getElementById('edit-teacher-modal-close');
  const cancelBtn = document.getElementById('edit-teacher-cancel');

  modal.style.display = 'block';
  nameInput.value = teacher.name || '';
  pinInput.value = teacher.pin || '';

  closeBtn.onclick = function() {
    modal.style.display = 'none';
  };

  cancelBtn.onclick = function() {
    modal.style.display = 'none';
  };

  saveBtn.onclick = function() {
    const newName = nameInput.value.trim();
    const newPin = pinInput.value.trim();

    if (!newName) {
      showResultMessage('Name cannot be empty', true);
      return;
    }

    if (newPin.length !== 6 || isNaN(newPin)) {
      showResultMessage('PIN must be a 6-digit number.', true);
      return;
    }

    const updates = {
      name: newName,
      pin: newPin
    };

    db.collection('teachers').doc(teacherId).update(updates)
      .then(() => {
        modal.style.display = 'none';
        showResultMessage('Teacher information updated successfully!', false);
        loadTeacherEmails();
      })
      .catch((error) => {
        showResultMessage('Error updating teacher: ' + error.message, true);
      });
  };

  window.onclick = function(event) {
    if (event.target == modal) {
      modal.style.display = 'none';
    }
  }
}

function showDeleteTeacherModal(teacherId, teacherEmail) {
  const modal = document.getElementById('delete-teacher-modal');
  const confirmBtn = document.getElementById('confirm-delete-teacher');
  const cancelBtn = document.getElementById('cancel-delete-teacher');

  if (!modal || !confirmBtn || !cancelBtn) {
    console.error('Delete modal elements not found');
    return;
  }

  modal.style.display = 'block';

  confirmBtn.onclick = async function() {
    try {
      // Delete from Firestore first
      await db.collection('teachers').doc(teacherId).delete();
      
      showResultMessage('Teacher deleted successfully!', false);
      modal.style.display = 'none';
      loadTeacherEmails(); // Refresh the table
    } catch (error) {
      console.error('Error deleting teacher:', error);
      showResultMessage('Error deleting teacher: ' + error.message, true);
    }
  };

  cancelBtn.onclick = function() {
    modal.style.display = 'none';
  };

  window.onclick = function(event) {
    if (event.target == modal) {
      modal.style.display = 'none';
    }
  };
}

// ------------------------------
// Sidebar Navigation and Dark Mode
// ------------------------------
function initSidebar() {
  document.querySelectorAll('.sidebar-item').forEach(item => {
    item.addEventListener('click', function (e) {
      e.preventDefault(); // Prevent default anchor behavior
      document.querySelectorAll('.sidebar-item').forEach(i => i.classList.remove('active'));
      this.classList.add('active');
      
      document.querySelectorAll('section').forEach(section => {
        section.style.display = 'none';
      });
      
      const targetId = this.getAttribute('data-target');
      if (targetId) {
        document.getElementById(targetId).style.display = 'block';
        
        // Special initialization for sections needing data
        if (targetId === 'students-section') {
          // Refresh students data
          loadStudents();
        } else if (targetId === 'records-section') {
          // Init records section if needed
          if (typeof initRecordsSection === 'function') {
            initRecordsSection();
          }
          loadStudentRecords();
        } else if (targetId === 'teacher-emails-section') {
          // Refresh teacher emails
          loadTeacherEmails();
        } else if (targetId === 'activities-section') {
          // Load activities data
          loadActivities();
        }
      }
    });
  });
}

function initDarkMode() {
  const darkModeToggle = document.getElementById('dark-mode-toggle');
  if (!darkModeToggle) return;
  
  if (localStorage.getItem('darkMode') === 'enabled') {
    document.body.classList.add('dark-mode');
    darkModeToggle.checked = true;
  }
  
  darkModeToggle.addEventListener('change', function () {
    if (darkModeToggle.checked) {
      document.body.classList.add('dark-mode');
      localStorage.setItem('darkMode', 'enabled');
    } else {
      document.body.classList.remove('dark-mode');
      localStorage.setItem('darkMode', 'disabled');
    }
  });
  
  const settingsForm = document.getElementById('settings-form');
  if (settingsForm) {
    settingsForm.addEventListener('submit', function(e) {
      e.preventDefault();
      const notificationsEnabled = document.getElementById('notification-toggle').checked;
      const fontSize = document.getElementById('font-size').value;
      localStorage.setItem('notificationsEnabled', notificationsEnabled ? 'true' : 'false');
      localStorage.setItem('fontSize', fontSize);
      showResultMessage('Settings saved successfully', false);
    });
  }
}

// ------------------------------
// Profile Modal Functionality & Edit Profile
// ------------------------------
function initProfileModal() {
  const profileTrigger = document.getElementById('profile-trigger');
  const modal = document.getElementById('profile-modal');
  const closeModal = document.querySelector('.modal .close');
  const profileForm = document.getElementById('profile-form');

  if (profileTrigger) {
    profileTrigger.addEventListener('click', function () {
      if (modal) {
        modal.style.display = 'block';
      } else {
        console.error("Modal element not found.");
      }
    });
  } else {
    console.error("Profile trigger element not found.");
  }

  if (closeModal) {
    closeModal.addEventListener('click', function () {
      if (modal) {
        modal.style.display = 'none';
      }
    });
  } else {
    console.error("Close button element not found.");
  }

  window.addEventListener('click', function (event) {
    if (event.target === modal) {
      modal.style.display = 'none';
    }
  });

  if (profileForm) {
    profileForm.addEventListener('submit', function (e) {
      e.preventDefault();
      const formData = new FormData(profileForm);
      fetch('updateProfile.php', {
        method: 'POST',
        body: formData
      })
      .then(function (response) {
        return response.json();
      })
      .then(function (data) {
        if (data.message === "Profile updated successfully") {
          showResultMessage("Profile updated successfully", false);
          document.querySelector('.user-info span').textContent = formData.get('username');
          modal.style.display = 'none';
        } else {
          showResultMessage("Error: " + data.message, true);
        }
      })
      .catch(function (err) {
        console.error("Error updating profile: ", err);
        showResultMessage("Error updating profile", true);
      });
    });
  }
}

// ------------------------------
// Admin Form Submission for Adding Admins
// ------------------------------
function initAdminModal() {
  const addAdminBtn = document.getElementById('add-admin-button');
  const adminModal = document.getElementById('add-admin-modal');
  const closeBtn = document.getElementById('add-admin-modal-close');
  const cancelBtn = document.getElementById('add-admin-cancel');
  const adminForm = document.getElementById('admin-form');

  if (!addAdminBtn || !adminModal || !adminForm) {
    console.error('Admin modal elements not found');
    return;
  }

  // Show modal
  addAdminBtn.addEventListener('click', () => {
    adminModal.style.display = 'block';
  });

  // Hide modal handlers
  closeBtn.addEventListener('click', () => {
    adminModal.style.display = 'none';
    adminForm.reset();
  });

  cancelBtn.addEventListener('click', () => {
    adminModal.style.display = 'none';
    adminForm.reset();
  });

  window.addEventListener('click', (e) => {
    if (e.target === adminModal) {
      adminModal.style.display = 'none';
      adminForm.reset();
    }
  });

  // Form submission
  adminForm.addEventListener('submit', function(e) {
    e.preventDefault();
    const formData = new FormData(this);
    
    if (!formData.get('username') || !formData.get('password')) {
      showResultMessage('Please fill in all fields', true);
      return;
    }

    fetch('processAddAdmin.php', {
      method: 'POST',
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        showResultMessage(data.message, false);
        
        // Update admin list display
        const adminListContainer = document.getElementById('admin-list-container');
        let adminListHtml = `<p>Total Admins: ${data.adminList.length}</p>`;
        adminListHtml += '<ul class="admin-list">';
        
        data.adminList.forEach(admin => {
          adminListHtml += `
            <li>
              <div class="admin-profile-wrap">
                <img src="${admin.profilePicture}" alt="Profile Picture of ${admin.username}" class="admin-profile-pic" />
              </div>
              <span class="admin-username">${admin.username}</span>
            </li>`;
        });
        
        adminListHtml += '</ul>';
        adminListContainer.innerHTML = adminListHtml;
        
        // Reset form and close modal
        adminForm.reset();
        adminModal.style.display = 'none';
      } else {
        showResultMessage(data.message, true);
      }
    })
    .catch(err => {
      console.error("Error:", err);
      showResultMessage("An error occurred while adding the admin.", true);
    });
  });
}

// ------------------------------
// Modal Profile Picture Upload
// ------------------------------
document.addEventListener('DOMContentLoaded', function() {
  const profilePictureInput = document.getElementById('profile-picture');
  const profilePicturePreviewImg = document.getElementById('profile-picture-preview-img');

  if (profilePictureInput && profilePicturePreviewImg) {
    profilePictureInput.addEventListener('change', function() {
      const file = this.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = function(e) {
          profilePicturePreviewImg.setAttribute('src', e.target.result);
        };
        reader.readAsDataURL(file);

        const formData = new FormData();
        formData.append('profile_picture', file);

        fetch('upload_profile_picture.php', {
          method: 'POST',
          body: formData
        })
        .then(function(response) {
          return response.json();
        })
        .then(function(data) {
          if (data.status === 'success') {
            console.log('Profile picture updated successfully.');
            profilePicturePreviewImg.setAttribute('src', data.file);
          } else {
            showResultMessage('Error: ' + data.message, true);
          }
        })
        .catch(function(error) {
          console.error('Error uploading file:', error);
          showResultMessage('Error uploading file', true);
        });
      }
    });
  }
});

// ------------------------------
// Glitch/Dust Easter Egg Effect
// ------------------------------
document.addEventListener('keydown', function(e) {
  if (e.altKey && e.shiftKey && e.key.toLowerCase() === 'e') {
    triggerOverloadGlitch();
  }
});

function triggerOverloadGlitch() {
  document.body.classList.add('glitch-effect-overload');
  setTimeout(() => {
    document.body.classList.remove('glitch-effect-overload');
  }, 4000);
}

// ------------------------------
// Records Management (CRUD)
// ------------------------------
document.addEventListener('DOMContentLoaded', function() {
  initRecordsSection();
});

function initRecordsSection() {
  loadStudentRecords();
  initRecordsSearch();
  initRecordsModal();
}

function initRecordsSearch() {
  const recordsSearchInput = document.getElementById('records-search');
  if (recordsSearchInput) {
    recordsSearchInput.addEventListener('input', function() {
      filterRecords(this.value.toLowerCase());
    });
  }
}

function initRecordsModal() {
  const recordsModalClose = document.getElementById('records-modal-close');
  if (recordsModalClose) {
    recordsModalClose.addEventListener('click', function() {
      document.getElementById('records-modal').style.display = 'none';
    });
  }
  
  window.addEventListener('click', function(e) {
    const modal = document.getElementById('records-modal');
    if (e.target === modal) {
      modal.style.display = 'none';
    }
  });
}

function loadStudentRecords() {
  const currentTeacherId = window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null;
  const tbody = document.querySelector('#records-table tbody');
  
  console.log('loadStudentRecords called, currentTeacherId:', currentTeacherId);
  console.log('teacherSwitcher available:', !!window.teacherSwitcher);
  
  if (!currentTeacherId) {
    // Load all students across all teachers so records list is not empty
    tbody.innerHTML = '';
    db.collectionGroup('students').orderBy('fullName').get()
      .then(function(snapshot) {
        tbody.innerHTML = '';
        if (snapshot.empty) {
          tbody.innerHTML = '<tr><td colspan="7" class="text-center">No students found</td></tr>';
          return;
        }
        snapshot.forEach(function(doc) {
          const student = doc.data();
          
          // Check if student was created in the selected school year
          const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
          if (isDateInSelectedYear && !isDateInSelectedYear(student.createdAt)) {
            return; // Skip this student if not in selected year
          }
          
          const studentName = student.fullName || student.name || 'Unknown';
          const challengesDisplay = Array.isArray(student.challenges) 
            ? student.challenges.join(', ') 
            : (student.challenges || 'None');
          const teacherId = doc.ref.parent && doc.ref.parent.parent ? doc.ref.parent.parent.id : null;
          const row = document.createElement('tr');
          row.classList.add('clickable-row');
          row.setAttribute('data-student-id', doc.id);
          row.innerHTML = `
            <td>${studentName}</td>
            <td>${student.age ? student.age + ' years old' : ''}</td>
            <td>${student.sex || student.gender || ''}</td>
            <td>${challengesDisplay}</td>
            <td>${student.contactNumber || ''}</td>
            <td>${student.guardianName || ''}</td>
            <td>
              <button class="btn-download" onclick="event.stopPropagation(); openDownloadMenu(event, '${doc.id}', '${studentName}', '${teacherId || ''}')">
                <i class="fas fa-download"></i> Download
              </button>
            </td>`;
          row.addEventListener('click', function() {
            viewStudentRecords(doc.id, studentName, teacherId);
          });
          tbody.appendChild(row);
        });
      })
      .catch(function(error) {
        console.warn('collectionGroup fallback, error:', error);
        // Fallback: aggregate students by iterating teachers
        db.collection('teachers').get().then(function(teachersSnap) {
          const promises = [];
          teachersSnap.forEach(function(tdoc) {
            const tid = tdoc.id;
            promises.push(
              db.collection('teachers').doc(tid).collection('students').get().then(function(stSnap) {
                return stSnap.docs.map(d => ({ doc: d, tid }));
              })
            );
          });
          Promise.all(promises).then(function(groups) {
            const all = groups.flat();
            if (all.length === 0) {
              tbody.innerHTML = '<tr><td colspan="7" class="text-center">No students found</td></tr>';
              return;
            }
            // Sort by full name
            all.sort((a, b) => {
              const sa = a.doc.data();
              const sb = b.doc.data();
              return (sa.fullName || sa.name || '').localeCompare(sb.fullName || sb.name || '');
            });
            all.forEach(({ doc: d, tid }) => {
              const student = d.data();
              
              // Check if student was created in the selected school year
              const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
              if (isDateInSelectedYear && !isDateInSelectedYear(student.createdAt)) {
                return; // Skip this student if not in selected year
              }
              
              const studentName = student.fullName || student.name || 'Unknown';
              const challengesDisplay = Array.isArray(student.challenges) 
                ? student.challenges.join(', ') 
                : (student.challenges || 'None');
              const row = document.createElement('tr');
              row.classList.add('clickable-row');
              row.setAttribute('data-student-id', d.id);
              row.innerHTML = `
                <td>${studentName}</td>
                <td>${student.age ? student.age + ' years old' : ''}</td>
                <td>${student.sex || student.gender || ''}</td>
                <td>${challengesDisplay}</td>
                <td>${student.contactNumber || ''}</td>
                <td>${student.guardianName || ''}</td>
                <td>
                  <button class="btn-download" onclick="event.stopPropagation(); openDownloadMenu(event, '${d.id}', '${studentName}', '${tid}')">
                    <i class="fas fa-download"></i> Download
                  </button>
                </td>`;
              row.addEventListener('click', function() {
                viewStudentRecords(d.id, studentName, tid);
              });
              tbody.appendChild(row);
            });
          });
        });
      });
    return;
  }

  // Load students for the selected teacher
  db.collection('teachers').doc(currentTeacherId).collection('students')
    .orderBy('fullName')
    .onSnapshot(function(snapshot) {
      tbody.innerHTML = '';
      
      if (snapshot.empty) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">No students found for this teacher</td></tr>';
        return;
      }

      snapshot.forEach(function(doc) {
        const student = doc.data();
        
        // Check if student was created in the selected school year
        const isDateInSelectedYear = window.teacherSwitcher ? window.teacherSwitcher.isDateInSelectedYear : null;
        if (isDateInSelectedYear && !isDateInSelectedYear(student.createdAt)) {
          return; // Skip this student if not in selected year
        }
        
        const studentName = student.fullName || student.name || 'Unknown';
        const challengesDisplay = Array.isArray(student.challenges) 
          ? student.challenges.join(', ') 
          : student.challenges || 'None';
        
        const row = document.createElement('tr');
        row.classList.add('clickable-row');
        row.setAttribute('data-student-id', doc.id);
        row.innerHTML = `
          <td>${studentName}</td>
          <td>${student.age ? student.age + ' years old' : ''}</td>
          <td>${student.sex || student.gender || ''}</td>
          <td>${challengesDisplay}</td>
          <td>${student.contactNumber || ''}</td>
          <td>${student.guardianName || ''}</td>
          <td>
            <button class="btn-download" onclick="event.stopPropagation(); openDownloadMenu(event, '${doc.id}', '${studentName}', '${currentTeacherId}')">
              <i class="fas fa-download"></i> Download
            </button>
          </td>`;
        
        row.addEventListener('click', function() {
          viewStudentRecords(doc.id, studentName, currentTeacherId);
        });
        tbody.appendChild(row);
      });
    });
}

// Function to generate and download student report
async function downloadStudentReport(studentId, studentName, teacherId) {
  try {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();
    
    // Resolve teacherId
    const resolvedTeacherId = teacherId || currentTeacherIdForRecords || (window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null);
    if (!resolvedTeacherId) {
      showResultMessage('Please select a teacher first', true);
      return;
    }

    // Get student details (try by id then by name)
    let studentDoc = await db.collection('teachers').doc(resolvedTeacherId).collection('students').doc(studentId).get();
    if (!studentDoc.exists && studentName && studentName !== studentId) {
      studentDoc = await db.collection('teachers').doc(resolvedTeacherId).collection('students').doc(studentName).get();
    }
    if (!studentDoc.exists) {
      showResultMessage('Student not found', true);
      return;
    }
    const studentData = studentDoc.data();
    
    // Get student records (ordered newest first)
    const studentDocId = studentDoc.id;
    let sessionsSnapshot = await db.collection('teachers')
      .doc(resolvedTeacherId)
      .collection('students')
      .doc(studentDocId)
      .collection('records')
      .orderBy('date', 'desc')
      .get();

    // Fallback for legacy data: try root students/{id}/sessions (old web path)
    if (sessionsSnapshot.empty) {
      sessionsSnapshot = await db.collection('students').doc(studentId).collection('sessions')
        .orderBy('date', 'desc')
        .get();
    }
    // Fallback by-name on legacy path
    if (sessionsSnapshot.empty && studentName && studentName !== studentId) {
      sessionsSnapshot = await db.collection('students').doc(studentName).collection('sessions')
        .orderBy('date', 'desc')
        .get();
    }

    if (sessionsSnapshot.empty) {
      showResultMessage('No records found for this student', true);
      return;
    }

    // Process records data
    const { records, stats, trends } = processRecordsForReport(sessionsSnapshot);
    
    // Generate performance graph
    const graphCanvas = await createPerformanceGraph(trends);
    
    // Create PDF content
    generatePDFContent(doc, studentName, studentData, stats, graphCanvas, records);
    
    // Save the PDF
    doc.save(`${studentName}_progress_report.pdf`);
    showResultMessage('Report downloaded successfully!', false);

  } catch (error) {
    console.error('Error generating report:', error);
    showResultMessage('Error generating report', true);
  }
}

// New report generator aligned with teacher/student/records data
async function downloadStudentReportV2(studentId, studentName, teacherId) {
  try {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();

    const resolvedTeacherId = teacherId || currentTeacherIdForRecords || (window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null);
    if (!resolvedTeacherId) {
      showResultMessage('Please select a teacher first', true);
      return;
    }

    // Resolve student document (id or fullName)
    let studentDoc = await db.collection('teachers').doc(resolvedTeacherId).collection('students').doc(studentId).get();
    if (!studentDoc.exists && studentName && studentName !== studentId) {
      studentDoc = await db.collection('teachers').doc(resolvedTeacherId).collection('students').doc(studentName).get();
    }
    if (!studentDoc.exists) {
      showResultMessage('Student not found', true);
      return;
    }
    const studentData = studentDoc.data();
    const studentDocId = studentDoc.id;

    // Load records strictly from new path
    const recordsSnap = await db.collection('teachers')
      .doc(resolvedTeacherId)
      .collection('students')
      .doc(studentDocId)
      .collection('records')
      .orderBy('date', 'desc')
      .get();

  let effectiveSnapshot = recordsSnap;

  if (effectiveSnapshot.empty) {
    // Fallback A: legacy top-level gameRecords filtered by studentName
    const nameKey = (studentData.fullName || studentData.name || studentName || '').trim();
    try {
      const gr = await db.collection('gameRecords')
        .where('studentName', '==', nameKey)
        .get();
      if (!gr.empty) {
        // Sort docs by date desc client-side
        const sorted = gr.docs.slice().sort((a, b) => {
          const ad = a.data().date;
          const bd = b.data().date;
          const da = ad && typeof ad === 'object' && ad.toDate ? ad.toDate() : (ad ? new Date(ad) : new Date(0));
          const dbv = bd && typeof bd === 'object' && bd.toDate ? bd.toDate() : (bd ? new Date(bd) : new Date(0));
          return dbv - da;
        });
        effectiveSnapshot = { forEach: (cb) => sorted.forEach(cb) };
      }
    } catch (_) {}
  }

  if (effectiveSnapshot.empty) {
    // Fallback B: legacy root students/{id or name}/sessions
    let legacy = await db.collection('students').doc(studentId).collection('sessions').orderBy('date','desc').get().catch(() => null);
    if (!legacy || legacy.empty) {
      if (studentName && studentName !== studentId) {
        legacy = await db.collection('students').doc(studentName).collection('sessions').orderBy('date','desc').get().catch(() => null);
      }
    }
    if (legacy && !legacy.empty) {
      effectiveSnapshot = legacy;
    }
  }

  if (!effectiveSnapshot || effectiveSnapshot.empty) {
    showResultMessage('No records found for this student', true);
    return;
  }

    // Prepare data for report
  const { records, stats, trends } = processRecordsForReport(effectiveSnapshot);

    // Build PDF (reuse existing helpers)
    const graphCanvas = await createPerformanceGraph(trends);
    const displayName = studentData.fullName || studentData.name || studentName || 'Student';
    generatePDFContent(doc, displayName, studentData, stats, graphCanvas, records);
    
    doc.save(`${displayName}_progress_report.pdf`);
    showResultMessage('Report downloaded successfully!', false);
  } catch (error) {
    console.error('Error generating report V2:', error);
    showResultMessage('Error generating report', true);
  }
}

// Brand new generator: Scans all possible sources, merges, sorts by date, and generates a unified report
async function downloadStudentReportNew(studentId, studentName, teacherId) {
  try {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();

    const resolvedTeacherId = teacherId || currentTeacherIdForRecords || (window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null);
    if (!resolvedTeacherId) {
      showResultMessage('Please select a teacher first', true);
      return;
    }

    // Find student document by id or by name under teacher
    let studentDoc = await db.collection('teachers').doc(resolvedTeacherId).collection('students').doc(studentId).get();
    if (!studentDoc.exists && studentName && studentName !== studentId) {
      const byNameDoc = await db.collection('teachers').doc(resolvedTeacherId).collection('students').doc(studentName).get();
      if (byNameDoc.exists) studentDoc = byNameDoc;
    }

    // Build a unified records array from multiple sources
    const combined = [];

    // Source 1: New path under teacher
    if (studentDoc.exists) {
      const recSnap = await db.collection('teachers')
        .doc(resolvedTeacherId)
        .collection('students')
        .doc(studentDoc.id)
        .collection('records')
        .get();
      recSnap.forEach(d => combined.push({ ...d.data(), _src: 'new' }));
    }

    // Source 2: Legacy gameRecords by studentName
    const lookupName = (studentDoc.exists ? (studentDoc.data().fullName || studentDoc.data().name) : studentName) || '';
    if (lookupName) {
      const grSnap = await db.collection('gameRecords').where('studentName', '==', lookupName).get().catch(() => null);
      if (grSnap && !grSnap.empty) grSnap.forEach(d => combined.push({ ...d.data(), _src: 'gameRecords' }));
    }

    // Source 3: Legacy root sessions by id and by name
    const s1 = await db.collection('students').doc(studentId).collection('sessions').get().catch(() => null);
    if (s1 && !s1.empty) s1.forEach(d => combined.push({ ...d.data(), _src: 'sessionsById' }));
    if (studentName && studentName !== studentId) {
      const s2 = await db.collection('students').doc(studentName).collection('sessions').get().catch(() => null);
      if (s2 && !s2.empty) s2.forEach(d => combined.push({ ...d.data(), _src: 'sessionsByName' }));
    }

    if (combined.length === 0) {
      showResultMessage('No records found for this student', true);
      return;
    }

    // Normalize dates and important fields, sort by newest first
    const normalizeDate = (v) => {
      if (!v) return new Date(0);
      if (typeof v === 'object' && v.toDate) return v.toDate();
      return new Date(v);
    };

    const normalized = combined.map(r => ({
      date: r.date ? normalizeDate(r.date) : (r.lastPlayed ? normalizeDate(r.lastPlayed) : new Date(0)),
      challengeFocus: r.challengeFocus || 'N/A',
      game: r.game || r.gameKey || 'N/A',
      difficulty: r.difficulty || r.difficultyText || 'N/A',
      accuracy: typeof r.accuracy === 'number' ? r.accuracy : (parseFloat(r.accuracy) || 0),
      completionTime: typeof r.completionTime === 'number' ? r.completionTime : (parseFloat(r.completionTime) || 0),
      errors: r.errors || 0,
    })).sort((a, b) => b.date - a.date);

    // Convert to a pseudo snapshot interface expected by processRecordsForReport
    const pseudoSnapshot = {
      forEach: (cb) => normalized.forEach((rec) => cb({ data: () => ({
        date: rec.date,
        challengeFocus: rec.challengeFocus,
        game: rec.game,
        difficulty: rec.difficulty,
        accuracy: rec.accuracy,
        completionTime: rec.completionTime,
        errors: rec.errors,
      }) }))
    };

    // Prepare data and generate
    const { records, stats, trends } = processRecordsForReport(pseudoSnapshot);
    const graphCanvas = await createPerformanceGraph(trends);

    const studentInfo = studentDoc && studentDoc.exists ? studentDoc.data() : { fullName: studentName };
    const displayName = studentInfo.fullName || studentInfo.name || studentName || 'Student';
    generatePDFContent(doc, displayName, studentInfo, stats, graphCanvas, records);

    doc.save(`${displayName}_progress_report.pdf`);
    showResultMessage('Report downloaded successfully!', false);
  } catch (error) {
    console.error('Error generating unified report:', error);
    showResultMessage('Error generating report', true);
  }
}

function formatDate(date) {
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// A separate date formatting function specifically for PDF reports
function formatDateForReport(date) {
  if (!date) return 'N/A';
  
  try {
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  } catch (e) {
    console.error('Error formatting date for report:', e);
    return 'N/A';
  }
}

function processRecordsForReport(recordsSnapshot) {
  let sessions = [];
  let totalAccuracy = 0;
  let totalCompletionTime = 0;
  let totalErrors = 0;
  let accuracyTrend = [];
  let completionTimeTrend = [];
  let errorsTrend = [];
  let dates = [];
  let count = 0;

  // First, collect all sessions
  recordsSnapshot.forEach(doc => {
    const session = doc.data();
    sessions.push(session);
  });

  // Sort by date (newest first for the sessions table, but oldest first for the trends)
  sessions.sort((a, b) => {
    const dateA = a.date?.toDate ? a.date.toDate() : new Date();
    const dateB = b.date?.toDate ? b.date.toDate() : new Date();
    return dateB - dateA; // descending order for table display
  });

  // Process the sessions for stats and trends (using first 20 for trends)
  const trendSessions = [...sessions].reverse().slice(0, 20); // oldest first for trends
  
  trendSessions.forEach(session => {
    if (session.accuracy !== undefined && !isNaN(session.accuracy)) {
      totalAccuracy += parseFloat(session.accuracy);
      accuracyTrend.push(parseFloat(session.accuracy));
    } else {
      accuracyTrend.push(null); // Use null for missing data points
    }
    
    if (session.completionTime !== undefined && !isNaN(session.completionTime)) {
      totalCompletionTime += parseFloat(session.completionTime);
      completionTimeTrend.push(parseFloat(session.completionTime));
    } else {
      completionTimeTrend.push(null);
    }
    
    if (session.errors !== undefined && !isNaN(session.errors)) {
      totalErrors += parseInt(session.errors);
      errorsTrend.push(parseInt(session.errors));
    } else {
      errorsTrend.push(null);
    }
    
    const date = session.date?.toDate ? session.date.toDate() : new Date();
    dates.push(formatDateForReport(date));
    count++;
  });

  // Calculate averages
  const stats = {
    avgAccuracy: count > 0 ? (totalAccuracy / count).toFixed(1) : "0.0",
    avgCompletionTime: count > 0 ? (totalCompletionTime / count).toFixed(1) : "0.0",
    avgErrors: count > 0 ? (totalErrors / count).toFixed(1) : "0.0",
    totalSessions: sessions.length
  };

  const trends = {
    dates,
    accuracyTrend,
    completionTimeTrend,
    errorsTrend
  };

  return { records: sessions, stats, trends };
}

async function createPerformanceGraph(trends) {
  const canvas = document.createElement('canvas');
  canvas.width = 800;
  canvas.height = 400;
  const ctx = canvas.getContext('2d');
  
  // Set background color to white
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  
  // Add padding
  const padding = 20;
  
  new Chart(ctx, {
    type: 'line',
    data: {
      labels: trends.dates,
      datasets: [
        {
          label: 'Accuracy %',
          data: trends.accuracyTrend,
          borderColor: '#4CAF50',
          backgroundColor: 'rgba(76, 175, 80, 0.1)',
          borderWidth: 3,
          pointBackgroundColor: '#4CAF50',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 5,
          pointHoverRadius: 7,
          tension: 0.4,
          fill: true
        },
        {
          label: 'Completion Time (sec)',
          data: trends.completionTimeTrend,
          borderColor: '#2196F3',
          backgroundColor: 'rgba(33, 150, 243, 0.1)',
          borderWidth: 3,
          pointBackgroundColor: '#2196F3',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 5,
          pointHoverRadius: 7,
          tension: 0.4,
          fill: true
        },
        {
          label: 'Errors',
          data: trends.errorsTrend,
          borderColor: '#f44336',
          backgroundColor: 'rgba(244, 67, 54, 0.1)',
          borderWidth: 3,
          pointBackgroundColor: '#f44336',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 5,
          pointHoverRadius: 7,
          tension: 0.4,
          fill: true
        }
      ]
    },
    options: {
      responsive: false,
      maintainAspectRatio: false,
      layout: {
        padding: padding
      },
      plugins: {
        title: {
          display: true,
          text: 'Performance Trends Over Time',
          font: {
            size: 18,
            weight: 'bold',
            family: 'Arial'
          },
          padding: {
            top: 10,
            bottom: 20
          },
          color: '#333'
        },
        legend: {
          position: 'bottom',
          labels: {
            boxWidth: 15,
            padding: 15,
            font: {
              size: 12,
              family: 'Arial'
            }
          }
        },
        tooltip: {
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          titleFont: {
            size: 14,
            family: 'Arial',
            weight: 'bold'
          },
          bodyFont: {
            size: 13,
            family: 'Arial'
          },
          padding: 12,
          cornerRadius: 6,
          displayColors: true
        }
      },
      scales: {
        x: {
          grid: {
            color: 'rgba(200, 200, 200, 0.3)',
            drawBorder: false
          },
          ticks: {
            font: {
              size: 11,
              family: 'Arial'
            },
            color: '#666',
            maxRotation: 45,
            minRotation: 45
          },
          title: {
            display: true,
            text: 'Session Date and Time',
            color: '#666',
            font: {
              size: 13,
              family: 'Arial',
              weight: 'bold'
            },
            padding: {
              top: 10
            }
          }
        },
        y: {
          beginAtZero: true,
          grid: {
            color: 'rgba(200, 200, 200, 0.3)',
            drawBorder: false
          },
          ticks: {
            font: {
              size: 11,
              family: 'Arial'
            },
            color: '#666',
            padding: 10
          },
          title: {
            display: true,
            text: 'Value',
            color: '#666',
            font: {
              size: 13,
              family: 'Arial',
              weight: 'bold'
            },
            padding: {
              bottom: 10
            }
          }
        }
      },
      elements: {
        line: {
          tension: 0.4
        }
      },
      animation: {
        duration: 500
      }
    }
  });

  // Wait for chart animation to complete
  await new Promise(resolve => setTimeout(resolve, 700));
  return canvas;
}

function generatePDFContent(doc, studentName, studentData, stats, graphCanvas, records) {
  // Set document properties
  doc.setProperties({
    title: `${studentName} - GrowBrain Progress Report`,
    subject: 'Student Progress Report',
    author: 'GrowBrain Learning Platform',
    creator: 'GrowBrain Dashboard',
    keywords: 'student report, progress, cognitive challenges, education',
    creationDate: new Date()
  });
  
  // Define colors
  const primaryColor = [76/255, 175/255, 80/255]; // #4CAF50
  const secondaryColor = [33/255, 150/255, 243/255]; // #2196F3
  const textColor = [40/255, 40/255, 40/255]; // Darker text for better readability
  const lightGray = [248/255, 248/255, 248/255]; // Very light gray for backgrounds
  
  // Add professional header with logo and title
  doc.setFillColor(0, 0, 0);
  doc.rect(0, 0, 210, 30, 'F');
  
  // Add title
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(22);
  doc.setFont('helvetica', 'bold');
  doc.text('GrowBrain', 20, 15);
  doc.setFontSize(16);
  doc.setFont('helvetica', 'normal');
  doc.text('Student Progress Report', 105, 15, { align: 'center' });
  doc.setFontSize(11);
  doc.text(new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }), 190, 15, { align: 'right' });
  
  // Add separator line
  doc.setDrawColor(255, 255, 255);
  doc.setLineWidth(0.5);
  doc.line(20, 20, 190, 20);
  
  // Add white space after header
  const contentStartY = 40;
  
  // Student information section title
  doc.setTextColor(...textColor);
  doc.setFontSize(16);
  doc.setFont('helvetica', 'bold');
  doc.text('Student Profile', 20, contentStartY);
  
  // Add horizontal rule under section title
  doc.setDrawColor(...primaryColor);
  doc.setLineWidth(0.5);
  doc.line(20, contentStartY + 5, 190, contentStartY + 5);
  
  // Create a box for student info - using white background with subtle border
  const studentInfoStartY = contentStartY + 10;
  doc.setFillColor(255, 255, 255); // Pure white background
  doc.roundedRect(20, studentInfoStartY, 170, 36, 3, 3, 'F');
  doc.setDrawColor(220/255, 220/255, 220/255); // Light gray border
  doc.setLineWidth(0.3);
  doc.roundedRect(20, studentInfoStartY, 170, 36, 3, 3, 'S');
  
  // Add student information in two columns
  doc.setFontSize(12);
  doc.setTextColor(...textColor);
  
  // Column 1 (left side)
  const col1 = 25;
  const col2 = 105;
  
  // Row 1
  doc.setFont('helvetica', 'bold');
  doc.text('Name:', col1, studentInfoStartY + 10);
  doc.setFont('helvetica', 'normal');
  doc.text(studentName, col1 + 30, studentInfoStartY + 10);
  
  doc.setFont('helvetica', 'bold');
  doc.text('Age:', col2, studentInfoStartY + 10);
  doc.setFont('helvetica', 'normal');
  doc.text(studentData.age ? `${studentData.age} years old` : 'N/A', col2 + 25, studentInfoStartY + 10);
  
  // Row 2
  doc.setFont('helvetica', 'bold');
  doc.text('Gender:', col1, studentInfoStartY + 20);
  doc.setFont('helvetica', 'normal');
  doc.text(studentData.gender || 'N/A', col1 + 30, studentInfoStartY + 20);
  
  doc.setFont('helvetica', 'bold');
  doc.text('Guardian:', col2, studentInfoStartY + 20);
  doc.setFont('helvetica', 'normal');
  doc.text(studentData.guardianName || 'N/A', col2 + 25, studentInfoStartY + 20);
  
  // Row 3
  doc.setFont('helvetica', 'bold');
  doc.text('Contact:', col1, studentInfoStartY + 30);
  doc.setFont('helvetica', 'normal');
  doc.text(studentData.contactNumber || 'N/A', col1 + 30, studentInfoStartY + 30);
  
  doc.setFont('helvetica', 'bold');
  doc.text('Challenges:', col2, studentInfoStartY + 30);
  doc.setFont('helvetica', 'normal');
  const challenges = Array.isArray(studentData.challenges) ? studentData.challenges.join(', ') : (studentData.challenges || 'None');
  doc.text(challenges, col2 + 25, studentInfoStartY + 30);
  
  // Performance Summary section
  const summaryStartY = studentInfoStartY + 50;
  
  // Summary title
  doc.setTextColor(...textColor);
  doc.setFontSize(16);
  doc.setFont('helvetica', 'bold');
  doc.text('Performance Summary', 20, summaryStartY);
  
  // Add horizontal rule under section title
  doc.setDrawColor(...primaryColor);
  doc.setLineWidth(0.5);
  doc.line(20, summaryStartY + 5, 190, summaryStartY + 5);
  
  // Summary box - white background with subtle border
  doc.setFillColor(255, 255, 255); // Pure white background
  doc.roundedRect(20, summaryStartY + 10, 170, 40, 3, 3, 'F');
  doc.setDrawColor(220/255, 220/255, 220/255); // Light gray border
  doc.setLineWidth(0.3);
  doc.roundedRect(20, summaryStartY + 10, 170, 40, 3, 3, 'S');
  
  // Create three-column layout for stats
  const colWidth = 56;
  const col1X = 25;
  const col2X = col1X + colWidth;
  const col3X = col2X + colWidth;
  const statsY = summaryStartY + 32;
  const statsLabelY = statsY + 10;
  
  // Accuracy
  doc.setFillColor(...primaryColor);
  doc.circle(col1X + 3, statsY - 3, 2, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(...primaryColor);
  doc.text(`${stats.avgAccuracy}%`, col1X + 15, statsY);
  doc.setFontSize(9);
  doc.setTextColor(...textColor);
  doc.text('Average Accuracy', col1X + 3, statsLabelY);
  
  // Completion Time
  doc.setFillColor(...secondaryColor);
  doc.circle(col2X + 3, statsY - 3, 2, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(...secondaryColor);
  doc.text(`${stats.avgCompletionTime}s`, col2X + 15, statsY);
  doc.setFontSize(9);
  doc.setTextColor(...textColor);
  doc.text('Average Completion Time', col2X + 3, statsLabelY);
  
  // Errors
  doc.setFillColor(244/255, 67/255, 54/255); // Red
  doc.circle(col3X + 3, statsY - 3, 2, 'F');
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(244/255, 67/255, 54/255);
  doc.text(`${stats.avgErrors}`, col3X + 15, statsY);
  doc.setFontSize(9);
  doc.setTextColor(...textColor);
  doc.text('Average Errors per Session', col3X + 3, statsLabelY);
  
  // Sessions count info
  doc.setFontSize(10);
  doc.setTextColor(...textColor);
  doc.setFont('helvetica', 'italic');
  doc.text(`Total Sessions: ${stats.totalSessions}`, 25, summaryStartY + 22);
  
  // Performance Trends section
  const trendsStartY = summaryStartY + 60;
  doc.setFontSize(16);
  doc.setTextColor(...textColor);
  doc.setFont('helvetica', 'bold');
  doc.text('Performance Trends Over Time', 20, trendsStartY);
  
  // Add horizontal rule under section title
  doc.setDrawColor(...primaryColor);
  doc.setLineWidth(0.5);
  doc.line(20, trendsStartY + 5, 190, trendsStartY + 5);
  
  // Add graph with border and background (white background, no black border)
  doc.setFillColor(255, 255, 255); // Pure white background
  doc.roundedRect(20, trendsStartY + 10, 170, 90, 3, 3, 'F');
  doc.setDrawColor(220/255, 220/255, 220/255); // Light gray border
  doc.setLineWidth(0.3);
  doc.roundedRect(20, trendsStartY + 10, 170, 90, 3, 3, 'S');
  
  // Insert the graph
  const graphImage = graphCanvas.toDataURL('image/png');
  doc.addImage(graphImage, 'PNG', 22, trendsStartY + 12, 166, 86);
  
  // Add detailed session data section
  doc.addPage();
  
  // Header on second page
  doc.setFillColor(0, 0, 0);
  doc.rect(0, 0, 210, 20, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(14);
  doc.setFont('helvetica', 'bold');
  doc.text('GrowBrain - Student Progress Report', 105, 13, { align: 'center' });
  
  // Session details title
  const detailsStartY = 30;
  doc.setTextColor(...textColor);
  doc.setFontSize(16);
  doc.setFont('helvetica', 'bold');
  doc.text('Detailed Session Data', 20, detailsStartY);
  doc.setDrawColor(...primaryColor);
  doc.setLineWidth(0.5);
  doc.line(20, detailsStartY + 5, 190, detailsStartY + 5);
  
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.setTextColor(...textColor);
  doc.text(`${studentName} - Last ${Math.min(records.length, 20)} Sessions`, 20, detailsStartY + 15);
  
  // Prepare data for auto table
  const tableData = records.slice(0, 20).map(record => {
    // Format date
    let formattedDate = 'N/A';
    if (record.date) {
      if (typeof record.date === 'object' && record.date.toDate) {
        formattedDate = formatDateForReport(record.date.toDate());
      } else if (typeof record.date === 'string') {
        formattedDate = formatDateForReport(new Date(record.date));
      }
    }
    
    // Format challenge focus (truncate if needed)
    let challengeFocus = record.challengeFocus || 'N/A';
    if (challengeFocus.length > 25) {
      challengeFocus = challengeFocus.substring(0, 22) + '...';
    }
    
    return [
      formattedDate,
      challengeFocus,
      record.difficultyText || 'N/A',
      record.accuracy ? record.accuracy + '%' : 'N/A',
      record.completionTime ? record.completionTime.toFixed(2) + ' sec' : 'N/A',
      record.errors || '0'
    ];
  });
  
  // Create table using autoTable
  doc.autoTable({
    startY: detailsStartY + 20,
    head: [['Date', 'Challenge Focus', 'Difficulty', 'Accuracy', 'Time (sec)', 'Errors']],
    body: tableData,
    theme: 'grid',
    headStyles: {
      fillColor: [0, 0, 0],
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      halign: 'left',
      fontSize: 10
    },
    styles: {
      fontSize: 9,
      cellPadding: 3,
      lineColor: [220, 220, 220],
      lineWidth: 0.1
    },
    columnStyles: {
      0: { cellWidth: 35 }, // Date
      1: { cellWidth: 40 }, // Challenge Focus
      2: { cellWidth: 25 }, // Difficulty
      3: { cellWidth: 25 }, // Accuracy
      4: { cellWidth: 25 }, // Time
      5: { cellWidth: 20 }  // Errors
    },
    alternateRowStyles: {
      fillColor: [245, 245, 245]
    },
    margin: { left: 20, right: 20 }
  });
  
  // Add footer with page numbers
  const pageCount = doc.internal.getNumberOfPages();
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFillColor(245, 245, 245);
    doc.rect(0, 280, 210, 17, 'F');
    
    doc.setFontSize(9);
    doc.setTextColor(100, 100, 100);
    doc.text(`Page ${i} of ${pageCount}`, 105, 287, { align: 'center' });
    doc.text('GrowBrain Learning Platform', 20, 287);
    doc.text(`Generated on ${new Date().toLocaleDateString()}`, 190, 287, { align: 'right' });
  }
}

function filterRecords(searchTerm) {
  const rows = document.querySelectorAll('#records-table tbody tr');
  rows.forEach(row => {
    const name = row.querySelector('td:first-child').textContent.toLowerCase();
    row.style.display = name.includes(searchTerm) ? '' : 'none';
  });
}

function viewStudentRecords(studentId, studentName, teacherId) {
  // Update modal header and reset stats
  document.getElementById('records-student-name').textContent = `${studentName}'s Sessions`;
  document.querySelector('#student-records-table tbody').innerHTML = '';
  setLoadingStats();
  document.getElementById('records-modal').style.display = 'block';
  
  // Store current student ID and name for analytics
  currentStudentId = studentId;
  currentStudentName = studentName;
  currentTeacherIdForRecords = teacherId;
  // enable auto download from cached records when user clicked Report from list
  window._autoDownloadAfterLoad = window._autoDownloadAfterLoad === true;
  
  // First try to get records from the teacher's student collection
  db.collection('teachers').doc(teacherId).collection('students').doc(studentId).collection('records')
    .orderBy('date', 'desc')
    .get()
    .then(function(querySnapshot) {
      const tbody = document.querySelector('#student-records-table tbody');
      
      if (querySnapshot.empty) {
        // Fallback 1: student document keyed by name
        if (studentName && studentName !== studentId) {
          db.collection('teachers').doc(teacherId).collection('students').doc(studentName).collection('records')
            .orderBy('date', 'desc')
            .get()
            .then(function(altSnapshot) {
              if (altSnapshot.empty) {
                // Fallback 2: legacy top-level gameRecords for this student (client-side sort)
                loadFromGameRecords(studentName, tbody);
                return;
              }
              const stats = processStudentRecords(altSnapshot, tbody);
              updateRecordStats(stats);
            })
            .catch(function(err) {
              console.error('Fallback by-name records query failed:', err);
              loadFromGameRecords(studentName, tbody);
            });
          return;
        } else {
          // Fallback to legacy top-level gameRecords
          loadFromGameRecords(studentName, tbody);
          return;
        }
      }
      
      const stats = processStudentRecords(querySnapshot, tbody);
      updateRecordStats(stats);
    })
    .catch(function(error) {
      console.error("Error getting student records from teacher collection: ", error);
      // Fallback to legacy top-level gameRecords in case of errors like missing index or rules
      loadFromGameRecords(studentName, document.querySelector('#student-records-table tbody'));
    });
}

// Fallback function to load from gameRecords collection
function loadFromGameRecords(studentName, tbody) {
  // Primary query (fast path): requires a composite index
  db.collection('gameRecords')
    .where('studentName', '==', studentName)
    .orderBy('date', 'desc')
    .get()
    .then(function(querySnapshot) {
      if (querySnapshot.empty) {
        handleEmptyRecords(tbody);
        return;
      }

      const stats = processStudentRecords(querySnapshot, tbody);
      updateRecordStats(stats);
    })
    .catch(function(error) {
      // Graceful fallback: if index is missing, run without orderBy and sort on client
      const requiresIndex =
        (error && (error.code === 'failed-precondition' || error.code === 'permission-denied')) ||
        (error && typeof error.message === 'string' && error.message.toLowerCase().includes('requires an index'));

      if (!requiresIndex) {
        console.error('Error getting student records from gameRecords: ', error);
        showError(error.message);
        return;
      }

      // Fallback query that does not need a composite index
      db.collection('gameRecords')
        .where('studentName', '==', studentName)
        .get()
        .then(function(snapshot) {
          if (snapshot.empty) {
            handleEmptyRecords(tbody);
            return;
          }

          // Sort documents by date (desc) on the client
          const docsSorted = snapshot.docs.slice().sort((a, b) => {
            const da = a.data().date;
            const dbv = b.data().date;

            const dateA = da && typeof da === 'object' && da.toDate ? da.toDate() : (da ? new Date(da) : new Date(0));
            const dateB = dbv && typeof dbv === 'object' && dbv.toDate ? dbv.toDate() : (dbv ? new Date(dbv) : new Date(0));
            return dateB - dateA; // newest first
          });

          // Create a lightweight iterable to reuse processStudentRecords
          const pseudoSnapshot = {
            forEach: (cb) => docsSorted.forEach(cb)
          };

          const stats = processStudentRecords(pseudoSnapshot, tbody);
          updateRecordStats(stats);

          // Also inform in console that creating the index will speed this up
          console.warn('Firestore composite index missing for gameRecords(studentName ==, orderBy date desc). Falling back to client-side sort. Create the index for better performance.');
        })
        .catch(function(fallbackError) {
          console.error('Fallback loadFromGameRecords failed: ', fallbackError);
          showError(fallbackError.message);
        });
    });
}

function setLoadingStats() {
  document.getElementById('avg-completion-time').textContent = 'Loading...';
  document.getElementById('avg-accuracy').textContent = 'Loading...';
}

function handleEmptyRecords(tbody) {
  tbody.innerHTML = '<tr><td colspan="6" class="no-records">No sessions found for this student.</td></tr>';
  document.getElementById('avg-completion-time').textContent = '0.00 sec';
  document.getElementById('avg-accuracy').textContent = '0.0%';
}

function processStudentRecords(querySnapshot, tbody) {
  let totalCompletionTime = 0;
  let totalAccuracy = 0;
  let count = 0;
  const cached = [];
  
  querySnapshot.forEach(function(doc) {
    const record = doc.data();
    const row = createRecordRow(record);
    tbody.appendChild(row);
    cached.push(record);
    
    // Update stats
    if (record.completionTime) {
      totalCompletionTime += parseFloat(record.completionTime);
      count++;
    }
    if (record.accuracy) {
      totalAccuracy += parseFloat(record.accuracy);
    }
  });
  
  // Save cache for force-download fallback
  window._cachedStudentRecords = cached;
  window._cachedStudentName = currentStudentName;
  window._cachedStudentMeta = { studentId: currentStudentId, teacherId: currentTeacherIdForRecords };

  // Auto-generate report if requested
  if (window._autoDownloadAfterLoad) {
    try {
      const pseudoSnapshot = {
        forEach: (cb) => cached.forEach(r => cb({ data: () => r }))
      };
      const { records, stats, trends } = processRecordsForReport(pseudoSnapshot);
      if (window._autoDownloadAfterLoad === 'excel') {
        // generate CSV instead of PDF
        window._cachedStudentRecords = cached;
        downloadExcelFromCache(window._cachedStudentName || 'Student');
      } else {
        createPerformanceGraph(trends).then((graphCanvas) => {
          const { jsPDF } = window.jspdf;
          const doc = new jsPDF();
          generatePDFContent(doc, window._cachedStudentName || 'Student', {}, stats, graphCanvas, records);
          doc.save(`${(window._cachedStudentName || 'Student')}_progress_report.pdf`);
          showResultMessage('Report downloaded successfully!', false);
        });
      }
    } catch (e) {
      console.error('Auto report generation error:', e);
      showResultMessage('Error generating report', true);
    } finally {
      window._autoDownloadAfterLoad = false;
    }
  }

  return { totalCompletionTime, totalAccuracy, count };
}

function createRecordRow(record) {
  let dateObj;
  
  // Check if the date is a Firestore timestamp
  if (record.date && typeof record.date === 'object' && record.date.toDate) {
    dateObj = record.date.toDate();
  } 
  // Check if the date is a string (ISO format from Flutter)
  else if (record.date && typeof record.date === 'string') {
    dateObj = new Date(record.date);
  } 
  // Fallback to current date
  else {
    dateObj = new Date();
  }
  
  // Map difficulty values from Flutter app
  const difficultyMap = {
    'Easy': 'Starter',
    'Medium': 'Growing', 
    'Hard': 'Challenged'
  };
  
  const displayDifficulty = difficultyMap[record.difficulty] || record.difficulty || 'N/A';
  
  const row = document.createElement('tr');
  row.innerHTML = `
    <td>${formatDate(dateObj)}</td>
    <td>${record.challengeFocus || 'N/A'}</td>
    <td>${record.game || 'N/A'}</td>
    <td>${displayDifficulty}</td>
    <td>${record.accuracy ? parseFloat(record.accuracy).toFixed(1) + '%' : 'N/A'}</td>
    <td>${record.completionTime ? parseFloat(record.completionTime).toFixed(2) + ' sec' : 'N/A'}</td>
    <td>${record.lastPlayed || record.game || 'N/A'}</td>`;
  
  return row;
}

function updateRecordStats({ totalCompletionTime, totalAccuracy, count }) {
  if (count > 0) {
    const avgCompletionTime = (totalCompletionTime / count).toFixed(2);
    const avgAccuracy = (totalAccuracy / count).toFixed(1);
    
    document.getElementById('avg-completion-time').textContent = `${avgCompletionTime} sec`;
    document.getElementById('avg-accuracy').textContent = `${avgAccuracy}%`;
  } else {
    document.getElementById('avg-completion-time').textContent = '0.00 sec';
    document.getElementById('avg-accuracy').textContent = '0.0%';
  }
}

function showError(message) {
  document.querySelector('#student-records-table tbody').innerHTML = 
    `<tr><td colspan="6" class="error-message">Error loading records: ${message}</td></tr>`;
}

// Force download uses already loaded records from the modal (no extra Firestore reads)
function forceDownloadFromModal(studentName) {
  if (Array.isArray(window._cachedStudentRecords) && window._cachedStudentRecords.length > 0) {
    try {
      const pseudoSnapshot = {
        forEach: (cb) => window._cachedStudentRecords.forEach(r => cb({ data: () => r }))
      };
      const { records, stats, trends } = processRecordsForReport(pseudoSnapshot);
      (async () => {
        const graphCanvas = await createPerformanceGraph(trends);
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();
        const displayName = studentName || window._cachedStudentName || 'Student';
        generatePDFContent(doc, displayName, {}, stats, graphCanvas, records);
        doc.save(`${displayName}_progress_report.pdf`);
        showResultMessage('Report downloaded successfully!', false);
      })();
    } catch (e) {
      console.error('Force download error:', e);
      showResultMessage('Error generating report', true);
    }
  } else {
    // If no cache yet, trigger loading then auto download once data arrives
    window._autoDownloadAfterLoad = true;
    const tbody = document.querySelector('#student-records-table tbody');
    if (tbody) {
      tbody.innerHTML = '<tr><td colspan="6" class="loading-message">Loading sessions before generating PDF...</td></tr>';
    }
    // Opening the modal again will cause viewStudentRecords to run and cache data
    if (currentStudentId && currentStudentName && currentTeacherIdForRecords) {
      viewStudentRecords(currentStudentId, currentStudentName, currentTeacherIdForRecords);
    }
  }
}

// Context menu for choosing PDF or Excel
function openDownloadMenu(event, studentId, studentName, teacherId) {
  event.preventDefault();
  // Ensure records will be cached by opening modal if needed
  currentStudentId = studentId;
  currentStudentName = studentName;
  currentTeacherIdForRecords = teacherId;

  // Build simple popup menu
  closeDownloadMenu();
  const menu = document.createElement('div');
  menu.id = 'download-menu-popup';
  menu.style.position = 'absolute';
  menu.style.zIndex = '9999';
  menu.style.background = '#fff';
  menu.style.border = '1px solid #ddd';
  menu.style.borderRadius = '6px';
  menu.style.boxShadow = '0 6px 16px rgba(0,0,0,0.15)';
  menu.style.minWidth = '200px';
  menu.style.fontSize = '14px';
  menu.style.color = '#333';
  menu.innerHTML = `
    <div id="download-pdf-btn" style="display:flex;align-items:center;gap:10px;width:100%;padding:10px 14px;cursor:pointer;color:#333;">
      <i class="fas fa-file-pdf" style="color:#e53935;width:18px;text-align:center"></i>
      <span>Download PDF</span>
    </div>
    <div id="download-excel-btn" style="display:flex;align-items:center;gap:10px;width:100%;padding:10px 14px;border-top:1px solid #eee;cursor:pointer;color:#333;">
      <i class="fas fa-file-excel" style="color:#2e7d32;width:18px;text-align:center"></i>
      <span>Download Excel (CSV)</span>
    </div>
  `;
  document.body.appendChild(menu);

  const rect = event.currentTarget.getBoundingClientRect();
  menu.style.top = `${rect.bottom + window.scrollY + 6}px`;
  menu.style.left = `${rect.left + window.scrollX}px`;

  document.getElementById('download-pdf-btn').onclick = () => {
    closeDownloadMenu();
    forceDownloadFromModal(studentName);
  };
  document.getElementById('download-excel-btn').onclick = () => {
    closeDownloadMenu();
    downloadExcelFromCache(studentName);
  };

  // Close when clicking outside
  setTimeout(() => {
    document.addEventListener('click', closeDownloadMenuOnce, { once: true });
  }, 0);
}

function closeDownloadMenuOnce(e) {
  closeDownloadMenu();
}

function closeDownloadMenu() {
  const existing = document.getElementById('download-menu-popup');
  if (existing && existing.parentNode) existing.parentNode.removeChild(existing);
}

// Generate Excel (CSV) from cached records
function downloadExcelFromCache(studentName) {
  const records = Array.isArray(window._cachedStudentRecords) ? window._cachedStudentRecords : [];
  if (!records.length) {
    // If no cache, load then retry via auto flag
    window._autoDownloadAfterLoad = 'excel';
    if (currentStudentId && currentStudentName && currentTeacherIdForRecords) {
      viewStudentRecords(currentStudentId, currentStudentName, currentTeacherIdForRecords);
    }
    return;
  }

  const headers = ['Date','Challenge Focus','Game','Difficulty','Accuracy','Completion Time','Errors','Last Played'];
  const toDateStr = (v) => {
    try {
      if (v && typeof v === 'object' && v.toDate) return v.toDate().toISOString();
      if (typeof v === 'string') return new Date(v).toISOString();
    } catch (_) {}
    return '';
  };
  const rows = records.map(r => [
    toDateStr(r.date),
    r.challengeFocus || '',
    r.game || r.gameKey || '',
    r.difficulty || r.difficultyText || '',
    r.accuracy ?? '',
    r.completionTime ?? '',
    r.errors ?? '',
    r.lastPlayed || ''
  ]);

  const csv = [headers, ...rows].map(r => r.map(escapeCsv).join(',')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${studentName || 'Student'}_records.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showResultMessage('Excel (CSV) downloaded successfully!', false);
}

function escapeCsv(val) {
  const s = (val === null || val === undefined) ? '' : String(val);
  if (s.includes(',') || s.includes('\"') || s.includes('\n')) {
    return '"' + s.replace(/\"/g, '""') + '"';
  }
  return s;
}

// ------------------------------
// Dashboard Teacher Count
// ------------------------------
function loadTeacherCount() {
  db.collection('teachers').get()
    .then(snapshot => {
      document.getElementById('active-teachers').textContent = snapshot.size;
    })
    .catch(error => {
      console.error("Error loading teacher count:", error);
    });
}

// ------------------------------
// Activities Section Functions
// ------------------------------
function loadActivities() {
  const activitiesTable = document.getElementById('activities-table');
  if (!activitiesTable) return;
  
  const tbody = activitiesTable.querySelector('tbody');
  tbody.innerHTML = '<tr><td colspan="7" class="loading-message">Loading activities data...</td></tr>';
  
  // Get gameRecords collection from Firestore
  db.collection('gameRecords')
    .orderBy('date', 'desc')
    .get()
    .then((querySnapshot) => {
      if (querySnapshot.empty) {
        tbody.innerHTML = '<tr><td colspan="7" class="empty-message">No activities found</td></tr>';
        return;
      }
      
      tbody.innerHTML = '';
      querySnapshot.forEach((doc) => {
        const data = doc.data();
        const tr = createActivityRow(data);
        tbody.appendChild(tr);
      });
    })
    .catch((error) => {
      console.error("Error loading activities: ", error);
      tbody.innerHTML = `<tr><td colspan="7" class="error-message">Error loading activities: ${error.message}</td></tr>`;
    });
}

function createActivityRow(activity) {
  const tr = document.createElement('tr');
  
  // Format date and time for display
  const date = activity.date ? formatDate(new Date(activity.date)) : 'N/A';
  const lastPlayed = activity.lastPlayed ? formatDate(new Date(activity.lastPlayed)) : 'N/A';
  
  // Format accuracy as percentage
  const accuracy = activity.accuracy !== undefined ? `${activity.accuracy}%` : 'N/A';
  
  // Format completion time in seconds
  const completionTime = activity.completionTime !== undefined ? 
    `${activity.completionTime} sec` : 'N/A';
  
  tr.innerHTML = `
    <td>${activity.studentName || 'Unknown'}</td>
    <td>${activity.challengeFocus || 'N/A'}</td>
    <td>${accuracy}</td>
    <td>${completionTime}</td>
    <td>${activity.difficulty || 'N/A'}</td>
    <td>${date}</td>
    <td>${lastPlayed}</td>
  `;
  
  return tr;
}

function filterActivities(searchTerm) {
  const rows = document.querySelectorAll('#activities-table tbody tr');
  rows.forEach(row => {
    const studentName = row.cells[0].textContent.toLowerCase();
    const challengeFocus = row.cells[1].textContent.toLowerCase();
    if (studentName.includes(searchTerm) || challengeFocus.includes(searchTerm)) {
      row.style.display = '';
    } else {
      row.style.display = 'none';
    }
  });
}

// Global variables for student analytics tracking
let currentStudentId = null;
let currentStudentName = null;
let currentTeacherIdForRecords = null;

// ------------------------------
// Initialize Detailed Analytics Modal
// ------------------------------
function initStudentAnalyticsModal() {
  // Get elements
  const viewAnalyticsBtn = document.getElementById('view-detailed-analytics-btn');
  const analyticsModal = document.getElementById('student-analytics-modal');
  const analyticsModalClose = document.getElementById('analytics-modal-close');
  
  // Add event listener to the detailed analytics button
  if (viewAnalyticsBtn) {
    viewAnalyticsBtn.addEventListener('click', function() {
      if (currentStudentId) {
        openStudentAnalytics(currentStudentId, currentStudentName);
      }
    });
  }
  
  // Close the analytics modal when clicking the close button
  if (analyticsModalClose) {
    analyticsModalClose.addEventListener('click', function() {
      analyticsModal.style.display = 'none';
    });
  }
  
  // Close the analytics modal when clicking outside the modal content
  window.addEventListener('click', function(e) {
    if (e.target === analyticsModal) {
      analyticsModal.style.display = 'none';
    }
  });
}

function openStudentAnalytics(studentId, studentName) {
  const analyticsModal = document.getElementById('student-analytics-modal');
  document.getElementById('student-name-display').textContent = studentName;
  
  // Show the modal and begin loading data
  analyticsModal.style.display = 'block';
  
  // Reset charts and data
  resetAnalyticsData();
  
  // Make sure scroll is at top when opening
  setTimeout(() => {
    const modalContent = document.querySelector('.analytics-modal-content');
    if (modalContent) {
      modalContent.scrollTop = 0;
    }
    
    // Add resize handler for charts
    const resizeObserver = new ResizeObserver(() => {
      if (window.accuracyChart) window.accuracyChart.resize();
      if (window.completionTimeChart) window.completionTimeChart.resize();
      if (window.performanceChart) window.performanceChart.resize();
    });
    
    // Observe main chart containers
    document.querySelectorAll('.analytics-chart-card, .performance-chart-container').forEach(el => {
      resizeObserver.observe(el);
    });
    
    // Load student analytics data
    loadStudentAnalyticsData(studentId, studentName);
    
    // Clean up observer when modal is closed
    const closeBtn = document.getElementById('analytics-modal-close');
    if (closeBtn) {
      const originalCloseHandler = closeBtn.onclick;
      closeBtn.onclick = function() {
        resizeObserver.disconnect();
        if (originalCloseHandler) originalCloseHandler();
        analyticsModal.style.display = 'none';
      };
    }
  }, 10);
}

function resetAnalyticsData() {
  // Reset statistics
  document.getElementById('avg-accuracy-percent').textContent = 'Loading...';
  document.getElementById('avg-completion-seconds').textContent = 'Loading...';
  document.getElementById('total-sessions-count').textContent = 'Loading...';
  document.getElementById('total-sessions-display').textContent = 'Loading...';
  document.getElementById('challenge-categories-display').textContent = 'Loading...';
  document.getElementById('recent-sessions-list').innerHTML = '<p>Loading recent sessions...</p>';
}

function loadStudentAnalyticsData(studentId, studentName) {
  const teacherId = currentTeacherIdForRecords || (window.teacherSwitcher ? window.teacherSwitcher.getCurrentTeacherId() : null);
  if (!teacherId) {
    handleEmptyAnalytics();
    return;
  }

  const loadFromDoc = (docId) => db.collection('teachers')
    .doc(teacherId)
    .collection('students')
    .doc(docId)
    .collection('records')
    .orderBy('date', 'desc')
    .get();

  loadFromDoc(studentId)
    .then(function(querySnapshot) {
      if (querySnapshot.empty && studentName && studentName !== studentId) {
        // Fallback: try by-name document id
        return loadFromDoc(studentName).then((alt) => ({ alt, usedAlt: true }));
      }
      return { alt: querySnapshot, usedAlt: false };
    })
    .then(function(result) {
      let snapshot = result.alt;
      const processSnapshot = (snap) => {
        // Process the data
        const sessions = [];
        const challengeCategories = new Set();
        let totalAccuracy = 0;
        let totalCompletionTime = 0;

        snap.forEach(doc => {
          const session = doc.data();
          session.id = doc.id;

          if (session.date) {
            session.originalDate = session.date;
          }

          sessions.push(session);

          if (session.challengeFocus) {
            challengeCategories.add(session.challengeFocus);
          }

          totalAccuracy += session.accuracy || 0;
          totalCompletionTime += session.completionTime || 0;
        });

        const sessionCount = sessions.length;
        const avgAccuracy = sessionCount > 0 ? (totalAccuracy / sessionCount).toFixed(2) : 0;
        const avgCompletionTime = sessionCount > 0 ? (totalCompletionTime / sessionCount).toFixed(2) : 0;

        updateAnalyticsUI(sessions, avgAccuracy, avgCompletionTime, sessionCount, challengeCategories);
        generateAnalyticsCharts(sessions);
      };

      if (!snapshot.empty) {
        processSnapshot(snapshot);
        return;
      }

      // Legacy fallbacks: root students/{id}/sessions
      db.collection('students').doc(studentId).collection('sessions')
        .orderBy('date','desc')
        .get()
        .then((legacy) => {
          if (!legacy.empty) {
            processSnapshot(legacy);
            return;
          }
          if (studentName && studentName !== studentId) {
            return db.collection('students').doc(studentName).collection('sessions').orderBy('date','desc').get()
              .then((legacyByName) => {
                if (!legacyByName.empty) {
                  processSnapshot(legacyByName);
                  return;
                }
                handleEmptyAnalytics();
              });
          }
          handleEmptyAnalytics();
        })
        .catch(() => handleEmptyAnalytics());
    })
    .catch(function(error) {
      console.error('Error getting student analytics data: ', error);
      handleEmptyAnalytics();
    });
}

function updateAnalyticsUI(sessions, avgAccuracy, avgCompletionTime, sessionCount, challengeCategories) {
  // Update statistics
  document.getElementById('avg-accuracy-percent').textContent = `${avgAccuracy}%`;
  document.getElementById('avg-completion-seconds').textContent = `${avgCompletionTime} sec`;
  document.getElementById('total-sessions-count').textContent = sessionCount;
  document.getElementById('total-sessions-display').textContent = sessionCount;
  document.getElementById('challenge-categories-display').textContent = 
    Array.from(challengeCategories).join(', ') || 'None';
  
  // Update recent sessions list (show up to 5 most recent)
  const recentSessionsList = document.getElementById('recent-sessions-list');
  recentSessionsList.innerHTML = '';
  
  const recentSessions = sessions.slice(0, 5);
  if (recentSessions.length === 0) {
    recentSessionsList.innerHTML = '<p>No recent sessions found.</p>';
  } else {
    recentSessions.forEach(session => {
      let sessionDate;
      
      // Handle different date formats
      if (session.date && typeof session.date === 'object' && session.date.seconds) {
        // Firestore timestamp
        sessionDate = new Date(session.date.seconds * 1000);
      } else if (session.date && typeof session.date === 'string') {
        // String date
        sessionDate = new Date(session.date);
      } else {
        // Default
        sessionDate = new Date();
      }
      
      const formattedDate = sessionDate.toLocaleDateString();
      
      const sessionItem = document.createElement('div');
      sessionItem.className = 'recent-session-item';
      sessionItem.innerHTML = `
        <div class="session-date">${formattedDate}</div>
        <div class="session-game">${session.game || session.gameKey || 'Unknown Game'}</div>
        <div class="session-stats">
          <span class="accuracy">${session.accuracy || 0}%</span> accuracy, 
          <span class="time">${session.completionTime || 0} sec</span>
        </div>
      `;
      
      recentSessionsList.appendChild(sessionItem);
    });
  }
}

function generateAnalyticsCharts(sessions) {
  // Set a short timeout to ensure the DOM is ready and containers are properly sized
  setTimeout(() => {
    generateAccuracyChart(sessions);
    generateCompletionTimeChart(sessions);
    generatePerformanceChart(sessions);
  }, 100);
}

function generateAccuracyChart(sessions) {
  const ctx = document.getElementById('accuracy-chart');
  if (!ctx) return;
  
  // Sort sessions by date (oldest first for timeline)
  const sortedSessions = [...sessions].sort((a, b) => {
    const dateA = a.date && a.date.seconds ? a.date.seconds : (a.date ? new Date(a.date).getTime() / 1000 : 0);
    const dateB = b.date && b.date.seconds ? b.date.seconds : (b.date ? new Date(b.date).getTime() / 1000 : 0);
    return dateA - dateB;
  });
  
  // Prepare data
  const labels = sortedSessions.map(session => {
    // Format the date properly to avoid "Invalid Date"
    if (session.date) {
      let date;
      if (typeof session.date === 'object' && session.date.seconds) {
        // Handle Firestore timestamp
        date = new Date(session.date.seconds * 1000);
      } else if (typeof session.date === 'string') {
        // Handle date string
        date = new Date(session.date);
      } else {
        // Fallback
        return 'No date';
      }
      
      if (!isNaN(date.getTime())) {
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      }
    }
    return 'Unknown';
  });
  
  const data = sortedSessions.map(session => session.accuracy || 0);
  
  // Create chart
  if (window.accuracyChart) {
    window.accuracyChart.destroy();
  }
  
  window.accuracyChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Accuracy (%)',
        data: data,
        borderColor: '#4CAF50',
        backgroundColor: 'rgba(76, 175, 80, 0.1)',
        borderWidth: 2,
        pointRadius: 4,
        pointBackgroundColor: '#4CAF50',
        fill: true,
        tension: 0.4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'top',
          labels: {
            boxWidth: 12,
            padding: 10,
            font: {
              size: 11
            }
          }
        },
        tooltip: {
          mode: 'index',
          intersect: false,
          titleFont: {
            size: 12
          },
          bodyFont: {
            size: 11
          },
          padding: 8
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          max: 100,
          ticks: {
            callback: function(value) {
              return value + '%';
            },
            font: {
              size: 10
            }
          }
        },
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 45,
            font: {
              size: 9
            }
          }
        }
      }
    }
  });
}

function generateCompletionTimeChart(sessions) {
  const ctx = document.getElementById('completion-time-chart');
  if (!ctx) return;
  
  // Sort sessions by date (oldest first for timeline)
  const sortedSessions = [...sessions].sort((a, b) => {
    const dateA = a.date && a.date.seconds ? a.date.seconds : (a.date ? new Date(a.date).getTime() / 1000 : 0);
    const dateB = b.date && b.date.seconds ? b.date.seconds : (b.date ? new Date(b.date).getTime() / 1000 : 0);
    return dateA - dateB;
  });
  
  // Prepare data
  const labels = sortedSessions.map(session => {
    // Format the date properly to avoid "Invalid Date"
    if (session.date) {
      let date;
      if (typeof session.date === 'object' && session.date.seconds) {
        // Handle Firestore timestamp
        date = new Date(session.date.seconds * 1000);
      } else if (typeof session.date === 'string') {
        // Handle date string
        date = new Date(session.date);
      } else {
        // Fallback
        return 'No date';
      }
      
      if (!isNaN(date.getTime())) {
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      }
    }
    return 'Unknown';
  });
  
  const data = sortedSessions.map(session => session.completionTime || 0);
  
  // Create chart
  if (window.completionTimeChart) {
    window.completionTimeChart.destroy();
  }
  
  window.completionTimeChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Completion Time (sec)',
        data: data,
        borderColor: '#2196F3',
        backgroundColor: 'rgba(33, 150, 243, 0.1)',
        borderWidth: 2,
        pointRadius: 4,
        pointBackgroundColor: '#2196F3',
        fill: true,
        tension: 0.4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'top',
          labels: {
            boxWidth: 12,
            padding: 10,
            font: {
              size: 11
            }
          }
        },
        tooltip: {
          mode: 'index',
          intersect: false,
          titleFont: {
            size: 12
          },
          bodyFont: {
            size: 11
          },
          padding: 8
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            callback: function(value) {
              return value + ' sec';
            },
            font: {
              size: 10
            }
          }
        },
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 45,
            font: {
              size: 9
            }
          }
        }
      }
    }
  });
}

function generatePerformanceChart(sessions) {
  const ctx = document.getElementById('performance-chart');
  if (!ctx) return;
  
  // Count sessions by challenge focus
  const challengeCounts = {};
  sessions.forEach(session => {
    const focus = session.challengeFocus || 'Unknown';
    challengeCounts[focus] = (challengeCounts[focus] || 0) + 1;
  });
  
  // Prepare data
  const labels = Object.keys(challengeCounts);
  const data = Object.values(challengeCounts);
  const backgroundColors = [
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#FFC107', // Amber
    '#FF5722', // Deep Orange
    '#9C27B0'  // Purple
  ];
  
  // Create chart
  if (window.performanceChart) {
    window.performanceChart.destroy();
  }
  
  window.performanceChart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: labels,
      datasets: [{
        data: data,
        backgroundColor: backgroundColors,
        borderWidth: 1
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: '65%',
      layout: {
        padding: {
          top: 5,
          bottom: 5
        }
      },
      plugins: {
        legend: {
          position: 'right',
          labels: {
            padding: 10,
            boxWidth: 10,
            font: {
              size: 10
            }
          }
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              const label = context.label || '';
              const value = context.raw || 0;
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = Math.round((value / total) * 100);
              return `${label}: ${value} (${percentage}%)`;
            }
          },
          titleFont: {
            size: 12
          },
          bodyFont: {
            size: 11
          },
          padding: 8
        }
      }
    }
  });
}

function handleEmptyAnalytics() {
  // Update UI for no data
  document.getElementById('avg-accuracy-percent').textContent = '0%';
  document.getElementById('avg-completion-seconds').textContent = '0 sec';
  document.getElementById('total-sessions-count').textContent = '0';
  document.getElementById('total-sessions-display').textContent = '0';
  document.getElementById('challenge-categories-display').textContent = 'None';
  document.getElementById('recent-sessions-list').innerHTML = '<p>No sessions found for this student.</p>';
  
  // Create empty charts
  generateAnalyticsCharts([]);
}

function handleAnalyticsError(error) {
  console.error("Analytics error:", error);
  document.getElementById('recent-sessions-list').innerHTML = 
    `<p class="error-message">Error loading analytics: ${error.message}</p>`;
}
