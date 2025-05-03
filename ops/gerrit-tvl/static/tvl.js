// vim: set noai ts=2 sw=2 et: */

function formatDuration(from, to) {
  const millisecondsTook = Math.floor(to.valueOf() - from.valueOf());
  if (millisecondsTook < 2000) return `${millisecondsTook} ms`;
  const secondsTook = Math.floor(millisecondsTook / 1000);
  if (secondsTook < 100) return `${secondsTook} seconds`;
  const minutesTook = Math.floor(secondsTook / 60);
  if (minutesTook < 60) return `${minutesTook} minutes`;
  const hoursTook = Math.floor(minutesTook / 60);
  const minutesRemainder = minutesTook - (hoursTook * 60);
  return `${hoursTook}hr ${minutesRemainder}min`;
}

// Maps the status of a Buildkite *job* to the statuses available for
// a Gerrit check.
//
// Note that jobs can have statuses that, according to the Buildkite
// documentation, are only available for builds, and maybe vice-versa.
// To deal with this we simply cover all statuses for all types here.
//
// Buildkite job statuses: https://buildkite.com/docs/pipelines/notifications#job-states
//
// Gerrit check statuses: https://gerrit.googlesource.com/gerrit/+/v3.4.0/polygerrit-ui/app/api/checks.ts#167
//
// TODO(tazjin): Use SCHEDULED status once we have upgraded Gerrit
// past 3.4
function jobStateToCheckRunStatus(state) {
  const status = {
    // Statuses documented for both types
    'blocked': 'RUNNABLE',
    'canceled': 'COMPLETED',
    'canceling': 'RUNNING',
    'running': 'RUNNING',
    'scheduled': 'RUNNABLE',
    'skipped': 'COMPLETED',

    // Statuses only documented for builds
    'creating': 'RUNNABLE',
    'failed': 'COMPLETED',
    'not_run': 'COMPLETED',
    'passed': 'COMPLETED',

    // Statuses only documented for jobs
    'accepted': 'RUNNABLE',
    'assigned': 'RUNNABLE',
    'blocked_failed': 'COMPLETED',
    'broken': 'COMPLETED',
    'finished': 'COMPLETED',
    'limited': 'RUNNABLE',
    'limiting': 'RUNNABLE',
    'pending': 'RUNNABLE',
    'timed_out': 'COMPLETED',
    'timing_out': 'RUNNING',
    'unblocked': 'RUNNABLE',
    'unblocked_failed': 'COMPLETED',
    'waiting': 'RUNNABLE',
    'waiting_failed': 'COMPLETED',
  }[state];

  if (!status) {
    console.log(`unknown Buildkite job state: ${state}`);
  }

  return status;
}

const snixChecksProvider = {
  async fetch(change) {
    let {patchsetSha, repo} = change;

    if (repo !== 'snix') {
      // We only handle snix's depot at the moment.
      return {responseCode: 'OK'};
    }

    const url = `https://cl.snix.dev/buildkite-status/${encodeURIComponent(patchsetSha)}`;
    const resp = await fetch(url, { });
    const respJSON = await resp.json();

    const runs = [];
    for (let i = 0; i < respJSON.length; i++) {
      const attempt = respJSON.length - i;
      const build = respJSON[i];

      for (let job of build.jobs) {
        // Skip non-command jobs (e.g. waiting/grouping jobs)
        if (job.type !== 'script') {
          continue;
        }

        // Skip jobs marked as 'broken' (this means they were skipped
        // intentionally)
        if (job.state === 'broken') {
          continue;
        }

        // TODO(lukegb): add the ability to retry these
        const checkRun = {
          patchset: parseInt(build.env.GERRIT_PATCHSET, 10),
          attempt: attempt,
          externalId: job.id,
          checkName: job.name,
          checkDescription: job.command,
          checkLink: job.web_url,
          status: jobStateToCheckRunStatus(job.state),
          labelName: 'Verified',
        };

        if (job.scheduled_at) {
          checkRun.scheduledTimestamp = new Date(job.scheduled_at);
        }

        if (job.started_at) {
          checkRun.startedTimestamp = new Date(job.started_at);
        }

        if (job.finished_at) {
          checkRun.finishedTimestamp = new Date(job.finished_at);
        }

        let statusDescription = job.state;
        if (checkRun.startedTimestamp && checkRun.finishedTimestamp) {
          statusDescription = `${statusDescription} in ${formatDuration(checkRun.startedTimestamp, checkRun.finishedTimestamp)}`;
        } else if (checkRun.startedTimestamp) {
          statusDescription = `${statusDescription} for ${formatDuration(checkRun.startedTimestamp, new Date())}`;
        } else if (checkRun.scheduledTimestamp) {
          statusDescription = `${statusDescription} for ${formatDuration(checkRun.scheduledTimestamp, new Date())}`;
        }
        checkRun.statusDescription = statusDescription;

        if (['failed', 'timed_out'].includes(job.state)) {
          const result = {
            // TODO(lukegb): get the log as the message here (the Gerrit
            // implementation doesn't yet seem to support newlines in message
            // strings...)
            links: [{
              url: job.web_url,
              tooltip: "Buildkite",
              primary: true,
              icon: 'EXTERNAL',
            }],
            category: 'ERROR',
            summary: `${job.command} failed`,
          };
          checkRun.results = [result];
        }

        runs.push(checkRun);
      }
    }

    return {
      responseCode: 'OK',
      runs: runs,
    };
  },
};

Gerrit.install(plugin => {
  console.log('snix plugin initialising');

  plugin.checks().register(snixChecksProvider);
});
