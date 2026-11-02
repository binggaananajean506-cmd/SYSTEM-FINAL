export function createBackgroundActions({ host, owner = () => '', notify = () => {}, errorMessage = error => error.message || 'Please try again.' }) {
  const jobs = new Map();
  let collapsed = false;
  const root = document.createElement('section');
  root.className = 'background-actions'; root.setAttribute('aria-label', 'Submission progress'); root.hidden = true;
  const live = document.createElement('div'); live.className = 'sr-only'; live.setAttribute('role', 'status'); live.setAttribute('aria-live', 'polite');
  const header = document.createElement('button'); header.type = 'button'; header.className = 'background-actions-heading';
  const list = document.createElement('div'); list.className = 'background-actions-list';
  const note = document.createElement('p'); note.className = 'background-actions-note';
  note.textContent = 'You can browse the site. Keep this tab open until finished.';
  header.addEventListener('click', () => { collapsed = !collapsed; render(); });
  root.append(live, header, list, note); host.append(root);
  const visible = () => [...jobs.values()].filter(job => job.owner === owner());
  function render() {
    const current = visible(); root.hidden = !current.length;
    const running = current.filter(job => job.state === 'running').length;
    const failed = current.filter(job => job.state === 'failed').length;
    header.textContent = `${running ? `${running} submission${running > 1 ? 's' : ''} in progress` : failed ? `${failed} submission${failed > 1 ? 's' : ''} need attention` : 'Submissions finished'} ${collapsed ? '+' : '−'}`;
    header.setAttribute('aria-expanded', String(!collapsed)); list.hidden = collapsed;
    note.hidden = collapsed || !running;
    list.replaceChildren();
    for (const job of current.slice().reverse()) {
      const card = document.createElement('article'); card.className = `background-task background-task--${job.state}`;
      const title = document.createElement('strong'); title.textContent = job.state === 'completed' ? job.success : job.title;
      const context = document.createElement('span'); context.className = 'background-task-context'; context.textContent = job.context || '';
      const message = document.createElement('p'); message.textContent = job.message + (Number.isFinite(job.progress) ? ` ${job.progress}%` : '');
      card.append(title, context, message);
      job.nodes = { message };
      if (job.state === 'running') {
        const progress = document.createElement('progress'); progress.max = 100;
        progress.setAttribute('aria-label', job.message);
        if (Number.isFinite(job.progress)) progress.value = job.progress;
        job.nodes.progress = progress;
        card.append(progress);
      }
      const buttons = document.createElement('div'); buttons.className = 'background-task-actions';
      const button = (label, action) => {
        const element = document.createElement('button'); element.type = 'button'; element.textContent = label;
        element.addEventListener('click', action); buttons.append(element);
      };
      if (job.state === 'failed' && job.retry) button('Retry', () => execute(job));
      if (job.state === 'failed' && job.recover) button('Review submission', async () => {
        try {
          if (await job.recover() !== false) { jobs.delete(job.key); render(); }
        } catch (error) { job.message = errorMessage(error); render(); }
      });
      if (job.state === 'completed' && job.action) button(job.action.label, () => { collapsed = true; render(); job.action.run(); });
      if (job.state !== 'running') button('Dismiss', () => {
        if (job.state === 'failed' && job.recover && !window.confirm('Discard this failed submission? Its saved draft will be removed.')) return;
        jobs.delete(job.key); render();
      });
      card.append(buttons); list.append(card);
    }
  }
  async function execute(job) {
    if (job.state === 'running') return;
    job.state = 'running'; job.message = 'Starting…'; job.progress = null;
    collapsed = false; render(); live.textContent = `${job.title}. You can continue using the site.`;
    // Run after the caller has closed the form and captured its complete input.
    await Promise.resolve();
    try {
      await job.run((message, progress = null) => {
        job.message = message; job.progress = progress;
        if (job.nodes?.progress?.isConnected) {
          job.nodes.message.textContent = message + (Number.isFinite(progress) ? ` ${progress}%` : '');
          job.nodes.progress.setAttribute('aria-label', message);
          if (Number.isFinite(progress)) job.nodes.progress.value = progress;
          else job.nodes.progress.removeAttribute('value');
        } else render();
      }, () => job.owner === owner());
      job.state = 'completed'; job.message = 'Finished successfully.';
      job.run = null; job.recover = null;
      if (job.owner === owner()) live.textContent = job.success;
      if (job.owner === owner()) notify(job.success);
      window.setTimeout(() => {
        // A newer submission may reuse this case's key before this timer fires.
        if (jobs.get(job.key) !== job || job.state !== 'completed') return;
        jobs.delete(job.key); render();
      }, 3000);
    } catch (error) {
      job.state = 'failed'; job.message = errorMessage(error);
      if (job.owner === owner()) live.textContent = `${job.title} failed. ${job.message}`;
      if (job.owner === owner()) notify(`${job.title} failed. Review it in submission activity.`, true);
    }
    render();
  }
  window.addEventListener('beforeunload', event => {
    if (visible().some(job => job.state === 'running' || job.state === 'failed')) { event.preventDefault(); event.returnValue = ''; }
  });
  for (const element of [document.querySelector('#adminModal'), document.querySelector('#announcementComposerPanel')].filter(Boolean)) {
    new MutationObserver(() => {
      if (!element.hidden && visible().length) { collapsed = true; render(); }
    }).observe(element, { attributes: true, attributeFilter: ['hidden'] });
  }
  return {
    isActive: key => jobs.get(key)?.state === 'running',
    start(options) {
      if (jobs.get(options.key)?.state === 'running') { collapsed = false; render(); return false; }
      // Completed cards are disposable; never silently evict running/failed work.
      for (const [key, job] of jobs) if (job.state === 'completed' && jobs.size >= 8) jobs.delete(key);
      const job = { ...options, owner: owner(), state: 'queued' }; jobs.set(job.key, job);
      void execute(job); return true;
    },
    refresh: render,
  };
}
