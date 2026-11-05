// ==========================================================================
// THE RIGHT CALL — SAFESCAPE 2.0
// Client-side interactions & tab routing
// ==========================================================================

document.addEventListener('DOMContentLoaded', () => {
  const tabs = document.querySelectorAll('.nav-tab');
  const panels = document.querySelectorAll('.tab-panel');
  const quickLaunchBtn = document.getElementById('quickLaunchBtn');
  const godotIframe = document.getElementById('godotIframe');
  const btnReloadGame = document.getElementById('btnReloadGame');
  const btnFullscreenGame = document.getElementById('btnFullscreenGame');
  const gameContainer = document.getElementById('gameContainer');

  // Activate Tab
  window.switchTab = function (targetTab) {
    if (!targetTab) return;

    tabs.forEach(tab => {
      const isMatch = tab.dataset.tab === targetTab;
      tab.classList.toggle('active', isMatch);
      tab.setAttribute('aria-selected', isMatch ? 'true' : 'false');
    });

    panels.forEach(panel => {
      const isMatch = panel.id === targetTab;
      if (isMatch) {
        panel.classList.add('active');
        // Scroll into view smoothly if needed
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } else {
        panel.classList.remove('active');
      }
    });

    // Update URL hash without jumping
    if (history.pushState) {
      history.pushState(null, null, '#' + targetTab);
    } else {
      location.hash = '#' + targetTab;
    }
  };

  // Bind Tab Click events
  tabs.forEach(tab => {
    tab.addEventListener('click', (e) => {
      e.preventDefault();
      const target = tab.dataset.tab;
      window.switchTab(target);
    });
  });

  // Quick Launch Button
  if (quickLaunchBtn) {
    quickLaunchBtn.addEventListener('click', () => {
      window.switchTab('system');
    });
  }

  // Reload Game iframe
  if (btnReloadGame && godotIframe) {
    btnReloadGame.addEventListener('click', () => {
      godotIframe.src = godotIframe.src;
    });
  }

  // Fullscreen toggle
  if (btnFullscreenGame && gameContainer) {
    btnFullscreenGame.addEventListener('click', () => {
      if (!document.fullscreenElement) {
        if (gameContainer.requestFullscreen) {
          gameContainer.requestFullscreen();
        } else if (gameContainer.webkitRequestFullscreen) {
          gameContainer.webkitRequestFullscreen();
        } else if (gameContainer.msRequestFullscreen) {
          gameContainer.msRequestFullscreen();
        }
      } else {
        if (document.exitFullscreen) {
          document.exitFullscreen();
        }
      }
    });
  }

  // Check URL hash on page load
  const hash = window.location.hash.replace('#', '');
  const validTabs = ['overview', 'team', 'problem', 'methodology', 'system', 'results', 'links'];
  if (hash && validTabs.includes(hash)) {
    window.switchTab(hash);
  } else {
    window.switchTab('overview');
  }
});
