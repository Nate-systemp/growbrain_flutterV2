// Updated viewStudentRecords function with fallback to gameRecords
function viewStudentRecords(studentId, studentName, teacherId) {
  // Update modal header and reset stats
  document.getElementById('records-student-name').textContent = `${studentName}'s Sessions`;
  document.querySelector('#student-records-table tbody').innerHTML = '';
  setLoadingStats();
  document.getElementById('records-modal').style.display = 'block';
  
  // Store current student ID and name for analytics
  currentStudentId = studentId;
  currentStudentName = studentName;
  
  // First try to get records from the teacher's student collection
  db.collection('teachers').doc(teacherId).collection('students').doc(studentId).collection('records')
    .orderBy('date', 'desc')
    .get()
    .then(function(querySnapshot) {
      const tbody = document.querySelector('#student-records-table tbody');
      
      if (querySnapshot.empty) {
        // If no records in teacher's collection, try the main gameRecords collection
        console.log('No records in teacher collection, checking gameRecords...');
        loadFromGameRecords(studentName, tbody);
        return;
      }
      
      const stats = processStudentRecords(querySnapshot, tbody);
      updateRecordStats(stats);
    })
    .catch(function(error) {
      console.error("Error getting student records from teacher collection: ", error);
      // Fallback to gameRecords collection
      loadFromGameRecords(studentName, document.querySelector('#student-records-table tbody'));
    });
}

// Fallback function to load from gameRecords collection
function loadFromGameRecords(studentName, tbody) {
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
      console.error("Error getting student records from gameRecords: ", error);
      showError(error.message);
    });
}