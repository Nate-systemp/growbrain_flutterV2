// admin_profile.js - Handles admin profile updates with Firebase

document.addEventListener('DOMContentLoaded', function() {
    // Get form elements
    const profileForm = document.getElementById('profile-form');
    const usernameInput = document.getElementById('profile-username');
    const passwordInput = document.getElementById('profile-password');
    const profilePictureInput = document.getElementById('profile-picture');
    const profilePicturePreview = document.getElementById('profile-picture-preview-img');
    
    // Handle form submission
    if (profileForm) {
        profileForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const username = usernameInput.value.trim();
            const password = passwordInput.value.trim();
            const currentUsername = usernameInput.getAttribute('data-current-username') || usernameInput.value;
            
            // Basic validation
            if (!username || !password) {
                showMessage('error', 'Username and password are required');
                return;
            }
            
            // Get Firestore reference
            const db = firebase.firestore();
            
            // Find the admin document by username
            db.collection('growbrainadminAuth').where('username', '==', currentUsername)
                .get()
                .then((querySnapshot) => {
                    if (querySnapshot.empty) {
                        throw new Error('Admin account not found');
                    }
                    
                    const adminDoc = querySnapshot.docs[0];
                    const updates = {
                        username: username,
                        password: password
                    };
                    
                    // Update the admin document
                    return adminDoc.ref.update(updates);
                })
                .then(() => {
                    // Handle profile picture upload if provided
                    if (profilePictureInput.files.length > 0) {
                        uploadProfilePicture(username);
                    } else {
                        // If no new profile picture, just update the PHP session
                        updateSession(username);
                    }
                })
                .catch((error) => {
                    console.error('Error updating profile:', error);
                    showMessage('error', 'Error updating profile: ' + error.message);
                });
        });
    }
    
    // Handle profile picture preview
    if (profilePictureInput) {
        profilePictureInput.addEventListener('change', function() {
            if (this.files && this.files[0]) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    profilePicturePreview.src = e.target.result;
                };
                reader.readAsDataURL(this.files[0]);
            }
        });
    }
    
    // Function to upload profile picture
    function uploadProfilePicture(username) {
        const formData = new FormData();
        formData.append('profile_picture', profilePictureInput.files[0]);
        
        fetch('upload_profile_picture.php', {
            method: 'POST',
            body: formData
        })
        .then(response => response.json())
        .then(data => {
            if (data.status === 'success') {
                // Update the admin document with the new profile picture URL
                const db = firebase.firestore();
                return db.collection('growbrainadminAuth').where('username', '==', username)
                    .get()
                    .then((querySnapshot) => {
                        if (!querySnapshot.empty) {
                            const adminDoc = querySnapshot.docs[0];
                            return adminDoc.ref.update({
                                profilePicture: data.file
                            });
                        }
                    })
                    .then(() => {
                        updateSession(username, data.file);
                    });
            } else {
                throw new Error(data.message || 'Error uploading profile picture');
            }
        })
        .catch(error => {
            console.error('Error:', error);
            showMessage('error', 'Error uploading profile picture: ' + error.message);
        });
    }
    
    // Function to update the PHP session
    function updateSession(username, profilePicture = null) {
        const formData = new FormData();
        formData.append('username', username);
        formData.append('password', passwordInput.value);
        
        fetch('updateProfile.php', {
            method: 'POST',
            body: formData
        })
        .then(response => response.json())
        .then(data => {
            showMessage('success', data.message || 'Profile updated successfully');
            
            // Update the UI
            const profileUsername = document.querySelector('.user-info span');
            if (profileUsername) {
                profileUsername.textContent = username;
            }
            
            // Update profile picture in UI if provided
            if (profilePicture) {
                const profileImages = document.querySelectorAll('.user-avatar img, .profile-pic');
                profileImages.forEach(img => {
                    img.src = profilePicture + '?v=' + new Date().getTime();
                });
            }
            
            // Close the edit section after a delay
            setTimeout(() => {
                const profileEditSection = document.getElementById('profile-edit-section');
                if (profileEditSection) {
                    profileEditSection.style.display = 'none';
                }
                
                // Close the modal after updating
                const profileModal = document.getElementById('profile-modal');
                if (profileModal) {
                    profileModal.style.display = 'none';
                }
            }, 2000);
        })
        .catch(error => {
            console.error('Error:', error);
            showMessage('error', 'Error updating session: ' + error.message);
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
}); 