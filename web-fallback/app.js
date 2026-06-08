// InfoMe web fallback — renders the same card data the App Clip shows, for
// Android / desktop / anywhere App Clips can't load. Two link shapes:
//   /u/<shortCode>   → fetch from CloudKit's public database (CloudKit JS)
//   /c/<encoded>     → fully self-contained payload, decoded entirely client-side
//
// Keep this in sync with `CardLinkConfiguration` / `CardLinkCodec` in
// InfoMeKit if you change either format.

const CLOUDKIT_CONTAINER_ID = "iCloud.com.example.infome";
const CLOUDKIT_API_TOKEN = "REPLACE_WITH_A_PUBLIC_API_TOKEN"; // CloudKit Dashboard → API Access
const CLOUDKIT_RECORD_TYPE = "PublishedCard";
const CLOUDKIT_ENVIRONMENT = "production"; // or "development"

const SOCIAL_PLATFORMS = {
  instagram: { name: "Instagram", color: "#D32F7E", glyph: "IG", url: (h) => `https://instagram.com/${h}` },
  tiktok: { name: "TikTok", color: "#19191F", glyph: "TT", url: (h) => `https://tiktok.com/@${h}` },
  x: { name: "X", color: "#0F0F0F", glyph: "X", url: (h) => `https://x.com/${h}` },
  linkedin: { name: "LinkedIn", color: "#0A75BD", glyph: "in", url: (h) => `https://linkedin.com/in/${h}` },
  facebook: { name: "Facebook", color: "#1877F2", glyph: "f", url: (h) => `https://facebook.com/${h}` },
  youtube: { name: "YouTube", color: "#F02121", glyph: "▶", url: (h) => `https://youtube.com/${h}` },
  snapchat: { name: "Snapchat", color: "#FFDE00", glyph: "👻", url: (h) => `https://snapchat.com/add/${h}` },
  github: { name: "GitHub", color: "#21262D", glyph: "</>", url: (h) => `https://github.com/${h}` },
  threads: { name: "Threads", color: "#0D0D0D", glyph: "@", url: (h) => `https://threads.net/@${h}` },
  pinterest: { name: "Pinterest", color: "#C70017", glyph: "P", url: (h) => `https://pinterest.com/${h}` },
  twitch: { name: "Twitch", color: "#6645D9", glyph: "tv", url: (h) => `https://twitch.tv/${h}` },
  discord: { name: "Discord", color: "#5765F2", glyph: "D", url: (h) => `https://discord.com/users/${h}` },
  whatsapp: { name: "WhatsApp", color: "#26D16B", glyph: "☎", url: (h) => `https://wa.me/${h}` },
  telegram: { name: "Telegram", color: "#299ED8", glyph: "✈", url: (h) => `https://t.me/${h}` },
  spotify: { name: "Spotify", color: "#1CBA54", glyph: "♫", url: (h) => `https://open.spotify.com/user/${h}` },
  website: { name: "Website", color: "#5A6169", glyph: "🌐", url: (h) => (h.startsWith("http") ? h : `https://${h}`) },
};

const app = document.getElementById("app");

main().catch((error) => showError(error.message ?? "Something went wrong."));

async function main() {
  const segments = window.location.pathname.split("/").filter(Boolean);
  if (segments.length < 2) {
    showError("This link doesn't point to an InfoMe card.");
    return;
  }

  const [kind, payload] = segments;
  let card;
  if (kind === "u") {
    card = await fetchHostedCard(payload);
  } else if (kind === "c") {
    card = decodeOfflineCard(payload);
  } else {
    showError("This link doesn't point to an InfoMe card.");
    return;
  }

  renderCard(card);
}

// MARK: - Hosted (CloudKit) cards

async function fetchHostedCard(shortCode) {
  if (typeof CloudKit === "undefined") throw new Error("Couldn't reach the card service.");

  CloudKit.configure({
    containers: [{
      containerIdentifier: CLOUDKIT_CONTAINER_ID,
      apiTokenAuth: { apiToken: CLOUDKIT_API_TOKEN, persist: false },
      environment: CLOUDKIT_ENVIRONMENT,
    }],
  });

  const container = CloudKit.getDefaultContainer();
  const database = container.publicCloudDatabase;
  const response = await database.fetchRecords(shortCode);
  const record = response.records?.[0];
  if (!record || record.recordType !== CLOUDKIT_RECORD_TYPE || !record.fields?.payload) {
    throw new Error("No card found for that link.");
  }

  const base64 = record.fields.payload.value;
  const json = new TextDecoder().decode(base64ToBytes(base64));
  return JSON.parse(json);
}

