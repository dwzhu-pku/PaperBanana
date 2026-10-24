const account = document.querySelector("#account");
const banner = document.querySelector("#banner");
const sponsoredNote = document.querySelector("#sponsored-note");
const byokFields = document.querySelector("#byok-fields");
const form = document.querySelector("#job-form");
const formError = document.querySelector("#form-error");
const submit = document.querySelector("#submit");
const live = document.querySelector("#live");
const historyEl = document.querySelector("#history");
const adminEl = document.querySelector("#admin");
const adminTab = document.querySelector("#admin-tab");

let me = null;
let config = null;
let pollTimer = null;

function el(tag, text, className) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

async function api(path, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  const response = await fetch(path, {
    credentials: "same-origin",
    ...options,
    headers,
  });
  const text = await response.text();
  let body = null;
  if (text) {
    try { body = JSON.parse(text); } catch { body = { detail: text }; }
  }
  if (!response.ok) {
    const detail = body && body.detail;
    let message = response.statusText;
    if (typeof detail === "string") message = detail;
    else if (Array.isArray(detail)) message = detail.map((item) => item.msg || JSON.stringify(item)).join("; ");
    else if (detail && detail.message) message = detail.message;
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return body;
}

function showTab(name) {
  for (const button of document.querySelectorAll(".tabs button")) {
    button.classList.toggle("active", button.dataset.tab === name);
  }
  for (const panel of ["generate", "history", "admin"]) {
    document.querySelector("#" + panel).hidden = panel !== name;
  }
  if (name === "history") loadHistory();
  if (name === "admin") loadAdmin();
}

document.querySelectorAll(".tabs button").forEach((button) => {
  button.addEventListener("click", () => showTab(button.dataset.tab));
});

form.elements.mode.forEach((input) => {
  input.addEventListener("change", () => {
    const sponsored = form.elements.mode.value === "sponsored";
    byokFields.hidden = sponsored;
    sponsoredNote.hidden = !sponsored;
  });
});

function renderAccount() {
  account.replaceChildren();
  if (!me) {
    const link = el("a", "Sign in with Hugging Face", "linkish");
    link.href = "/auth/login";
    account.append(link);
    return;
  }
  account.append(el("span", me.username || me.hf_user_id));
  const out = el("button", "Sign out");
  out.type = "button";
  out.addEventListener("click", async () => {
    await fetch("/auth/logout", { method: "POST", credentials: "same-origin" });
    location.href = "/";
  });
  account.append(out);
}

function renderConfig() {
  if (!config || !config.sponsored) return;
  const sponsored = config.sponsored;
  const bits = [
    `Model ${sponsored.text_model} / ${sponsored.image_model}`,
    `resolution ${sponsored.image_size}`,
    `${sponsored.max_critic_rounds} refinement round(s)`,
    `${sponsored.candidates} candidate`,
    `${sponsored.user_daily_limit} free figures / day`,
    `public budget $${sponsored.daily_budget_usd}/day, $${sponsored.monthly_budget_usd}/month`,
  ];
  if (sponsored.paused) {
    banner.hidden = false;
    banner.textContent = "Free trial is paused. " + (sponsored.pause_reason || "An admin can resume it after the ledger backup is healthy.");
  } else if (!config.ledger_ok) {
    banner.hidden = false;
    banner.textContent = config.ledger_error || "The ledger could not be restored. Quotas were not reset.";
  } else {
    banner.hidden = true;
  }
  sponsoredNote.replaceChildren(el("p", bits.join(" · ")));
  adminTab.hidden = !(me && me.is_admin);
}

async function boot() {
  try {
    config = await api("/api/public-config");
  } catch (error) {
    banner.hidden = false;
    banner.textContent = error.message;
  }
  try {
    me = await api("/api/me");
  } catch {
    me = null;
  }
  renderAccount();
  renderConfig();
}

function imageCard(jobId, image) {
  const figure = el("figure");
  const img = document.createElement("img");
  img.alt = image.label;
  img.src = `/api/jobs/${jobId}/images/${image.id}`;
  const caption = el("figcaption", image.label);
  const link = el("a", "Download");
  link.href = `/api/jobs/${jobId}/images/${image.id}?download=1`;
  figure.append(img, caption, link);
  return figure;
}

function renderLive(job) {
  live.hidden = false;
  document.querySelector("#live-title").textContent = job.caption || "Generation";
  document.querySelector("#live-status").textContent = job.status;
  const pct = Math.round(((job.progress && job.progress.overall_pct) || (job.status === "succeeded" ? 1 : 0)) * 100);
  document.querySelector("#live-bar").style.width = pct + "%";
  const stage = (job.progress && job.progress.stage) || "";
  document.querySelector("#live-stage").textContent = job.error || stage || job.status;
  const wrap = document.querySelector("#live-images");
  wrap.replaceChildren(...(job.images || []).map((image) => imageCard(job.id, image)));
}

async function watch(jobId) {
  if (pollTimer) clearInterval(pollTimer);
  const tick = async () => {
    const job = await api("/api/jobs/" + jobId);
    renderLive(job);
    if (["succeeded", "failed", "interrupted"].includes(job.status)) {
      clearInterval(pollTimer);
      submit.disabled = false;
    }
  };
  await tick();
  pollTimer = setInterval(() => {
    tick().catch((error) => {
      formError.textContent = error.message;
    });
  }, 1000);
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  formError.textContent = "";
  if (!me) {
    formError.textContent = "Sign in first.";
    return;
  }
  const data = new FormData(form);
  const mode = data.get("mode");
  const payload = {
    mode,
    content: data.get("content"),
    caption: data.get("caption"),
    task_name: data.get("task_name"),
    aspect_ratio: "16:9",
  };
  if (mode === "byok") {
    payload.byok = {
      provider: data.get("provider"),
      api_key: data.get("api_key"),
      main_model: data.get("main_model"),
      image_model: data.get("image_model"),
      num_candidates: Number(data.get("num_candidates") || 1),
      max_critic_rounds: Number(data.get("max_critic_rounds") || 0),
      exp_mode: "demo_full",
      retrieval_setting: "none",
    };
  }
  submit.disabled = true;
  const key = crypto.randomUUID().replace(/-/g, "");
  try {
    const job = await api("/api/jobs", {
      method: "POST",
      body: JSON.stringify(payload),
      headers: { "Idempotency-Key": key },
    });
    renderLive(job);
    if (!["succeeded", "failed", "interrupted"].includes(job.status)) watch(job.id);
    else submit.disabled = false;
  } catch (error) {
    formError.textContent = error.message;
    submit.disabled = false;
  }
});

