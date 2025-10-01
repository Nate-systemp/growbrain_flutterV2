// add_admin.js - Handles adding new admin users with Firebase

document.addEventListener('DOMContentLoaded', function() {
    // Get form elements
    const adminForm = document.getElementById('admin-form');
    const usernameInput = document.getElementById('admin-username');
    const passwordInput = document.getElementById('admin-password');
    const addAdminModal = document.getElementById('add-admin-modal');
    const addAdminModalClose = document.getElementById('add-admin-modal-close');
    const addAdminCancel = document.getElementById('add-admin-cancel');
    const addAdminButton = document.getElementById('add-admin-button');
    
    // Show modal when add button is clicked
    if (addAdminButton) {
        addAdminButton.addEventListener('click', function() {
            if (addAdminModal) {
                addAdminModal.style.display = 'block';
            }
        });
    }
    
    // Close modal when close button is clicked
    if (addAdminModalClose) {
        addAdminModalClose.addEventListener('click', function() {
            if (addAdminModal) {
                addAdminModal.style.display = 'none';
            }
        });
    }
    
    // Close modal when cancel button is clicked
    if (addAdminCancel) {
        addAdminCancel.addEventListener('click', function() {
            if (addAdminModal) {
                addAdminModal.style.display = 'none';
            }
        });
    }
    
    // Close modal when clicking outside of it
    window.addEventListener('click', function(event) {
        if (event.target === addAdminModal) {
            addAdminModal.style.display = 'none';
        }
    });
    
    // Handle form submission
    if (adminForm) {
        adminForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const username = usernameInput.value.trim();
            const password = passwordInput.value.trim();
            
            // Basic validation
            if (!username || !password) {
                showMessage('error', 'Username and password are required');
                return;
            }
            
            // Show loading state
            const submitButton = adminForm.querySelector('button[type="submit"]');
            const originalButtonText = submitButton.innerHTML;
            submitButton.innerHTML = '<span class="loading-spinner"></span> Adding...';
            submitButton.disabled = true;
            
            // Get Firestore reference
            const db = firebase.firestore();
            
            // Check if username already exists
            db.collection('growbrainadminAuth').where('username', '==', username)
                .get()
                .then((querySnapshot) => {
                    if (!querySnapshot.empty) {
                        throw new Error('Username already exists');
                    }
                    
                    // Create new admin document
                    return db.collection('growbrainadminAuth').add({
                        username: username,
                        password: password, // Note: In production, use proper password hashing
                        profilePicture: 'img/ITFRAME.jpg',
                        createdAt: new Date()
                    });
                })
                .then(() => {
                    // Show success message
                    showMessage('success', 'Admin added successfully');
                    
                    // Reset form and close modal
                    adminForm.reset();
                    if (addAdminModal) {
                        addAdminModal.style.display = 'none';
                    }
                    
                    // Refresh admin list
                    refreshAdminList();
                })
                .catch((error) => {
                    console.error('Error adding admin:', error);
                    showMessage('error', 'Error adding admin: ' + error.message);
                })
                .finally(() => {
                    // Reset button state
                    submitButton.innerHTML = originalButtonText;
                    submitButton.disabled = false;
                });
        });
    }
    
    // Function to refresh the admin list
    function refreshAdminList() {
        const adminList = document.getElementById('admin-list');
        const adminCount = document.getElementById('admin-count');
        
        if (!adminList || !adminCount) return;
        
        const db = firebase.firestore();
        db.collection('growbrainadminAuth').get()
            .then((querySnapshot) => {
                adminCount.textContent = querySnapshot.size;
                adminList.innerHTML = '';
                
                querySnapshot.forEach((doc) => {
                    const adminData = doc.data();
                    const username = adminData.username;
                    const profilePic = adminData.profilePicture || 'img/default image.jpg';
                    
                    const li = document.createElement('li');
                    li.innerHTML = `
                        <div class='admin-profile-wrap'>
                            <img src='${profilePic}' alt='Profile Picture of ${username}' class='admin-profile-pic' />
                        </div>
                        <span class='admin-username'>${username}</span>
                    `;
                    adminList.appendChild(li);
                });
            })
            .catch((error) => {
                console.error('Error getting admin list:', error);
            });
    }
    
    // Function to show messages
    function showMessage(type, message) {
        // Check if result window exists, if not create it
        let resultWindow = document.getElementById('result-window');
        if (!resultWindow) {
            resultWindow = document.createElement('div');
            resultWindow.id = 'result-window';
            resultWindow.className = 'result-window';
            
            const resultMessage = document.createElement('span');
            resultMessage.id = 'result-message';
            
            const closeButton = document.createElement('button');
            closeButton.id = 'close-result-btn';
            closeButton.innerHTML = '&times;';
            closeButton.addEventListener('click', function() {
                resultWindow.style.display = 'none';
            });
            
            resultWindow.appendChild(resultMessage);
            resultWindow.appendChild(closeButton);
            document.body.appendChild(resultWindow);
        }
        
        // Set message and show
        const resultMessage = document.getElementById('result-message');
        resultMessage.textContent = message;
        resultWindow.className = 'result-window ' + type;
        resultWindow.style.display = 'flex';
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            resultWindow.style.display = 'none';
        }, 5000);
    }
    
    // Initial load of admin list
    refreshAdminList();
}); 