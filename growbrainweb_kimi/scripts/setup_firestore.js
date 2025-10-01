// setup_firestore.js - Helper script to initialize Firestore database structure
// Run this script once to create the necessary collections and indexes

document.addEventListener('DOMContentLoaded', function() {
  // Legacy gameRecords bootstrap removed. The Flutter app writes to
  // teachers/{teacherId}/students/{studentId}/records, which the web UI now reads.
  console.log('Firestore setup: skipping legacy gameRecords seeding.');
});