// MARK: - Offline (self-contained) cards
//
// Mirrors `CardLinkCodec`: base64url → raw DEFLATE (note: Apple's
// `COMPRESSION_ZLIB` algorithm is — despite the name — *raw* DEFLATE with no
// zlib/gzip wrapper, so we must use `inflateRaw`, not `inflate`) → UTF-8 JSON.

function decodeOfflineCard(encoded) {
  const compressed = base64URLToBytes(encoded);
  const json = pako.inflateRaw(compressed, { to: "string" });
  return JSON.parse(json);
}

function base64URLToBytes(base64url) {
  let base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  while (base64.length % 4 !== 0) base64 += "=";
  return base64ToBytes(base64);
}

function base64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// MARK: - Rendering

function renderCard(card) {
  const template = document.getElementById("card-template");
  const fragment = template.content.cloneNode(true);
  const root = fragment.querySelector(".card");

  const fullName = [card.givenName, card.familyName].filter(Boolean).join(" ") || "Their InfoMe Card";
  const subtitle = [card.jobTitle, card.organization].filter(Boolean).join(" · ");

  const avatar = root.querySelector('[data-role="avatar"]');
  if (card.avatarJPEGData) {
    avatar.style.backgroundImage = `url(data:image/jpeg;base64,${card.avatarJPEGData})`;
    avatar.textContent = "";
  } else {
    avatar.textContent = initials(card.givenName, card.familyName);
  }

  setText(root, "name", fullName);
  setText(root, "subtitle", subtitle);
  setText(root, "bio", card.bio ?? "");

  const saveLink = root.querySelector('[data-role="save"]');
  const vCard = buildVCard(card, fullName);
  saveLink.href = `data:text/vcard;charset=utf-8,${encodeURIComponent(vCard)}`;
  saveLink.download = `${fullName.replace(/\s+/g, "_") || "contact"}.vcf`;

  const grid = root.querySelector('[data-role="socials"]');
  for (const link of card.socialLinks ?? []) {
    grid.appendChild(renderSocialBadge(link));
  }

  app.classList.remove("loading");
  app.replaceChildren(root);
  document.title = `${fullName} · InfoMe`;
}

function renderSocialBadge(link) {
  const meta = SOCIAL_PLATFORMS[link.platform] ?? SOCIAL_PLATFORMS.website;
  const handle = (link.handle ?? "").replace(/^@/, "");
  const a = document.createElement("a");
  a.className = "social-badge";
  a.href = meta.url(handle);
  a.target = "_blank";
  a.rel = "noopener";
  a.innerHTML = `
    <span class="glyph" style="background:${meta.color}">${meta.glyph}</span>
    <span>
      <div class="name">${escapeHTML(meta.name)}</div>
      <div class="handle">${escapeHTML(link.platform === "website" ? link.handle : "@" + handle)}</div>
    </span>`;
  return a;
}

function buildVCard(card, fullName) {
  const lines = [
    "BEGIN:VCARD",
    "VERSION:3.0",
    `N:${card.familyName ?? ""};${card.givenName ?? ""};;;`,
    `FN:${fullName}`,
  ];
  if (card.organization) lines.push(`ORG:${card.organization}`);
  if (card.jobTitle) lines.push(`TITLE:${card.jobTitle}`);
  if (card.phoneNumber) lines.push(`TEL;TYPE=CELL:${card.phoneNumber}`);
  if (card.email) lines.push(`EMAIL:${card.email}`);
  if (card.bio) lines.push(`NOTE:${card.bio.replace(/\n/g, "\\n")}`);
  for (const link of card.socialLinks ?? []) {
    const meta = SOCIAL_PLATFORMS[link.platform] ?? SOCIAL_PLATFORMS.website;
    const handle = (link.handle ?? "").replace(/^@/, "");
    lines.push(`URL;TYPE=${link.platform.toUpperCase()}:${meta.url(handle)}`);
  }
  lines.push("END:VCARD");
  return lines.join("\r\n");
}

function initials(given, family) {
  const combined = `${(given || "")[0] ?? ""}${(family || "")[0] ?? ""}`.toUpperCase();
  return combined || "🙂";
}

function setText(root, role, value) {
  const node = root.querySelector(`[data-role="${role}"]`);
  if (!value) { node.remove(); return; }
  node.textContent = value;
}

function escapeHTML(value) {
  const div = document.createElement("div");
  div.textContent = value ?? "";
  return div.innerHTML;
}

function showError(message) {
  app.classList.remove("loading");
  app.innerHTML = `
    <p style="font-size:40px">🔗</p>
    <h1>Card not found</h1>
    <p class="error">${escapeHTML(message)}</p>
    <p class="footer"><a href="https://infome.app">Make your own InfoMe card</a></p>`;
}