async function loadHistory() {
  historyEl.replaceChildren(el("p", "Loading…"));
  if (!me) {
    historyEl.replaceChildren(el("p", "Sign in to see your figures."));
    return;
  }
  const body = await api("/api/jobs");
  historyEl.replaceChildren();
  if (!body.jobs.length) {
    historyEl.append(el("p", "No generations yet."));
    return;
  }
  for (const job of body.jobs) {
    const article = el("article");
    article.append(el("h2", job.caption));
    article.append(el("p", `${job.status} · ${job.mode} · ${job.created_at}`));
    if (job.error) article.append(el("p", job.error, "error"));
    const grid = el("div", null, "history-grid");
    for (const image of job.images || []) grid.append(imageCard(job.id, image));
    article.append(grid);
    if ((job.images || []).length) {
      const archive = el("a", "Download all");
      archive.href = `/api/jobs/${job.id}/archive`;
      article.append(archive);
    }
    historyEl.append(article);
  }
}

async function loadAdmin() {
  adminEl.replaceChildren(el("p", "Loading…"));
  const body = await api("/api/admin/overview");
  adminEl.replaceChildren();
  const summary = el("div", null, "card");
  const status = body.status;
  summary.append(el("h2", status.paused || !status.backup_ok ? "Free trial paused" : "Free trial running"));
  summary.append(el("p", `Today $${status.daily_spend_usd} of $${body.limits.daily_budget_usd}. This month $${status.monthly_spend_usd} of $${body.limits.monthly_budget_usd}.`));
  summary.append(el("p", status.pause_reason || "Backup verified."));
  const pause = el("button", status.paused ? "Resume free trial" : "Pause free trial");
  pause.type = "button";
  pause.addEventListener("click", async () => {
    await api(status.paused ? "/api/admin/resume" : "/api/admin/pause", { method: "POST" });
    loadAdmin();
    boot();
  });
  summary.append(pause);
  adminEl.append(summary);
  const jobs = el("div", null, "card");
  jobs.append(el("h2", "Recent jobs"));
  const table = document.createElement("table");
  const head = document.createElement("tr");
  for (const name of ["User", "Status", "Mode", "Spend", "When"]) {
    head.append(el("th", name));
  }
  table.append(head);
  for (const job of body.jobs) {
    const row = document.createElement("tr");
    for (const value of [job.user_id, job.status, job.mode, "$" + job.spend_usd, job.created_at]) {
      row.append(el("td", value));
    }
    table.append(row);
  }
  jobs.append(table);
  adminEl.append(jobs);
}

boot();
