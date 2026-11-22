const IDLE_MS = 5 * 60 * 1000;
const MESSAGE_MS = 8 * 1000;
const MESSAGES = [
  'I’m still here. Your workspace is out of view.',
  'Your work is right where you left it.',
  'Take your time. RoGoal will be here when you return.',
];

export function mountStandby(dialog, animate) {
  const message = dialog.querySelector('#standbyMessage');
  const resume = dialog.querySelector('#resumeWorkspace');
  const listeners = new AbortController();
  const capture = { capture: true, signal: listeners.signal };
  let lastActivity = Date.now();
  let idleTimer;
  let messageTimer;
  let previousFocus;

  function checkIdle() {
    clearTimeout(idleTimer);
    if (dialog.open) return;
    const remaining = IDLE_MS - (Date.now() - lastActivity);
    if (remaining > 0) {
      idleTimer = setTimeout(checkIdle, remaining);
      return;
    }
    previousFocus = document.activeElement;
    message.textContent = MESSAGES[0];
    dialog.showModal();
    animate(message, 5);
    let index = 0;
    messageTimer = setInterval(() => {
      index = (index + 1) % MESSAGES.length;
      message.textContent = MESSAGES[index];
      animate(message, 5);
    }, MESSAGE_MS);
  }

  function activity() {
    if (!dialog.open) lastActivity = Date.now();
  }

  function wake() {
    clearInterval(messageTimer);
    dialog.close();
    if (previousFocus instanceof HTMLElement && previousFocus.isConnected) {
      previousFocus.focus({ preventScroll: true });
    }
    previousFocus = null;
    lastActivity = Date.now();
    checkIdle();
  }

  for (const event of ['pointermove', 'pointerdown', 'wheel', 'keydown', 'input']) {
    window.addEventListener(event, activity, capture);
  }
  document.addEventListener('visibilitychange', checkIdle, { signal: listeners.signal });
  resume.addEventListener('click', wake, { signal: listeners.signal });
  dialog.addEventListener('cancel', event => {
    event.preventDefault();
    wake();
  }, { signal: listeners.signal });

  checkIdle();
  return () => {
    clearTimeout(idleTimer);
    clearInterval(messageTimer);
    listeners.abort();
  };
}
