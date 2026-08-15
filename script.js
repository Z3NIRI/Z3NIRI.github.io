const config = window.PORTFOLIO_CONFIG || {};
const state = { totalVisits: 0, activeTab: "about" };
let clickAudio;

function clickSound() {
  if (!clickAudio) clickAudio = new Audio("assets/sounds/click.mp3");
  clickAudio.currentTime = 0;
  clickAudio.volume = .25;
  clickAudio.play().catch(() => {});
}

function setTab(name, updateHash = true) {
  if (!document.getElementById(name)) return;
  state.activeTab = name;
  document.querySelectorAll(".tab-panel").forEach(el => el.classList.toggle("active", el.id === name));
  document.querySelectorAll(".tab-link").forEach(el => el.classList.toggle("active", el.dataset.tab === name));
  if (updateHash) history.replaceState(null, "", `#${name}`);
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function bindNavigation() {
  document.querySelectorAll("[data-tab], [data-tab-target]").forEach(el => el.addEventListener("click", event => {
    event.preventDefault(); clickSound(); setTab(el.dataset.tab || el.dataset.tabTarget);
  }));
  const initial = location.hash.slice(1);
  if (initial) setTab(initial, false);
}

function bootstrap() {
  document.getElementById("intro-text").textContent = config.about.introduction;
  document.getElementById("profile-name").textContent = config.name;
  document.getElementById("discord-avatar").src = config.discord.fallbackAvatar;
  document.getElementById("header-avatar").src = config.discord.fallbackAvatar;
  document.getElementById("workflow-tools").innerHTML = config.about.workflowTools.map(tool => `<span>${tool}</span>`).join("");
  document.getElementById("library-tools").innerHTML = config.about.libraries.map(tool => `<span>${tool}</span>`).join("");
  const availability = document.getElementById("availability");
  availability.classList.toggle("unavailable", !config.availableForWork);
  availability.querySelector("b").textContent = config.availableForWork ? "Open for work" : "Not available";
  const email = document.getElementById("email-link"); email.textContent = config.contact.email; email.href = `mailto:${config.contact.email}`;
  const socials = [{key:"discord",label:"Discord",icon:"discord.svg"},{key:"robloxProfile",label:"Roblox",icon:"roblox.svg"}];
  document.getElementById("social-buttons").innerHTML = socials.filter(x => config.links[x.key]).map(x => `<a class="social-btn" href="${config.links[x.key]}" target="_blank" rel="noreferrer"><img src="assets/icons/${x.icon}" alt="">${x.label}</a>`).join("");
  updateTimezone();
}

function updateTimezone() {
  const zone = config.contact.timeZone || "Europe/Belgrade";
  const parts = new Intl.DateTimeFormat("en-GB", { timeZone: zone, timeZoneName: "short" }).formatToParts(new Date());
  const abbreviation = parts.find(part => part.type === "timeZoneName")?.value || "CET";
  const time = new Intl.DateTimeFormat("en-GB", { timeZone: zone, hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date());
  const display = `${time} · ${abbreviation}`;
  document.getElementById("hero-timezone").textContent = display;
}

const compactNumber = value => value >= 1e9 ? `${(value/1e9).toFixed(1)}B` : value >= 1e6 ? `${(value/1e6).toFixed(1)}M` : value >= 1e3 ? `${(value/1e3).toFixed(1)}K` : value.toLocaleString();

async function fetchProject(project, index) {
  const placeId = project.robloxGameUrl.match(/games\/(\d+)/)?.[1];
  const fallback = { available: true, name: project.name || "Roblox Experience", visits: null, imageUrl: "" };
  if (!placeId) return fallback;
  try {
    const placeIconResponse = await fetch(`https://thumbnails.roproxy.com/v1/places/gameicons?placeIds=${placeId}&returnPolicy=PlaceHolder&size=512x512&format=Png&isCircular=false`);
    const placeIconData = await placeIconResponse.json();
    fallback.imageUrl = placeIconData.data?.[0]?.imageUrl || "";
  } catch {}
  try {
    const universeResponse = await fetch(`https://apis.roproxy.com/universes/v1/places/${placeId}/universe`);
    if (!universeResponse.ok) throw new Error("Could not find universe");
    const { universeId } = await universeResponse.json();
    const [gameResponse, thumbResponse] = await Promise.all([
      fetch(`https://games.roproxy.com/v1/games?universeIds=${universeId}`),
      fetch(`https://thumbnails.roproxy.com/v1/games/multiget/thumbnails?universeIds=${universeId}&countPerUniverse=1&defaults=true&size=768x432&format=Png&isCircular=false`)
    ]);
    const game = (await gameResponse.json()).data?.[0];
    const thumbnailData = await thumbResponse.json();
    const thumb = thumbnailData.data?.[0]?.thumbnails?.find(item => item.state === "Completed") || thumbnailData.data?.[0]?.thumbnails?.[0];
    if (!game) throw new Error("No game data");
    return { ...game, available: true, imageUrl: thumb?.imageUrl || fallback.imageUrl };
  } catch (error) { console.warn(`Project ${index + 1}:`, error); return fallback; }
}

async function renderProjects() {
  const grid = document.getElementById("project-grid");
  grid.innerHTML = config.projects.map((project,index) => `<article class="project-card" id="project-${index}"><div class="project-thumb"><div class="project-thumb-fallback">${project.name.charAt(0)}</div></div><div class="project-body"><div class="project-meta"><span>${project.role.toUpperCase()}</span><span>${project.period}</span></div><h3>${project.name}</h3><div class="project-bottom"><span class="visit-count">VISITS LOADING…</span><a class="play-btn" href="${project.robloxGameUrl}" target="_blank" rel="noreferrer">PLAY ON ROBLOX ↗</a></div></div></article>`).join("");
  const data = await Promise.all(config.projects.map(fetchProject));
  state.totalVisits = 0;
  data.forEach((game,index) => {
    const card = document.getElementById(`project-${index}`);
    card.querySelector("h3").textContent = game.name;
    if (game.imageUrl) card.querySelector(".project-thumb").innerHTML = `<img src="${game.imageUrl}" alt="${game.name} thumbnail">`;
    if (typeof game.visits === "number") { state.totalVisits += game.visits; card.querySelector(".visit-count").textContent = `${compactNumber(game.visits)} VISITS`; }
    else card.querySelector(".visit-count").textContent = "VIEW ON ROBLOX";
  });
  document.getElementById("total-visits").innerHTML = state.totalVisits ? `TOTAL VISITS<strong>${compactNumber(state.totalVisits)}+</strong>` : "Visit counts are unavailable";
}

function escapeHTML(value) { return value.replace(/[&<>]/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;"}[char])); }
function highlightLuau(source) {
  const keywords = new Set(["and","break","continue","do","else","elseif","end","export","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","type","until","while"]);
  const builtins = new Set(["assert","error","getmetatable","ipairs","math","next","pairs","pcall","print","rawequal","rawget","rawset","require","select","setmetatable","string","table","task","tonumber","tostring","type","typeof","unpack","Vector2","Vector3","CFrame","Color3","Enum","Instance","UDim","UDim2","Random","workspace","game","script"]);
  const tokenPattern = /(--.*$|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`|\b\d+(?:\.\d+)?\b|\b[A-Za-z_]\w*\b)/g;
  return source.split("\n").map(line => {
    let cursor = 0;
    let rendered = "";
    for (const match of line.matchAll(tokenPattern)) {
      rendered += escapeHTML(line.slice(cursor, match.index));
      const token = match[0];
      let className = "";
      if (token.startsWith("--")) className = "tok-com";
      else if (/^["'`]/.test(token)) className = "tok-str";
      else if (/^\d/.test(token)) className = "tok-num";
      else if (keywords.has(token)) className = "tok-key";
      else if (builtins.has(token)) className = "tok-global";
      else if (line.slice(match.index + token.length).match(/^\s*\(/)) className = "tok-fn";
      rendered += className ? `<span class="${className}">${escapeHTML(token)}</span>` : escapeHTML(token);
      cursor = match.index + token.length;
    }
    rendered += escapeHTML(line.slice(cursor));
    return `<span class="code-line">${rendered || " "}</span>`;
  }).join("");
}

function openModal(type, item, content) {
  const modal = document.getElementById("showcase-modal");
  document.getElementById("modal-type").textContent = type;
  document.getElementById("modal-title").textContent = item.name;
  const description = document.getElementById("modal-description");
  description.textContent = item.description || "";
  description.hidden = !item.description;
  document.getElementById("modal-content").innerHTML = content;
  modal.classList.add("open"); modal.setAttribute("aria-hidden", "false"); document.body.classList.add("modal-open");
}

function closeModal() {
  const modal = document.getElementById("showcase-modal");
  modal.classList.remove("open"); modal.setAttribute("aria-hidden", "true"); document.getElementById("modal-content").innerHTML = ""; document.body.classList.remove("modal-open");
}

async function renderSamples() {
  const videos = config.videos || [], systemGrid = document.getElementById("system-grid");
  systemGrid.innerHTML = videos.length ? videos.map((video, index) => `<button class="showcase-card system-card" data-video="${index}" type="button"><video src="${video.file}" muted autoplay loop playsinline preload="metadata"></video><span class="preview-shade"></span><span class="preview-play">▶</span><span class="preview-info"><b>${video.name}</b><small>View system</small></span></button>`).join("") : '<div class="showcase-empty"><span>▶</span><div><b>No system videos added yet</b><p>Add MP4 files in portfolio.config.js when they’re ready.</p></div></div>';
  systemGrid.querySelectorAll("[data-video]").forEach(card => card.addEventListener("click", () => { const item = videos[card.dataset.video]; openModal("SYSTEM SHOWCASE", item, `<video class="modal-video" src="${item.file}" controls controlsList="nodownload" disablePictureInPicture autoplay loop oncontextmenu="return false"></video>`); }));

  const samples = config.codeSamples || [], codeGrid = document.getElementById("code-grid");
  const sources = await Promise.all(samples.map(async sample => { try { const response = await fetch(sample.file); if (!response.ok) throw new Error(); return await response.text(); } catch { return "-- This sample could not be loaded."; } }));
  codeGrid.innerHTML = samples.map((sample,index) => `<button class="showcase-card code-preview-card" data-code="${index}" type="button"><span class="code-card-top"><i></i>${sample.file.replace(/\.lua$/i,".luau")}</span><pre><code>${highlightLuau(sources[index].split("\n").slice(0,12).join("\n"))}</code></pre><span class="code-card-info"><b>${sample.name}</b><small>Open full source →</small></span></button>`).join("");
  codeGrid.querySelectorAll("[data-code]").forEach(card => card.addEventListener("click", () => { const index = card.dataset.code, item = samples[index]; openModal("CODE SAMPLE", item, `<div class="modal-editor-head"><span>${item.file.replace(/\.lua$/i,".luau")}</span></div><pre class="code-window modal-code"><code>${highlightLuau(sources[index])}</code></pre>`); }));
  document.querySelectorAll("[data-close-modal]").forEach(button => button.addEventListener("click", closeModal));
  document.addEventListener("keydown", event => { if (event.key === "Escape") closeModal(); });
}

async function loadDiscordPresence() {
  try {
    const response = await fetch(`https://api.lanyard.rest/v1/users/${config.discord.lanyardUserId}`); const { data } = await response.json(); if (!data) return;
    const status = data.discord_status || "offline", label = {online:"Online",idle:"Away",dnd:"Do not disturb",offline:"Offline"};
    document.getElementById("status-dot").className = `status-dot status-${status}`; document.getElementById("discord-presence").textContent = label[status];
    if (data.discord_user.avatar) {
      const avatar = `https://cdn.discordapp.com/avatars/${data.discord_user.id}/${data.discord_user.avatar}.png?size=256`;
      document.getElementById("discord-avatar").src = avatar; document.getElementById("header-avatar").src = avatar;
    }
  } catch {}
}

bootstrap(); bindNavigation(); renderProjects(); renderSamples(); loadDiscordPresence(); setInterval(loadDiscordPresence, 30000); setInterval(updateTimezone, 60000);
