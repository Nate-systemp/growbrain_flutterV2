// ui.js - Handles UI animations and interactions

document.addEventListener('DOMContentLoaded', function() {
  // Profile modal handling
  const profileTrigger = document.getElementById('profile-trigger');
  const profileModal = document.getElementById('profile-modal');
  const closeModal = document.querySelector('.modal .close');
  const editProfileBtn = document.getElementById('edit-profile-btn');
  const profileEditSection = document.getElementById('profile-edit-section');

  if (profileTrigger) {
    profileTrigger.addEventListener('click', () => {
      profileModal.style.display = 'block';
    });
  }
  
  if (closeModal) {
    closeModal.addEventListener('click', () => {
      profileModal.style.display = 'none';
      profileEditSection.style.display = 'none';
    });
  }
  
  window.addEventListener('click', (e) => {
    if (e.target == profileModal) {
      profileModal.style.display = 'none';
      profileEditSection.style.display = 'none';
    }
  });

  if (editProfileBtn) {
    editProfileBtn.addEventListener('click', () => {
      if (profileEditSection.style.display === 'none' || profileEditSection.style.display === '') {
        profileEditSection.style.display = 'block';
      } else {
        profileEditSection.style.display = 'none';
      }
    });
  }
  
  // Animate stat cards on load
  const statCards = document.querySelectorAll('.stat-card');
  statCards.forEach((card, index) => {
    setTimeout(() => {
      card.classList.add('fadeIn');
    }, 100 * index);
  });
  
  // Function to animate counting effect for highlights
  const animateCounters = (container) => {
    const counters = container.querySelectorAll('.highlight-value');
    
    counters.forEach(counter => {
      // Skip if already animated
      if (counter.classList.contains('counted')) return;
      
      counter.classList.add('counting', 'counted');
      
      const target = counter.innerText;
      let isPercentage = target.includes('%');
      let isSec = target.includes('sec');
      
      // Extract just the number
      let targetValue = parseFloat(target.replace(/[^0-9.]/g, ''));
      
      // Only animate if it's a number greater than zero
      if (!isNaN(targetValue) && targetValue > 0) {
        let startValue = 0;
        let duration = 1500;
        let startTime = null;
        
        const updateCounter = (timestamp) => {
          if (!startTime) startTime = timestamp;
          const progress = Math.min((timestamp - startTime) / duration, 1);
          const easedProgress = easeOutQuart(progress);
          const currentValue = Math.floor(startValue + (targetValue - startValue) * easedProgress);
          
          // Format the output based on original format
          let formattedValue = currentValue;
          if (isPercentage) formattedValue += '%';
          if (isSec) formattedValue += ' sec';
          
          counter.textContent = formattedValue;
          
          if (progress < 1) {
            requestAnimationFrame(updateCounter);
          }
        };
        
        requestAnimationFrame(updateCounter);
      }
    });
  };
  
  // Easing function for smoother animation
  const easeOutQuart = (x) => {
    return 1 - Math.pow(1 - x, 4);
  };
  
  // Animate counters in the visible section
  const currentSection = document.getElementById('dashboard-section');
  if (currentSection) {
    animateCounters(currentSection);
  }
  
  // Note: Sidebar initialization is handled in script.js
  
  // Add animation to modals
    const modals = document.querySelectorAll('.modal-content');
    modals.forEach(modal => {
      const originalDisplay = modal.style.display;
      const observer = new MutationObserver(mutations => {
        mutations.forEach(mutation => {
          if (mutation.type === 'attributes' && mutation.attributeName === 'style') {
            if (modal.parentElement.style.display === 'block' && !modal.classList.contains('animated')) {
              modal.classList.add('animated');
            }
          }
        });
      });
      observer.observe(modal.parentElement, { attributes: true });
    });
    
    // Add loading indicator to buttons that perform actions
    const actionButtons = document.querySelectorAll('button[type="submit"]');
    actionButtons.forEach(button => {
      button.addEventListener('click', function(e) {
        if (!this.classList.contains('loading') && this.form && this.form.checkValidity()) {
          this.classList.add('loading');
          const originalText = this.innerHTML;
          this.innerHTML = '<span class="loading-spinner"></span> Processing...';
          
          // Reset button after 2 seconds (or replace with actual form submission event)
          setTimeout(() => {
            this.innerHTML = originalText;
            this.classList.remove('loading');
          }, 2000);
        }
      });
    });
    
    // Add table row animations
    const tables = document.querySelectorAll('table');
    tables.forEach(table => {
      const observer = new MutationObserver(mutations => {
        const newRows = table.querySelectorAll('tbody tr:not(.animated)');
        newRows.forEach((row, index) => {
          setTimeout(() => {
            row.classList.add('animated', 'slideIn');
          }, 50 * index);
        });
      });
      observer.observe(table, { childList: true, subtree: true });
    });
    
    // Add pulse effect to important elements
    document.querySelectorAll('#total-students, #avg-progress').forEach(el => {
      el.classList.add('pulseEffect');
    });

  // Open Flutter web app from Activities toolbar
  document.addEventListener('click', function(e) {
    const btn = e.target.closest && e.target.closest('#open-flutter-app');
    if (btn) {
      // Serve the compiled Flutter web index directly
      const flutterUrl = 'growbrain_flutterV2/web/index.html';
      try {
        window.open(flutterUrl, '_blank');
      } catch (_) {
        location.href = flutterUrl;
      }
    }
  });
  
  // Add confirmation animation
  window.showConfirmation = (message) => {
    const toast = document.createElement('div');
    toast.className = 'confirmation-toast fadeIn';
    toast.innerHTML = `
      <div class="confirmation-content">
        <i class="fas fa-check-circle"></i>
        <span>${message}</span>
      </div>
    `;
    document.body.appendChild(toast);
    
    setTimeout(() => {
      toast.classList.remove('fadeIn');
      toast.classList.add('fadeOut');
      setTimeout(() => {
        document.body.removeChild(toast);
      }, 500);
    }, 3000);
  };
}); 