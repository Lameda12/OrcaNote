// Landing Page Interactivity & Pre-Order Handler

// Mock timer state
let mockSeconds = 42;
let isRecording = true;
let timerInterval = null;

function startMockTimer() {
  const timerEl = document.getElementById('mock-timer');
  if (!timerEl) return;

  timerInterval = setInterval(() => {
    if (!isRecording) return;
    mockSeconds++;
    const mins = String(Math.floor(mockSeconds / 60)).padStart(2, '0');
    const secs = String(mockSeconds % 60).padStart(2, '0');
    timerEl.textContent = `${mins}:${secs}`;
  }, 1000);
}

function toggleMockRecording() {
  const stopBtn = document.getElementById('mock-stop-btn');
  const timerEl = document.getElementById('mock-timer');
  const menubarItem = document.querySelector('.menubar-item');
  const menubarTitle = document.querySelector('.menubar-title');

  if (isRecording) {
    // Stop recording
    isRecording = false;
    stopBtn.innerHTML = '<span class="status-icon">⚡</span><span>Generating Notes via Groq...</span>';
    stopBtn.style.background = 'rgba(56, 189, 248, 0.2)';
    stopBtn.style.borderColor = 'rgba(56, 189, 248, 0.4)';
    stopBtn.style.color = '#38bdf8';
    if (menubarTitle) menubarTitle.textContent = 'Transcribing & Summarizing (1.4s)...';

    setTimeout(() => {
      stopBtn.innerHTML = '<span class="status-icon">✓</span><span>Note Saved to ~/MeetingNotes!</span>';
      stopBtn.style.background = 'rgba(16, 185, 129, 0.2)';
      stopBtn.style.borderColor = 'rgba(16, 185, 129, 0.4)';
      stopBtn.style.color = '#34d399';
      if (menubarTitle) menubarTitle.textContent = 'Ready · Note Saved';

      // Reset after 3 seconds
      setTimeout(() => {
        isRecording = true;
        mockSeconds = 0;
        stopBtn.innerHTML = '<span class="stop-square"></span><span>Stop & Generate Notes</span>';
        stopBtn.style.background = '';
        stopBtn.style.borderColor = '';
        stopBtn.style.color = '';
        if (menubarTitle) menubarTitle.textContent = 'Recording Meeting...';
      }, 3000);
    }, 1400);
  }
}

// Pre-Order Form Handling
function handlePreOrder(e) {
  e.preventDefault();
  const emailInput = document.getElementById('email-input');
  const submitBtn = document.getElementById('submit-btn');
  const form = document.getElementById('preorder-form');
  const successBox = document.getElementById('preorder-success');

  const email = emailInput.value.trim();
  if (!email || !email.includes('@')) {
    alert('Please enter a valid email address.');
    return;
  }

  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span>Reserving Slot...</span>';

  // Save email to local storage
  const preorders = JSON.parse(localStorage.getItem('orca_preorders') || '[]');
  preorders.push({ email, timestamp: new Date().toISOString(), paid: false });
  localStorage.setItem('orca_preorders', JSON.stringify(preorders));

  setTimeout(() => {
    form.style.display = 'none';
    successBox.classList.remove('hidden');
    console.log(`[OrcaNotes] Pre-order recorded for: ${email}`);
  }, 600);
}

document.addEventListener('DOMContentLoaded', () => {
  startMockTimer();
});
