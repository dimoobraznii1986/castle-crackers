'use strict';
/*
 * CASTLE CRACKERS
 * A two-player, turn-based artillery game.
 * Each player has a castle with a treasure inside. Destroy the enemy treasure to win.
 */

// ---------------------------------------------------------------- constants
const W = 1600, H = 900;
const WATER = 838;          // water line (y)
const G = 540;              // gravity, px/s^2
const BS = 18;              // castle block size
const WIND_ACC = 260;       // wind push at wind = 1, px/s^2
const MIN_SPEED = 160, MAX_SPEED = 960;
const TURN_TIME = 45;
const CASTLE_X = [230, 1370];
const PLATEAU = 612;        // ground level under castles
const MAX_SOLDIERS = 6;
const START_GOLD = 100, INCOME = 25;

const TEAM = [
  { name: 'RED', color: '#e2412f', dark: '#8e1e14', light: '#ff9a7b' },
  { name: 'BLUE', color: '#2f7de2', dark: '#173f8a', light: '#8cc4ff' },
];

// kind: shoot = fire from cannon, target = click on map, instant = use at once
const WEAPONS = [
  { id: 'ball', name: 'Cannonball', icon: '⚫', cost: 0, kind: 'shoot', desc: 'Free. Small blast. The wind barely moves it.' },
  { id: 'rocket', name: 'Rocket', icon: '🚀', cost: 30, kind: 'shoot', desc: 'Big blast. The wind pushes it a lot.' },
  { id: 'bounce', name: 'Bouncy Bomb', icon: '💣', cost: 25, kind: 'shoot', desc: 'Bounces around. Explodes after 3 seconds.' },
  { id: 'cluster', name: 'Cluster', icon: '🎆', cost: 45, kind: 'shoot', desc: 'Explodes into 5 small bombs.' },
  { id: 'drill', name: 'Drill Rocket', icon: '🔩', cost: 55, kind: 'shoot', desc: 'Digs through walls and ground, then explodes.' },
  { id: 'mega', name: 'Giant Boulder', icon: '🪨', cost: 0, secret: true, kind: 'shoot', desc: 'SECRET WEAPON. A huge blast.' },
  { id: 'meteor', name: 'Meteor Storm', icon: '☄️', cost: 0, secret: true, kind: 'target', desc: 'SECRET WEAPON. Click a spot. 5 meteors fall from the sky.' },
  { id: 'recruit', name: 'Recruit', icon: '🪖', cost: 40, kind: 'instant', desc: 'Get 3 soldiers in front of your castle.' },
  { id: 'march', name: 'March!', icon: '🥾', cost: 0, kind: 'instant', desc: 'Your soldiers walk to the enemy and attack walls and treasure.' },
  { id: 'wall', name: 'Build Wall', icon: '🧱', cost: 35, kind: 'target', desc: 'Click on your side of the map to drop a stone wall.' },
  { id: 'repair', name: 'Repair', icon: '🔧', cost: 50, kind: 'instant', desc: 'Fix all cracks and rebuild up to 8 lost bricks.' },
  { id: 'armor', name: 'Iron Armor', icon: '🛡️', cost: 110, kind: 'instant', desc: 'Bricks around your treasure become iron. Iron takes half damage.' },
];
const WMAP = Object.fromEntries(WEAPONS.map(w => [w.id, w]));
const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'Q', 'E'];

const PROJ = {
  ball:    { wind: 0.25, blast: 38, dmg: 45 },
  rocket:  { wind: 1.0,  blast: 52, dmg: 58 },
  bounce:  { wind: 0.4,  blast: 58, dmg: 62 },
  cluster: { wind: 0.4,  blast: 30, dmg: 30 },
  bomblet: { wind: 0.2,  blast: 27, dmg: 28 },
  drill:   { wind: 0.6,  blast: 44, dmg: 52 },
  mega:    { wind: 0.15, blast: 92, dmg: 90 },
  meteor:  { wind: 0.5,  blast: 46, dmg: 48 },
};

// Castle layout for the RED castle. BLUE uses the mirror image.
// The treasure sits in the empty room in the middle.
const LAYOUT = [
  '#.#...........',
  '###........###',
  '####.#..#.####',
  '##############',
  '##############',
  '####......####',
  '####......####',
  '####......####',
  '##############',
];

// ---------------------------------------------------------------- helpers
const cv = document.getElementById('game');
const ctx = cv.getContext('2d');
const rnd = (a, b) => a + Math.random() * (b - a);
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
const pick = arr => arr[(Math.random() * arr.length) | 0];
function h2(x, y) {
  let n = Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263);
  n = Math.imul(n ^ (n >>> 13), 1274126177);
  return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
}
function vnoise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y);
  let xf = x - xi, yf = y - yi;
  xf = xf * xf * (3 - 2 * xf); yf = yf * yf * (3 - 2 * yf);
  const a = h2(xi, yi), b = h2(xi + 1, yi), c = h2(xi, yi + 1), d = h2(xi + 1, yi + 1);
  return a + (b - a) * xf + (c - a) * yf + (a - b - c + d) * xf * yf;
}
const inRect = (x, y, o, pad = 0) => x >= o.x - pad && x < o.x + o.w + pad && y >= o.y - pad && y < o.y + o.h + pad;
function rectDist(x, y, o) {
  const dx = Math.max(o.x - x, 0, x - (o.x + o.w));
  const dy = Math.max(o.y - y, 0, y - (o.y + o.h));
  return Math.hypot(dx, dy);
}
const rectsOverlap = (x, y, w, h, o) => x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y;
function rr(c, x, y, w, h, r) {
  c.beginPath();
  c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r);
  c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r);
  c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y); c.closePath();
}
function outlineText(text, x, y, size, fill, align = 'center', stroke = '#1d140b') {
  ctx.font = `900 ${size}px "Trebuchet MS", "Arial Rounded MT Bold", sans-serif`;
  ctx.textAlign = align; ctx.textBaseline = 'alphabetic';
  ctx.lineJoin = 'round'; ctx.lineWidth = Math.max(3, size / 5); ctx.strokeStyle = stroke;
  ctx.strokeText(text, x, y); ctx.fillStyle = fill; ctx.fillText(text, x, y);
}

// ---------------------------------------------------------------- sound (synthesized, no files)
let AC = null, muted = false, noiseBuf = null;
function initAudio() {
  if (!AC) { try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { AC = null; } }
  if (AC && AC.state === 'suspended') AC.resume();
}
function getNoise() {
  if (!noiseBuf) {
    noiseBuf = AC.createBuffer(1, AC.sampleRate * 2, AC.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  return noiseBuf;
}
function sNoise(dur, f0, f1, vol, type = 'lowpass', delay = 0) {
  if (!AC || muted) return;
  const t = AC.currentTime + delay;
  const src = AC.createBufferSource(); src.buffer = getNoise();
  const fl = AC.createBiquadFilter(); fl.type = type;
  fl.frequency.setValueAtTime(f0, t); fl.frequency.exponentialRampToValueAtTime(f1, t + dur);
  const g = AC.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  src.connect(fl).connect(g).connect(AC.destination); src.start(t); src.stop(t + dur);
}
function sTone(f0, f1, dur, vol, type = 'sine', delay = 0) {
  if (!AC || muted) return;
  const t = AC.currentTime + delay;
  const o = AC.createOscillator(); o.type = type;
  o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
  const g = AC.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  o.connect(g).connect(AC.destination); o.start(t); o.stop(t + dur + 0.02);
}
let lastDrill = 0;
const SFX = {
  boom: s => { sNoise(0.45 + s * 0.7, 1000, 50, 0.45 + 0.35 * s); sTone(110, 28, 0.35 + s * 0.4, 0.55); },
  shoot: () => { sNoise(0.25, 2400, 200, 0.3); sTone(170, 45, 0.2, 0.35, 'square'); },
  bounce: () => sTone(320, 200, 0.08, 0.15, 'triangle'),
  clang: () => { sTone(900, 620, 0.12, 0.14, 'triangle'); sTone(1350, 900, 0.09, 0.07, 'square'); },
  chest: () => [523, 659, 784, 1047, 1319].forEach((f, i) => sTone(f, f, 0.16, 0.16, 'triangle', i * 0.07)),
  secret: () => [392, 523, 659, 784, 1047, 784, 1047].forEach((f, i) => sTone(f, f, 0.2, 0.16, 'square', i * 0.09)),
  splash: () => sNoise(0.5, 2500, 300, 0.22, 'bandpass'),
  click: () => sTone(700, 700, 0.04, 0.06, 'square'),
  build: () => { sTone(220, 120, 0.1, 0.22, 'square'); sTone(260, 140, 0.1, 0.18, 'square', 0.12); },
  drill: () => { if (S.t - lastDrill > 0.07) { lastDrill = S.t; sNoise(0.08, 3500, 1800, 0.07, 'bandpass'); } },
  march: () => { for (let i = 0; i < 4; i++) sTone(160, 150, 0.06, 0.14, 'square', i * 0.16); },
  turn: () => { sTone(660, 660, 0.08, 0.1, 'triangle'); sTone(990, 990, 0.12, 0.1, 'triangle', 0.09); },
  win: () => [523, 523, 523, 659, 784, 659, 784, 1047].forEach((f, i) => sTone(f, f, 0.25, 0.18, 'square', i * 0.15)),
  error: () => sTone(180, 140, 0.15, 0.12, 'square'),
};

// ---------------------------------------------------------------- game state
let S = null;
let mask = null, terrainCv = null, tctx = null, bgCv = null;
const GC = Math.ceil(W / BS), GR = Math.ceil(H / BS);
const grid = []; for (let i = 0; i < GC * GR; i++) grid.push([]);
const moving = [];

function mkPlayer(i) {
  return {
    gold: START_GOLD,
    inv: { ball: 0, rocket: 1, bounce: 1, cluster: 0, drill: 0, mega: 0, meteor: 0, recruit: 0, march: 0, wall: 0, repair: 0, armor: 0 },
    angle: i === 0 ? -Math.PI / 4 : -Math.PI * 3 / 4,
    dmg: 0, shots: 0,
  };
}

function newGame() {
  S = {
    state: 'title', turn: 0, turnNo: 1, wind: 0, timer: TURN_TIME, t: 0,
    players: [mkPlayer(0), mkPlayer(1)],
    blocks: [], treasures: [], cannons: [], castles: [], chests: [], soldiers: [], projs: [], parts: [],
    banner: null, msg: null, shake: 0, settle: 0, busyT: 0, power: 0, charging: false,
    weapon: 'ball', mouse: { x: 800, y: 400 }, wake: true, clouds: [],
  };
  makeBackground();
  makeTerrain();
  for (let i = 0; i < 8; i++) S.clouds.push({ x: rnd(0, W), y: rnd(60, 330), s: rnd(0.6, 1.4), v: rnd(0.6, 1.3) });
  buildCastle(0); buildCastle(1);
  rebuildGrid();
  for (let i = 0; i < 2; i++) {
    const x = rnd(470, 1130);
    const c = mkChest(x, 0); c.para = false; c.y = surfaceY(x + 15, 0) - c.h; S.chests.push(c);
  }
}

function beginBattle() {
  newGame();
  S.turn = Math.random() < 0.5 ? 0 : 1;
  startTurn(true);
}

// ---------------------------------------------------------------- terrain
function makeTerrain() {
  mask = new Uint8Array(W * H);
  const heights = new Float32Array(W);
  const p1 = rnd(0, 6.28), p2 = rnd(0, 6.28), p3 = rnd(0, 6.28);
  const mount = rnd(120, 240), mx = 800 + rnd(-70, 70), mw = rnd(130, 190);
  const v1 = rnd(0.2, 1), v2 = rnd(0.2, 1);
  for (let x = 0; x < W; x++) {
    let y = 665 + 34 * Math.sin(x * 0.0047 + p1) + 18 * Math.sin(x * 0.013 + p2) + 7 * Math.sin(x * 0.041 + p3);
    y -= mount * Math.exp(-(((x - mx) / mw) ** 2));
    y += 95 * v1 * Math.exp(-(((x - 530) / 75) ** 2));
    y += 95 * v2 * Math.exp(-(((x - 1070) / 75) ** 2));
    for (const cx of CASTLE_X) { const t = smooth(165, 265, Math.abs(x - cx)); y = PLATEAU * (1 - t) + y * t; }
    heights[x] = y;
    for (let yy = Math.max(0, Math.ceil(y)); yy < H; yy++) mask[yy * W + x] = 1;
  }
  // floating islands
  const nIsl = Math.random() < 0.5 ? 1 : 2;
  for (let k = 0; k < nIsl; k++) {
    const cx = nIsl === 1 ? rnd(720, 880) : (k === 0 ? rnd(560, 680) : rnd(920, 1040));
    const cy = rnd(220, 310), rw = rnd(55, 95), rh = rnd(26, 42);
    for (let x = Math.floor(cx - rw); x <= cx + rw; x++) {
      const t = (x - cx) / rw, s = 1 - t * t;
      if (s <= 0) continue;
      const top = cy - 9 * Math.sqrt(s) + 3 * Math.sin(x * 0.2);
      const bot = cy + rh * s * (0.8 + 0.2 * Math.sin(x * 0.13 + k * 3));
      for (let yy = Math.floor(top); yy < bot; yy++) if (yy >= 0 && yy < H) mask[yy * W + x] = 1;
    }
  }
  paintTerrain(heights);
}

function paintTerrain(heights) {
  terrainCv = document.createElement('canvas'); terrainCv.width = W; terrainCv.height = H;
  tctx = terrainCv.getContext('2d');
  const img = tctx.createImageData(W, H), d = img.data;
  for (let x = 0; x < W; x++) {
    let since = 0;
    for (let y = 0; y < H; y++) {
      const i = y * W + x;
      if (!mask[i]) { since = 0; continue; }
      since++;
      const o = i * 4, grain = h2(x, y) * 16 - 8;
      let r, g, b;
      if (since <= 3) { r = 30; g = 92; b = 24; }
      else if (since <= 12) { const n = vnoise(x / 3, y / 3) * 34; r = 84 + n * 0.5 + grain; g = 176 + n + grain; b = 48 + grain; }
      else if (since <= 15) { r = 58; g = 88; b = 34; }
      else {
        const n = vnoise(x / 22, y / 14), n2 = vnoise(x / 6 + 40, y / 6);
        const band = 0.5 + 0.5 * Math.sin(y * 0.045 + n * 5);
        r = 110 + 32 * band + 28 * n2 + grain;
        g = 70 + 20 * band + 16 * n2 + grain;
        b = 40 + 10 * band + 8 * n2 + grain * 0.5;
      }
      d[o] = r; d[o + 1] = g; d[o + 2] = b; d[o + 3] = 255;
    }
  }
  tctx.putImageData(img, 0, 0);
  // stones in the soil
  tctx.globalCompositeOperation = 'source-atop';
  for (let k = 0; k < 360; k++) {
    const x = rnd(0, W), y = rnd(heights[x | 0] + 24, H);
    const rx = rnd(3, 9), ry = rx * rnd(0.5, 0.8);
    tctx.fillStyle = `rgba(${(55 + rnd(0, 30)) | 0},${(38 + rnd(0, 18)) | 0},24,0.6)`;
    tctx.beginPath(); tctx.ellipse(x, y, rx, ry, rnd(0, 3), 0, 6.283); tctx.fill();
    tctx.fillStyle = 'rgba(255,230,190,0.22)';
    tctx.beginPath(); tctx.ellipse(x - rx * 0.3, y - ry * 0.3, rx * 0.45, ry * 0.4, 0, 0, 6.283); tctx.fill();
  }
  tctx.globalCompositeOperation = 'source-over';
}

function carve(x, y, r, burn = true) {
  tctx.save();
  tctx.globalCompositeOperation = 'destination-out';
  tctx.beginPath(); tctx.arc(x, y, r, 0, 6.2832); tctx.fill();
  if (burn) {
    tctx.globalCompositeOperation = 'source-atop';
    tctx.fillStyle = 'rgba(45,28,14,0.5)';
    tctx.beginPath(); tctx.arc(x, y, r + 6, 0, 6.2832); tctx.fill();
  }
  tctx.restore();
  const r2 = r * r;
  const x0 = Math.max(0, Math.floor(x - r)), x1 = Math.min(W - 1, Math.ceil(x + r));
  const y0 = Math.max(0, Math.floor(y - r)), y1 = Math.min(H - 1, Math.ceil(y + r));
  for (let yy = y0; yy <= y1; yy++) {
    const dy = yy - y, row = yy * W;
    for (let xx = x0; xx <= x1; xx++) { const dx = xx - x; if (dx * dx + dy * dy <= r2) mask[row + xx] = 0; }
  }
  S.wake = true;
}

function makeBackground() {
  bgCv = document.createElement('canvas'); bgCv.width = W; bgCv.height = H;
  const g = bgCv.getContext('2d');
  const grd = g.createLinearGradient(0, 0, 0, H);
  grd.addColorStop(0, '#2a4fa8'); grd.addColorStop(0.45, '#6fb3ef'); grd.addColorStop(0.78, '#ffd9a0'); grd.addColorStop(1, '#ffb27a');
  g.fillStyle = grd; g.fillRect(0, 0, W, H);
  // sun
  const sx = rnd(1000, 1250), sy = 170;
  const sg = g.createRadialGradient(sx, sy, 20, sx, sy, 190);
  sg.addColorStop(0, 'rgba(255,245,190,0.9)'); sg.addColorStop(1, 'rgba(255,245,190,0)');
  g.fillStyle = sg; g.fillRect(0, 0, W, H);
  g.fillStyle = '#fff4b8'; g.strokeStyle = '#e8a640'; g.lineWidth = 4;
  g.beginPath(); g.arc(sx, sy, 46, 0, 6.283); g.fill(); g.stroke();
  // far mountains
  const layers = [
    { base: 560, amp: 90, col: '#9fb4e2', f: 0.006 },
    { base: 640, amp: 70, col: '#7d97cf', f: 0.009 },
  ];
  for (const L of layers) {
    const ph = rnd(0, 6), ph2 = rnd(0, 6);
    g.fillStyle = L.col; g.strokeStyle = 'rgba(40,50,90,0.35)'; g.lineWidth = 3;
    g.beginPath(); g.moveTo(0, H);
    for (let x = 0; x <= W; x += 8) {
      const y = L.base - L.amp * (0.5 + 0.5 * Math.sin(x * L.f + ph)) - L.amp * 0.4 * Math.abs(Math.sin(x * L.f * 2.7 + ph2));
      g.lineTo(x, y);
    }
    g.lineTo(W, H); g.closePath(); g.fill(); g.stroke();
  }
}

// ---------------------------------------------------------------- blocks and world queries
function makeCracks() {
  const out = [];
  for (let k = 0; k < 3; k++) {
    let x = rnd(2, BS - 2), y = rnd(2, BS - 2);
    const e = (Math.random() * 4) | 0;
    if (e === 0) y = 1; else if (e === 1) y = BS - 1; else if (e === 2) x = 1; else x = BS - 1;
    const pts = [[x, y]];
    for (let i = 0; i < 3; i++) {
      x = clamp(x + (BS / 2 - x) * 0.5 + rnd(-4, 4), 1, BS - 1);
      y = clamp(y + (BS / 2 - y) * 0.5 + rnd(-4, 4), 1, BS - 1);
      pts.push([x, y]);
    }
    out.push(pts);
  }
  return out;
}
function mkBlock(x, y, owner) {
  return { x, y, w: BS, h: BS, hp: 40, maxHp: 40, iron: false, owner, vy: 0, tint: rnd(-14, 14), cracks: makeCracks(), flag: false, dead: false };
}

function buildCastle(p) {
  const cx = CASTLE_X[p], x0 = cx - 7 * BS, base = PLATEAU, top0 = base - LAYOUT.length * BS;
  const slots = [];
  LAYOUT.forEach((row, r) => {
    for (let c = 0; c < row.length; c++) {
      const ch = p === 0 ? row[c] : row[row.length - 1 - c];
      if (ch !== '#') continue;
      const b = mkBlock(x0 + c * BS, top0 + r * BS, p);
      if (r === 1 && c === (p === 0 ? 1 : 12)) b.flag = true;
      S.blocks.push(b);
      slots.push({ x: b.x, y: b.y });
    }
  });
  S.castles[p] = { slots };
  S.treasures[p] = { x: cx - 22, y: base - BS - 36, w: 44, h: 36, vy: 0, hp: 100, owner: p, hurt: 0, showHp: 0, isTreasure: true };
  const col = p === 0 ? 12 : 1;
  S.cannons[p] = { x: x0 + col * BS + 9 - 17, y: top0 + BS - 24, w: 34, h: 24, vy: 0, owner: p, recoil: 0 };
}

function rebuildGrid() {
  for (const c of grid) c.length = 0;
  moving.length = 0;
  S.blocks = S.blocks.filter(b => !b.dead);
  for (const b of S.blocks) {
    if (b.vy > 0) { moving.push(b); continue; }
    const c0 = Math.max(0, Math.floor(b.x / BS)), c1 = Math.min(GC - 1, Math.floor((b.x + b.w - 0.01) / BS));
    const r0 = Math.max(0, Math.floor(b.y / BS)), r1 = Math.min(GR - 1, Math.floor((b.y + b.h - 0.01) / BS));
    for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) grid[r * GC + c].push(b);
  }
}
function blockAt(x, y) {
  if (x < 0 || x >= W || y < 0 || y >= H) return null;
  const cell = grid[((y / BS) | 0) * GC + ((x / BS) | 0)];
  for (const b of cell) if (!b.dead && x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h) return b;
  for (const b of moving) if (!b.dead && x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h) return b;
  return null;
}
function solidAt(x, y, ignore) {
  x |= 0; y |= 0;
  if (x < 0 || x >= W || y < 0) return false;
  if (y >= H) return true;
  if (mask[y * W + x]) return true;
  const b = blockAt(x, y);
  if (b && b !== ignore) return true;
  for (const t of S.treasures) if (t !== ignore && inRect(x, y, t)) return true;
  return false;
}
function surfaceY(x, from = 0) {
  for (let y = from; y < H; y++) if (solidAt(x, y)) return y;
  return H;
}
function normalAt(x, y) {
  let nx = 0, ny = 0;
  for (let dy = -6; dy <= 6; dy += 2) for (let dx = -6; dx <= 6; dx += 2) {
    if (dx * dx + dy * dy > 36) continue;
    if (solidAt(x + dx, y + dy)) { nx -= dx; ny -= dy; }
  }
  const l = Math.hypot(nx, ny);
  return l ? { x: nx / l, y: ny / l } : { x: 0, y: -1 };
}
function areaFree(x, y, w, h) {
  const pts = [[x + 2, y + 2], [x + w - 2, y + 2], [x + 2, y + h - 2], [x + w - 2, y + h - 2], [x + w / 2, y + h / 2]];
  for (const [px, py] of pts) if (solidAt(px, py)) return false;
  for (const o of [...S.cannons, ...S.soldiers, ...S.treasures, ...S.chests]) if (rectsOverlap(x, y, w, h, o)) return false;
  return true;
}

// A block stays up if:
//  - something is right under it, or
//  - it is in a short bridge: a standing block is at most 6 blocks away on BOTH sides, or
//  - it sticks out 1 block from a standing block.
function standsOnSomething(b) {
  const by = Math.floor(b.y + b.h);
  return solidAt(b.x + 3, by, b) || solidAt(b.x + b.w - 3, by, b);
}
// how many steps to the nearest standing block on this side (99 = none)
function stepsToStanding(b, dir) {
  let cur = b;
  for (let k = 1; k <= 6; k++) {
    const n = blockAt(dir < 0 ? cur.x - 2 : cur.x + cur.w + 2, cur.y + cur.h / 2);
    if (!n || n === cur || n.vy !== 0) return 99;
    if (standsOnSomething(n)) return k;
    cur = n;
  }
  return 99;
}
function blockSupported(b) {
  if (standsOnSomething(b)) return true;
  const l = stepsToStanding(b, -1), r = stepsToStanding(b, 1);
  if (l < 99 && r < 99) return true;
  return l === 1 || r === 1;
}

function damageBlock(b, amt, owner) {
  if (b.dead) return 0;
  const real = Math.min(b.hp, amt * (b.iron ? 0.45 : 1));
  b.hp -= real;
  if (b.hp <= 0.5) destroyBlock(b);
  return owner != null && b.owner !== owner ? real : 0;
}
function destroyBlock(b) {
  b.dead = true; S.wake = true;
  const col = b.iron ? '#8a9ab0' : '#a89e8c';
  for (let i = 0; i < 5; i++) addP({ type: 'debris', x: b.x + rnd(2, b.w - 2), y: b.y + rnd(2, b.h - 2), vx: rnd(-170, 170), vy: rnd(-320, -60), size: rnd(3, 7), rot: rnd(0, 6), vr: rnd(-10, 10), color: col, life: rnd(1, 2), max: 2 });
  addP({ type: 'smoke', x: b.x + 9, y: b.y + 9, vx: rnd(-10, 10), vy: rnd(-30, -10), r: 8, life: 0.8, max: 0.8, color: '200,190,170' });
}

// ---------------------------------------------------------------- particles and text
function addP(o) { if (S.parts.length < 1800) S.parts.push(o); }
function popText(text, x, y, size, color, life = 1.2) { addP({ type: 'text', text, x, y, vy: -40, size, color, life, max: life }); }
function dust(x, y) { for (let i = 0; i < 4; i++) addP({ type: 'smoke', x: x + rnd(-8, 8), y, vx: rnd(-30, 30), vy: rnd(-20, -5), r: 5, life: 0.6, max: 0.6, color: '210,195,170' }); }
function sparkle(x, y, n = 6, col = '#fff6a0') { for (let i = 0; i < n; i++) addP({ type: 'star', x: x + rnd(-10, 10), y: y + rnd(-10, 10), vx: rnd(-60, 60), vy: rnd(-120, -30), life: rnd(0.6, 1.1), max: 1.1, color: col, size: rnd(3, 6) }); }
function splash(x, y, s = 1) {
  for (let i = 0; i < 14 * s; i++) addP({ type: 'drop', x: x + rnd(-6, 6), y, vx: rnd(-90, 90) * s, vy: rnd(-320, -120) * s, life: 1.2, max: 1.2, size: rnd(2, 4) });
  SFX.splash();
}
function coins(x, y, n = 8) { for (let i = 0; i < n; i++) addP({ type: 'coin', x, y, vx: rnd(-160, 160), vy: rnd(-380, -150), life: rnd(1.2, 2), max: 2, rot: rnd(0, 6) }); }
function setMsg(text, color = '#fff') { S.msg = { text, color, life: 2.2 }; }

// ---------------------------------------------------------------- explosions
const BOOM_WORDS = ['BOOM!', 'KABOOM!', 'POW!', 'BLAM!', 'WHAM!', 'KRAK!'];
function explode(x, y, r, dmg, owner) {
  carve(x, y, r);
  let dealt = 0;
  for (const b of S.blocks) {
    if (b.dead) continue;
    const d = rectDist(x, y, b);
    if (d < r) dealt += damageBlock(b, dmg * (1 - 0.6 * d / r), owner);
  }
  for (const t of S.treasures) {
    const d = rectDist(x, y, t);
    if (d >= r || t.hp <= 0) continue;
    const occ = countOccluders(x, y, t.x + t.w / 2, t.y + t.h / 2);
    const amt = Math.round(dmg * 0.9 * (1 - 0.5 * d / r) * Math.pow(0.4, occ));
    if (amt >= 1) {
      t.hp = Math.max(0, t.hp - amt); t.hurt = 1; t.showHp = 3;
      popText('-' + amt, t.x + t.w / 2, t.y - 14, 34, '#ff3b30', 1.6);
      coins(t.x + t.w / 2, t.y + 6, Math.min(14, 3 + amt / 4));
      if (owner != null && t.owner !== owner) dealt += amt * 2;
    }
  }
  for (const s of S.soldiers) {
    const d = rectDist(x, y, s);
    if (d < r) {
      const f = 1 - d / r;
      s.hp -= dmg * 1.1 * f; s.vy = -260 * f; s.y -= 3;
      if (owner != null && s.owner !== owner) dealt += 10 * f;
    }
  }
  for (const c of S.chests.slice()) if (rectDist(x, y, c) < r + 6) openChest(c, owner);

  // effects
  addP({ type: 'flash', x, y, r: r * 1.5, life: 0.22, max: 0.22 });
  addP({ type: 'ring', x, y, r, life: 0.35, max: 0.35 });
  for (let i = 0; i < 12 + r / 3; i++) {
    const a = rnd(0, 6.283), sp = rnd(40, 260) * (r / 45);
    addP({ type: 'fire', x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: rnd(0.25, 0.6), max: 0.6, size: rnd(4, 9) * (r / 45) });
  }
  for (let i = 0; i < 6 + r / 6; i++) addP({ type: 'smoke', x: x + rnd(-r / 2, r / 2), y: y + rnd(-r / 2, r / 3), vx: rnd(-20, 20), vy: rnd(-70, -20), r: rnd(8, 16) * (r / 45), life: rnd(1, 2), max: 2, color: '70,62,58' });
  for (let i = 0; i < 8 + r / 4; i++) addP({ type: 'debris', x, y, vx: rnd(-280, 280), vy: rnd(-460, -120), size: rnd(2, 6), rot: rnd(0, 6), vr: rnd(-12, 12), color: pick(['#7a4f2b', '#5c3a1e', '#4a9a32', '#8f6a45']), life: rnd(1, 2), max: 2 });
  if (r >= 34) popText(pick(BOOM_WORDS), x + rnd(-20, 20), y - r * 0.6, Math.min(64, 26 + r * 0.45), pick(['#ffe14a', '#ff8a2a', '#fff']), 1);
  S.shake = Math.max(S.shake, Math.min(20, r / 3.2));
  SFX.boom(clamp(r / 90, 0.1, 1));

  if (owner != null && dealt > 0) {
    const g = Math.round(dealt / 6);
    if (g > 0) { S.players[owner].gold += g; popText('+' + g + ' gold', x, y - r - 30, 20, '#ffd84a', 1.4); }
    S.players[owner].dmg += dealt;
  }
}
function countOccluders(x0, y0, x1, y1) {
  const seen = new Set();
  const n = Math.ceil(Math.hypot(x1 - x0, y1 - y0) / 5);
  for (let i = 1; i < n; i++) {
    const t = i / n;
    const b = blockAt(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
    if (b) seen.add(b);
  }
  return seen.size;
}

// ---------------------------------------------------------------- bonus crates
function mkChest(x, y) { return { x, y, w: 30, h: 26, vy: 0, para: true, sway: rnd(0, 6) }; }
const LOOT = [
  { w: 26, f: p => { const g = 40 + ((Math.random() * 5) | 0) * 15; S.players[p].gold += g; return `💰 ${g} gold`; } },
  { w: 14, f: p => { S.players[p].inv.rocket += 2; return '🚀 2 Rockets'; } },
  { w: 10, f: p => { S.players[p].inv.cluster += 1; return '🎆 a Cluster Bomb'; } },
  { w: 10, f: p => { S.players[p].inv.drill += 1; return '🔩 a Drill Rocket'; } },
  { w: 10, f: p => { S.players[p].inv.bounce += 2; return '💣 2 Bouncy Bombs'; } },
  { w: 8, f: p => { repair(p); return '🔧 Free repair! Castle fixed'; } },
  { w: 7, f: p => { armor(p); return '🛡️ IRON ARMOR for the castle!'; } },
  { w: 6, f: p => { S.players[p].inv.recruit += 1; return '🪖 Free soldiers'; } },
  { w: 5, secret: true, f: p => { S.players[p].inv.meteor += 1; return '☄️ SECRET WEAPON: Meteor Storm!'; } },
  { w: 5, secret: true, f: p => { S.players[p].inv.mega += 1; return '🪨 SECRET WEAPON: Giant Boulder!'; } },
];
function openChest(c, who) {
  if (c.opened) return;
  c.opened = true;
  S.chests = S.chests.filter(o => o !== c);
  sparkle(c.x + 15, c.y + 13, 16);
  for (let i = 0; i < 6; i++) addP({ type: 'debris', x: c.x + 15, y: c.y + 13, vx: rnd(-200, 200), vy: rnd(-350, -100), size: rnd(4, 8), rot: rnd(0, 6), vr: rnd(-10, 10), color: '#c8873a', life: 1.5, max: 1.5 });
  if (who == null) return;
  let total = LOOT.reduce((s, l) => s + l.w, 0), roll = Math.random() * total, loot = LOOT[0];
  for (const l of LOOT) { roll -= l.w; if (roll <= 0) { loot = l; break; } }
  const text = loot.f(who);
  S.banner = { text: `${TEAM[who].name} FOUND`, sub: text, life: 2.8, max: 2.8, color: TEAM[who].color };
  if (loot.secret) SFX.secret(); else SFX.chest();
}
function dropChest() {
  if (S.chests.length >= 3) return;
  S.chests.push(mkChest(rnd(470, 1130), -40));
  setMsg('📦 A bonus crate is falling! Shoot it to open it.', '#ffe9a0');
}

// ---------------------------------------------------------------- actions
function canUse(p, w, quiet = true) {
  const P = S.players[p];
  const say = (m) => { if (!quiet) { setMsg(m, '#ffb0a0'); SFX.error(); } return false; };
  if (w.id === 'march' && !S.soldiers.some(s => s.owner === p)) return say('You have no soldiers. Recruit some first!');
  if (w.id === 'recruit' && S.soldiers.filter(s => s.owner === p).length >= MAX_SOLDIERS) return say(`You already have ${MAX_SOLDIERS} soldiers.`);
  if (P.inv[w.id] > 0) return true;
  if (w.secret) return say('Secret weapon! Find it in a bonus crate.');
  if (P.gold < w.cost) return say(`Not enough gold. ${w.name} costs ${w.cost}.`);
  return true;
}
function pay(p, w) {
  const P = S.players[p];
  if (P.inv[w.id] > 0) P.inv[w.id]--; else P.gold -= w.cost;
}

function selectWeapon(id) {
  if (!S || S.state !== 'aim') return;
  const w = WMAP[id];
  if (w.secret && !(S.players[S.turn].inv[id] > 0)) { canUse(S.turn, w, false); return; }
  S.weapon = id; S.charging = false; S.power = 0;
  SFX.click();
  renderBar();
}

function useWeapon(mx, my) {
  if (S.state !== 'aim') return;
  const p = S.turn, w = WMAP[S.weapon];
  if (w.kind === 'shoot') {
    if (!canUse(p, w, false)) return;
    S.charging = true; S.power = 0;
    return;
  }
  if (w.kind === 'target') {
    if (w.id === 'wall') {
      const g = wallGhost(mx);
      if (!g.ok) { setMsg(g.why, '#ffb0a0'); SFX.error(); return; }
      if (!canUse(p, w, false)) return;
      pay(p, w); buildWall(p, g);
    } else if (w.id === 'meteor') {
      if (!canUse(p, w, false)) return;
      pay(p, w); meteorStorm(p, mx);
    }
    endAction();
    return;
  }
  // instant
  if (!canUse(p, w, false)) return;
  pay(p, w);
  if (w.id === 'recruit') { recruit(p); SFX.build(); }
  else if (w.id === 'march') marchSoldiers(p);
  else if (w.id === 'repair') { const n = repair(p); setMsg(n ? 'Castle repaired!' : 'Nothing to repair.'); SFX.build(); }
  else if (w.id === 'armor') { armor(p); setMsg('Iron armor added around the treasure!'); SFX.secret(); }
  endAction();
}

function fire() {
  const p = S.turn, w = WMAP[S.weapon], P = S.players[p];
  S.charging = false;
  if (!canUse(p, w, false)) { S.power = 0; return; }
  pay(p, w);
  const c = S.cannons[p];
  const px = c.x + c.w / 2, py = c.y + 8, a = P.angle;
  const sp = MIN_SPEED + S.power * (MAX_SPEED - MIN_SPEED);
  const ox = px + Math.cos(a) * 32, oy = py + Math.sin(a) * 32;
  S.projs.push(mkProj(w.id, ox, oy, Math.cos(a) * sp, Math.sin(a) * sp, p));
  for (let i = 0; i < 8; i++) addP({ type: 'smoke', x: ox, y: oy, vx: Math.cos(a) * rnd(20, 90) + rnd(-20, 20), vy: Math.sin(a) * rnd(20, 90) + rnd(-20, 20), r: rnd(5, 10), life: 0.9, max: 0.9, color: '230,230,230' });
  addP({ type: 'flash', x: ox, y: oy, r: 22, life: 0.12, max: 0.12 });
  c.recoil = 1;
  S.shake = Math.max(S.shake, 4);
  P.shots++;
  S.power = 0;
  SFX.shoot();
  endAction();
}

function endAction() {
  S.state = 'busy'; S.busyT = 0; S.settle = 0; S.charging = false;
  renderBar();
}

function startTurn(first = false) {
  S.state = 'aim';
  S.timer = TURN_TIME;
  S.wind = Math.round(rnd(-1, 1) * 10) / 10;
  S.weapon = 'ball'; S.power = 0; S.charging = false;
  if (!first) {
    S.players[S.turn].gold += INCOME;
    S.turnNo++;
    if (Math.random() < 0.5) dropChest();
  }
  S.banner = { text: `${TEAM[S.turn].name}'S TURN`, sub: first ? 'Destroy the enemy treasure!' : `+${INCOME} gold`, life: 1.8, max: 1.8, color: TEAM[S.turn].color };
  SFX.turn();
  renderBar();
}

function nextTurn() {
  const dead = S.treasures.filter(t => t.hp <= 0);
  if (dead.length) { gameOver(dead); return; }
  S.turn = 1 - S.turn;
  startTurn();
}

function gameOver(dead) {
  S.state = 'over';
  renderBar();
  for (const t of dead) { coins(t.x + t.w / 2, t.y + 10, 40); explode(t.x + t.w / 2, t.y + t.h / 2, 60, 0, null); t.gone = true; }
  const winner = dead.length === 2 ? -1 : 1 - dead[0].owner;
  SFX.win();
  setTimeout(() => {
    const ot = document.getElementById('overTitle');
    if (winner < 0) { ot.textContent = "IT'S A DRAW!"; ot.style.color = '#ffd84a'; document.getElementById('overSub').textContent = 'Both treasures are gone!'; }
    else {
      ot.textContent = `${TEAM[winner].name} WINS!`; ot.style.color = TEAM[winner].light;
      document.getElementById('overSub').textContent = `The ${TEAM[1 - winner].name.toLowerCase()} treasure is destroyed in ${S.turnNo} turns!`;
    }
    document.getElementById('over').classList.remove('hidden');
  }, 1800);
}

// build wall: 2 blocks wide, 4 blocks tall, drops from the sky
function wallGhost(mx) {
  const p = S.turn;
  const bx = Math.round(mx / BS) * BS - BS;
  const g = { x: bx, w: BS * 2, h: BS * 4, ok: true, why: '' };
  const top = Math.min(surfaceY(bx + 3), surfaceY(bx + BS), surfaceY(bx + 2 * BS - 3));
  g.y = top - g.h;
  const mid = W / 2;
  if ((p === 0 && bx + g.w > mid - 80) || (p === 1 && bx < mid + 80)) { g.ok = false; g.why = 'Build on your own side of the map.'; }
  else if (bx < 0 || bx + g.w > W) { g.ok = false; g.why = 'Too close to the edge.'; }
  else if (top >= WATER || g.y < 20) { g.ok = false; g.why = 'You cannot build there.'; }
  else {
    for (const o of [...S.cannons, ...S.treasures, ...S.soldiers]) if (rectsOverlap(g.x, g.y - 30, g.w, g.h + 30, o)) { g.ok = false; g.why = 'Something is in the way.'; }
  }
  return g;
}
function buildWall(p, g) {
  for (let r = 0; r < 4; r++) for (let c = 0; c < 2; c++) {
    const b = mkBlock(g.x + c * BS, g.y - 30 + r * BS, p);
    S.blocks.push(b);
  }
  rebuildGrid();
  S.wake = true;
  sparkle(g.x + BS, g.y + 20, 10, '#fff');
  SFX.build();
}

function meteorStorm(p, tx) {
  for (let i = 0; i < 5; i++) {
    const x = tx + (i - 2) * 42 + rnd(-10, 10);
    const pr = mkProj('meteor', x - 190, -60 - i * 90, 170, 260, p);
    pr.t = 1;
    S.projs.push(pr);
  }
  popText('METEOR STORM!', tx, 200, 50, '#ff8a2a', 2);
  SFX.secret();
}

function recruit(p) {
  const have = S.soldiers.filter(s => s.owner === p).length;
  const n = Math.min(3, MAX_SOLDIERS - have);
  const dir = p === 0 ? 1 : -1;
  for (let i = 0; i < n; i++) {
    const fx = CASTLE_X[p] + dir * (150 + i * 18);
    const s = { x: fx - 6, y: 0, w: 12, h: 22, vy: 0, hp: 30, owner: p, dir, walk: 0, acc: 0, anim: rnd(0, 6), atk: 0, marchT: 0 };
    s.y = surfaceY(fx, 300) - s.h - 30 - i * 12;
    S.soldiers.push(s);
    sparkle(fx, s.y + 10, 6, '#fff');
  }
  setMsg(`${n} soldiers are ready! Use March! to attack.`);
  return n;
}
function marchSoldiers(p) {
  for (const s of S.soldiers) if (s.owner === p) { s.walk = 240; s.marchT = 0; }
  setMsg('Forward, march!');
  SFX.march();
}

function repair(p) {
  let n = 0;
  for (const b of S.blocks) if (b.owner === p && !b.dead && b.hp < b.maxHp) { b.hp = b.maxHp; n++; sparkle(b.x + 9, b.y + 9, 2, '#9fffa0'); }
  const t = S.treasures[p], tx = t.x + t.w / 2, ty = t.y + t.h / 2;
  const slots = S.castles[p].slots.slice().sort((a, b) => Math.hypot(a.x + 9 - tx, a.y + 9 - ty) - Math.hypot(b.x + 9 - tx, b.y + 9 - ty));
  let built = 0;
  for (const sl of slots) {
    if (built >= 8) break;
    if (!areaFree(sl.x, sl.y, BS, BS)) continue;
    S.blocks.push(mkBlock(sl.x, sl.y, p));
    rebuildGrid();
    built++;
    sparkle(sl.x + 9, sl.y + 9, 4, '#9fffa0');
  }
  S.wake = true;
  return n + built;
}
function armor(p) {
  const t = S.treasures[p], tx = t.x + t.w / 2, ty = t.y + t.h / 2;
  let n = 0;
  for (const b of S.blocks) {
    if (b.owner !== p || b.dead) continue;
    if (Math.hypot(b.x + 9 - tx, b.y + 9 - ty) < 125) { b.iron = true; b.maxHp = 100; b.hp = 100; n++; sparkle(b.x + 9, b.y + 9, 2, '#cfe6ff'); }
  }
  return n;
}

// ---------------------------------------------------------------- projectiles
function mkProj(type, x, y, vx, vy, owner) {
  return { type, x, y, vx, vy, owner, t: 0, fuse: type === 'bounce' ? 3 : 0, drilling: false, dtime: 0, dead: false, lastBounce: 0 };
}
function projHit(p) {
  const x = p.x | 0, y = p.y | 0;
  if (y < 0) return null;
  if (x >= 0 && x < W && y < H && mask[y * W + x]) return 'terrain';
  if (blockAt(x, y)) return 'block';
  for (const t of S.treasures) if (inRect(x, y, t, 2)) return 'treasure';
  for (const c of S.chests) if (inRect(x, y, c, 3)) return 'chest';
  for (const s of S.soldiers) if (inRect(x, y, s, 2)) return 'soldier';
  return null;
}
function impact(p) {
  const d = PROJ[p.type];
  explode(p.x, p.y, d.blast, d.dmg, p.owner);
  if (p.type === 'cluster') {
    for (let i = 0; i < 5; i++) {
      const b = mkProj('bomblet', p.x, p.y - 8, rnd(-230, 230), rnd(-400, -220), p.owner);
      b.t = 0.02;
      S.projs.push(b);
    }
  }
  p.dead = true;
}
function updateProj(p, dt) {
  p.t += dt;
  const def = PROJ[p.type];
  if (p.drilling) { updateDrill(p, dt); return; }
  if (p.type === 'bounce') {
    p.fuse -= dt;
    if (p.fuse <= 0) { impact(p); return; }
  }
  const sp = Math.hypot(p.vx, p.vy);
  const n = Math.max(1, Math.ceil(sp * dt / 3)), sdt = dt / n;
  for (let i = 0; i < n; i++) {
    p.vx += S.wind * WIND_ACC * def.wind * sdt;
    p.vy += G * sdt;
    const ox = p.x, oy = p.y;
    p.x += p.vx * sdt; p.y += p.vy * sdt;
    if (p.x < -300 || p.x > W + 300 || p.y > H) { p.dead = true; return; }
    if (p.y >= WATER) { splash(p.x, WATER); p.dead = true; return; }
    if (p.t < 0.04) continue;
    const hit = projHit(p);
    if (!hit) continue;
    if (p.type === 'bounce') {
      p.x = ox; p.y = oy;
      const nn = normalAt(p.x, p.y);
      const dot = p.vx * nn.x + p.vy * nn.y;
      if (dot < 0) { p.vx -= 2 * dot * nn.x; p.vy -= 2 * dot * nn.y; }
      p.vx *= 0.55; p.vy *= 0.55;
      if (Math.abs(dot) > 60 && S.t - p.lastBounce > 0.1) { SFX.bounce(); p.lastBounce = S.t; }
      break;
    }
    if (p.type === 'drill' && hit !== 'treasure') {
      const l = Math.hypot(p.vx, p.vy) || 1;
      p.drilling = true; p.dtime = 0.8; p.dx = p.vx / l; p.dy = p.vy / l;
      return;
    }
    impact(p);
    return;
  }
  // trails
  if (p.type === 'rocket' || p.type === 'drill') {
    addP({ type: 'smoke', x: p.x - p.vx * 0.02, y: p.y - p.vy * 0.02, vx: rnd(-10, 10), vy: rnd(-20, 0), r: 4, life: 0.8, max: 0.8, color: '235,235,235' });
    addP({ type: 'fire', x: p.x - p.vx * 0.015, y: p.y - p.vy * 0.015, vx: -p.vx * 0.1, vy: -p.vy * 0.1, life: 0.15, max: 0.15, size: 4 });
  } else if (p.type === 'meteor') {
    for (let k = 0; k < 2; k++) addP({ type: 'fire', x: p.x + rnd(-4, 4), y: p.y + rnd(-4, 4), vx: -p.vx * 0.2, vy: -p.vy * 0.2, life: 0.35, max: 0.35, size: rnd(5, 9) });
    addP({ type: 'smoke', x: p.x, y: p.y, vx: 0, vy: -10, r: 7, life: 1, max: 1, color: '90,70,60' });
  } else if (Math.random() < 0.5) {
    addP({ type: 'smoke', x: p.x, y: p.y, vx: 0, vy: -8, r: 2.5, life: 0.5, max: 0.5, color: '255,255,255' });
  }
}
function updateDrill(p, dt) {
  p.dtime -= dt;
  const step = 270 * dt;
  p.x += p.dx * step; p.y += p.dy * step;
  carve(p.x, p.y, 10, false);
  for (const [ox, oy] of [[0, 0], [-p.dy * 7, p.dx * 7], [p.dy * 7, -p.dx * 7]]) {
    const b = blockAt(p.x + ox, p.y + oy);
    if (b && !b.drilled) {
      b.drilled = true;
      damageBlock(b, b.iron ? 45 : 60, p.owner);
      p.dtime -= 0.05;
      SFX.clang();
    }
  }
  for (let i = 0; i < 2; i++) addP({ type: 'spark', x: p.x, y: p.y, vx: rnd(-150, 150) - p.dx * 100, vy: rnd(-150, 50) - p.dy * 100, life: 0.3, max: 0.3 });
  SFX.drill();
  for (const t of S.treasures) if (inRect(p.x, p.y, t, 2)) { impact(p); return; }
  if (p.y >= WATER || p.x < 0 || p.x > W) { splash(p.x, WATER); p.dead = true; return; }
  if (p.dtime <= 0) impact(p);
}

// ---------------------------------------------------------------- bodies (things that fall)
function bodySupported(o) {
  const by = Math.floor(o.y + o.h);
  return solidAt(o.x + 3, by, o) || solidAt(o.x + o.w / 2, by, o) || solidAt(o.x + o.w - 3, by, o);
}
function fallBody(o, dt, maxV = 750) {
  if (bodySupported(o)) { const hard = o.vy > 150; o.vy = 0; return hard ? 'land' : 'rest'; }
  o.vy = Math.min(o.vy + G * dt, maxV);
  const steps = Math.max(1, Math.round(o.vy * dt));
  for (let i = 0; i < steps; i++) { o.y += 1; if (bodySupported(o)) break; }
  return 'fall';
}

function updateBlocks(dt) {
  if (!S.wake) return;
  let any = false;
  const arr = S.blocks.filter(b => !b.dead).sort((a, b) => b.y - a.y);
  for (const b of arr) {
    if (blockSupported(b)) {
      if (b.vy > 150) dust(b.x + b.w / 2, b.y + b.h);
      if (b.vy > 0) any = true;
      b.vy = 0;
      continue;
    }
    any = true;
    b.vy = Math.min(b.vy + G * dt, 800);
    const steps = Math.max(1, Math.round(b.vy * dt));
    for (let i = 0; i < steps; i++) {
      b.y += 1;
      if (b.y > WATER) { b.dead = true; splash(b.x + b.w / 2, WATER, 0.6); break; }
      if (blockSupported(b)) break;
    }
  }
  S.wake = any;
}

function updateBodies(dt) {
  for (const t of S.treasures) {
    if (t.gone) continue;
    const r = fallBody(t, dt);
    if (r === 'land') dust(t.x + t.w / 2, t.y + t.h);
    if (t.y + t.h > WATER + 6 && t.hp > 0) { t.hp = 0; splash(t.x + t.w / 2, WATER, 1.5); S.banner = { text: 'SPLASH!', sub: `The ${TEAM[t.owner].name.toLowerCase()} treasure sank!`, life: 2.5, max: 2.5, color: TEAM[t.owner].color }; }
    t.hurt = Math.max(0, t.hurt - dt * 3);
    t.showHp = Math.max(0, t.showHp - dt);
  }
  for (const c of S.cannons) {
    const r = fallBody(c, dt);
    if (r === 'land') dust(c.x + c.w / 2, c.y + c.h);
    c.recoil = Math.max(0, c.recoil - dt * 4);
    if (c.y + c.h > WATER + 4) respawnCannon(c);
  }
  for (const c of S.chests) {
    c.sway += dt * 2;
    const r = fallBody(c, dt, c.para ? 95 : 750);
    if (r === 'rest' || r === 'land') { if (c.para) dust(c.x + 15, c.y + c.h); c.para = false; }
  }
  S.chests = S.chests.filter(c => {
    if (c.y + c.h > WATER + 4) { splash(c.x + 15, WATER, 0.7); return false; }
    return true;
  });
}
function respawnCannon(c) {
  splash(c.x + c.w / 2, WATER);
  const own = S.blocks.filter(b => b.owner === c.owner && !b.dead);
  let x = CASTLE_X[c.owner];
  if (own.length) { const top = own.reduce((a, b) => (b.y < a.y ? b : a)); x = top.x + top.w / 2; }
  c.x = x - c.w / 2; c.y = 40; c.vy = 0;
  setMsg(`The ${TEAM[c.owner].name.toLowerCase()} cannon fell in the water. A new one drops in!`);
}

// ---------------------------------------------------------------- soldiers
function enemyThingAt(x, y, owner) {
  const b = blockAt(x, y);
  if (b && b.owner !== owner) return b;
  for (const t of S.treasures) if (t.owner !== owner && t.hp > 0 && inRect(x, y, t)) return t;
  return null;
}
function soldierStep(s) {
  const fx = s.x + s.w / 2 + s.dir * (s.w / 2 + 2), feet = s.y + s.h;
  const tgt = enemyThingAt(fx, feet - 5, s.owner) || enemyThingAt(fx, feet - 14, s.owner);
  if (tgt) { soldierAttack(s, tgt); s.walk = 0; return; }
  let climb = 0;
  while (climb <= 20 && solidAt(fx, feet - 1 - climb)) climb++;
  if (climb > 20 || solidAt(fx, feet - 1 - climb - s.h + 3)) {
    // blocked: hit any enemy brick in front, from the feet up to above the head
    let t2 = null;
    for (let dy = 2; dy <= 40 && !t2; dy += 4) t2 = enemyThingAt(fx, feet - dy, s.owner);
    if (t2) soldierAttack(s, t2);
    s.walk = 0;
    return;
  }
  s.x += s.dir; s.y -= climb; s.walk--;
  if (s.x < -20 || s.x > W + 20) s.walk = 0;
}
function soldierAttack(s, tgt) {
  s.atk = 0.5;
  if (tgt.isTreasure) {
    tgt.hp = Math.max(0, tgt.hp - 10); tgt.hurt = 1; tgt.showHp = 3;
    S.players[s.owner].gold += 5;
    popText('STEAL! -10', tgt.x + tgt.w / 2, tgt.y - 12, 22, '#ffd84a');
    coins(tgt.x + tgt.w / 2, tgt.y + 8, 5);
  } else {
    damageBlock(tgt, 40, s.owner);
    popText('CLANG!', s.x + 6 + s.dir * 10, s.y - 6, 16, '#fff', 0.8);
    for (let i = 0; i < 5; i++) addP({ type: 'spark', x: s.x + 6 + s.dir * 9, y: s.y + 8, vx: rnd(-120, 120), vy: rnd(-160, 20), life: 0.3, max: 0.3 });
  }
  SFX.clang();
}
function updateSoldiers(dt) {
  for (const s of S.soldiers) {
    s.anim += dt;
    s.atk = Math.max(0, s.atk - dt);
    const r = fallBody(s, dt);
    if (s.y + s.h > WATER + 4) { s.hp = 0; splash(s.x + 6, WATER, 0.6); }
    if (s.hp <= 0) {
      s.dead = true;
      addP({ type: 'smoke', x: s.x + 6, y: s.y + 10, vx: 0, vy: -30, r: 12, life: 1, max: 1, color: '240,240,240' });
      popText('Ouch!', s.x + 6, s.y - 4, 16, TEAM[s.owner].light);
      continue;
    }
    if (s.walk > 0) {
      s.marchT += dt;
      if (s.marchT > 9) s.walk = 0;
      if (r === 'rest' || r === 'land') {
        s.acc += 75 * dt;
        while (s.acc >= 1 && s.walk > 0) { s.acc -= 1; soldierStep(s); }
      }
    }
    for (const c of S.chests.slice()) if (rectsOverlap(s.x, s.y, s.w, s.h, c)) openChest(c, s.owner);
  }
  S.soldiers = S.soldiers.filter(s => !s.dead);
}

// ---------------------------------------------------------------- particles update
function updateParts(dt) {
  for (const p of S.parts) {
    p.life -= dt;
    switch (p.type) {
      case 'smoke': p.x += p.vx * dt; p.y += p.vy * dt; p.r += dt * 14; break;
      case 'fire': p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 0.92; p.vy *= 0.92; p.vy -= 30 * dt; break;
      case 'debris': case 'coin': case 'drop':
        p.vy += G * dt; p.x += p.vx * dt; p.y += p.vy * dt; if (p.rot != null) p.rot += (p.vr || 8) * dt;
        if (p.vy > 0 && solidAt(p.x, p.y)) { p.vy *= -0.35; p.vx *= 0.6; p.y -= 2; }
        if (p.y > WATER) p.life = Math.min(p.life, 0.05);
        break;
      case 'spark': p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 300 * dt; break;
      case 'star': p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 80 * dt; break;
      case 'text': p.y += p.vy * dt; p.vy *= 0.96; break;
    }
  }
  S.parts = S.parts.filter(p => p.life > 0);
}

// ---------------------------------------------------------------- main update
function update(dt) {
  S.t += dt;
  rebuildGrid();
  for (const c of S.clouds) { c.x += (10 + S.wind * 45) * c.v * dt; if (c.x > W + 150) c.x = -150; if (c.x < -150) c.x = W + 150; }

  if (S.state === 'aim') {
    S.timer -= dt;
    if (S.charging) { S.power += dt / 2; if (S.power >= 1) { S.power = 1; fire(); } }
    if (S.timer <= 0) { setMsg('Time is up!', '#ffb0a0'); S.charging = false; endAction(); }
  }

  for (const p of S.projs) updateProj(p, dt);
  S.projs = S.projs.filter(p => !p.dead);
  updateBlocks(dt);
  updateBodies(dt);
  updateSoldiers(dt);
  updateParts(dt);

  if (S.state === 'busy') {
    S.busyT += dt;
    const quiet = !S.projs.length && !S.wake &&
      !S.treasures.some(t => t.vy > 0) && !S.cannons.some(c => c.vy > 0) &&
      !S.soldiers.some(s => s.walk > 0 || s.vy > 0);
    if (quiet && S.busyT > 0.5) S.settle += dt; else S.settle = 0;
    if (S.settle > 0.8 || S.busyT > 25) nextTurn();
  }

  S.shake = Math.max(0, S.shake - dt * 30);
  if (S.banner) { S.banner.life -= dt; if (S.banner.life <= 0) S.banner = null; }
  if (S.msg) { S.msg.life -= dt; if (S.msg.life <= 0) S.msg = null; }
}

// ---------------------------------------------------------------- drawing
function drawClouds() {
  for (const c of S.clouds) {
    const s = c.s;
    ctx.fillStyle = 'rgba(120,150,200,0.35)';
    for (const [dx, dy, r] of [[0, 6, 26], [30, 10, 22], [-28, 12, 20], [14, -8, 22]]) { ctx.beginPath(); ctx.arc(c.x + dx * s, c.y + (dy + 6) * s, r * s, 0, 6.283); ctx.fill(); }
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    for (const [dx, dy, r] of [[0, 6, 26], [30, 10, 22], [-28, 12, 20], [14, -8, 22]]) { ctx.beginPath(); ctx.arc(c.x + dx * s, c.y + dy * s, r * s, 0, 6.283); ctx.fill(); }
  }
}
function wavePath(off, speed, phase) {
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 16) {
    const y = WATER + off + Math.sin(x * 0.02 + S.t * speed + phase) * 4 + Math.sin(x * 0.05 - S.t * 1.1) * 2;
    ctx.lineTo(x, y);
  }
  ctx.lineTo(W, H); ctx.closePath();
}
function drawWater(front) {
  if (!front) { wavePath(-5, 1.3, 2); ctx.fillStyle = '#1d4f99'; ctx.fill(); return; }
  wavePath(4, 2, 0);
  const g = ctx.createLinearGradient(0, WATER, 0, H);
  g.addColorStop(0, 'rgba(60,140,230,0.82)'); g.addColorStop(1, 'rgba(20,60,140,0.95)');
  ctx.fillStyle = g; ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,0.7)'; ctx.lineWidth = 3;
  ctx.beginPath();
  for (let x = 0; x <= W; x += 16) {
    const y = WATER + 4 + Math.sin(x * 0.02 + S.t * 2) * 4 + Math.sin(x * 0.05 - S.t * 1.1) * 2;
    if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.stroke();
}

function drawBlocks() {
  for (const b of S.blocks) {
    if (b.dead) continue;
    const r = b.hp / b.maxHp, k = 0.62 + 0.38 * r;
    let cr, cg, cb;
    if (b.iron) { cr = 122; cg = 138; cb = 162; }
    else { cr = 174 + b.tint + (b.owner === 0 ? 10 : -4); cg = 162 + b.tint; cb = 140 + b.tint + (b.owner === 1 ? 16 : 0); }
    ctx.fillStyle = `rgb(${(cr * k) | 0},${(cg * k) | 0},${(cb * k) | 0})`;
    ctx.fillRect(b.x, b.y, b.w, b.h);
    ctx.fillStyle = 'rgba(255,255,255,0.28)'; ctx.fillRect(b.x + 2, b.y + 2, b.w - 4, 3);
    ctx.fillStyle = 'rgba(0,0,0,0.22)'; ctx.fillRect(b.x + 2, b.y + b.h - 4, b.w - 4, 3);
    ctx.strokeStyle = '#3b3027'; ctx.lineWidth = 1.5; ctx.strokeRect(b.x + 0.75, b.y + 0.75, b.w - 1.5, b.h - 1.5);
    if (b.iron) {
      ctx.fillStyle = '#e4ecf5';
      for (const [dx, dy] of [[4, 4], [b.w - 4, 4], [4, b.h - 4], [b.w - 4, b.h - 4]]) { ctx.beginPath(); ctx.arc(b.x + dx, b.y + dy, 1.6, 0, 6.283); ctx.fill(); }
    }
    const n = r < 0.3 ? 3 : r < 0.6 ? 2 : r < 0.92 ? 1 : 0;
    if (n) {
      ctx.strokeStyle = '#1e1813'; ctx.lineWidth = 1.4; ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const c = b.cracks[i];
        ctx.moveTo(b.x + c[0][0], b.y + c[0][1]);
        for (let j = 1; j < c.length; j++) ctx.lineTo(b.x + c[j][0], b.y + c[j][1]);
      }
      ctx.stroke();
    }
  }
  for (const b of S.blocks) if (b.flag && !b.dead) drawFlag(b);
}
function drawFlag(b) {
  const x = b.x + b.w / 2, y = b.y, T = TEAM[b.owner];
  ctx.strokeStyle = '#3b2a1a'; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y - 50); ctx.stroke();
  const dir = S.wind >= 0 ? 1 : -1, len = 22 + Math.abs(S.wind) * 14;
  ctx.beginPath(); ctx.moveTo(x, y - 50);
  for (let i = 1; i <= 6; i++) ctx.lineTo(x + dir * len * i / 6, y - 50 + Math.sin(S.t * 7 + i) * 2.5 * i / 6);
  for (let i = 6; i >= 0; i--) ctx.lineTo(x + dir * len * i / 6, y - 32 + Math.sin(S.t * 7 + i) * 2.5 * i / 6);
  ctx.closePath();
  ctx.fillStyle = T.color; ctx.fill(); ctx.strokeStyle = '#1d140b'; ctx.lineWidth = 2; ctx.stroke();
  ctx.fillStyle = '#ffd84a'; ctx.beginPath(); ctx.arc(x + dir * len * 0.45, y - 41, 3.5, 0, 6.283); ctx.fill();
}

function drawTreasure(t) {
  if (t.gone) return;
  const { x, y, w, h } = t, T = TEAM[t.owner];
  const pulse = 0.45 + 0.15 * Math.sin(S.t * 3 + t.owner);
  const g = ctx.createRadialGradient(x + w / 2, y + h / 2, 4, x + w / 2, y + h / 2, 50);
  g.addColorStop(0, `rgba(255,225,110,${pulse})`); g.addColorStop(1, 'rgba(255,225,110,0)');
  ctx.fillStyle = g; ctx.fillRect(x - 30, y - 30, w + 60, h + 60);
  // gold pile
  ctx.strokeStyle = '#8a5a00'; ctx.lineWidth = 1.5;
  for (const [dx, dy, r] of [[9, 0.52, 7], [17, 0.4, 8], [27, 0.42, 8], [35, 0.52, 7], [22, 0.3, 6]]) {
    ctx.fillStyle = '#ffd23f'; ctx.beginPath(); ctx.arc(x + dx, y + h * dy, r, 0, 6.283); ctx.fill(); ctx.stroke();
  }
  // chest box
  rr(ctx, x + 2, y + h * 0.48, w - 4, h * 0.52, 4);
  ctx.fillStyle = '#8a4b1f'; ctx.fill(); ctx.strokeStyle = '#2b1709'; ctx.lineWidth = 2.5; ctx.stroke();
  ctx.fillStyle = '#e8b33a';
  ctx.fillRect(x + 8, y + h * 0.48 + 1, 4, h * 0.52 - 2); ctx.fillRect(x + w - 12, y + h * 0.48 + 1, 4, h * 0.52 - 2);
  ctx.fillRect(x + w / 2 - 4, y + h * 0.62, 8, 8);
  // crown
  const cx = x + w / 2, cy = y + h * 0.3;
  ctx.beginPath();
  ctx.moveTo(cx - 12, cy); ctx.lineTo(cx - 13, cy - 13); ctx.lineTo(cx - 6, cy - 6); ctx.lineTo(cx, cy - 17);
  ctx.lineTo(cx + 6, cy - 6); ctx.lineTo(cx + 13, cy - 13); ctx.lineTo(cx + 12, cy); ctx.closePath();
  ctx.fillStyle = '#ffcc1f'; ctx.fill(); ctx.strokeStyle = '#6b4300'; ctx.lineWidth = 2; ctx.stroke();
  ctx.fillStyle = T.color; ctx.beginPath(); ctx.arc(cx, cy - 5, 3.5, 0, 6.283); ctx.fill(); ctx.stroke();
  if (Math.sin(S.t * 2.3 + t.owner * 2) > 0.85) drawStar(cx + 10, cy - 14, 5, '#fff');
  if (t.hurt > 0) { ctx.fillStyle = `rgba(255,255,255,${t.hurt * 0.7})`; ctx.fillRect(x, y - 16, w, h + 16); }
  if (t.showHp > 0) {
    ctx.globalAlpha = Math.min(1, t.showHp);
    rr(ctx, x - 4, y - 32, w + 8, 10, 4); ctx.fillStyle = '#2b1b0e'; ctx.fill();
    ctx.fillStyle = t.hp > 50 ? '#6be04a' : t.hp > 25 ? '#ffc62a' : '#ff4a3a';
    ctx.fillRect(x - 2, y - 30, (w + 4) * t.hp / 100, 6);
    ctx.globalAlpha = 1;
  }
}
function drawStar(x, y, r, col) {
  ctx.fillStyle = col; ctx.beginPath();
  for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4, rr2 = i % 2 ? r * 0.35 : r; ctx.lineTo(x + Math.cos(a) * rr2, y + Math.sin(a) * rr2); }
  ctx.closePath(); ctx.fill();
}

function drawChest(c) {
  const { x, y, w, h } = c;
  ctx.save();
  if (c.para) {
    const sw = Math.sin(c.sway) * 0.12;
    ctx.translate(x + w / 2, y); ctx.rotate(sw); ctx.translate(-(x + w / 2), -y);
    const px = x + w / 2, py = y - 40;
    ctx.strokeStyle = '#333'; ctx.lineWidth = 1.2; ctx.beginPath();
    ctx.moveTo(x + 2, y); ctx.lineTo(px - 30, py); ctx.moveTo(x + w - 2, y); ctx.lineTo(px + 30, py);
    ctx.moveTo(x + w / 2, y); ctx.lineTo(px, py - 2); ctx.stroke();
    for (let i = 0; i < 5; i++) {
      ctx.beginPath(); ctx.moveTo(px, py);
      ctx.arc(px, py, 32, Math.PI + i * Math.PI / 5, Math.PI + (i + 1) * Math.PI / 5); ctx.closePath();
      ctx.fillStyle = i % 2 ? '#fff' : '#e8412f'; ctx.fill();
    }
    ctx.beginPath(); ctx.arc(px, py, 32, Math.PI, 0); ctx.strokeStyle = '#1d140b'; ctx.lineWidth = 2.5; ctx.stroke();
  }
  ctx.fillStyle = '#c8873a'; ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = '#8a5520'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(x, y + h / 3); ctx.lineTo(x + w, y + h / 3); ctx.moveTo(x, y + 2 * h / 3); ctx.lineTo(x + w, y + 2 * h / 3); ctx.stroke();
  ctx.strokeStyle = '#3a2410'; ctx.lineWidth = 2.5; ctx.strokeRect(x, y, w, h);
  ctx.fillStyle = '#777';
  for (const [dx, dy] of [[0, 0], [w - 5, 0], [0, h - 5], [w - 5, h - 5]]) ctx.fillRect(x + dx, y + dy, 5, 5);
  outlineText('?', x + w / 2, y + h / 2 + 8, 22, '#fff');
  ctx.restore();
}

function drawCannon(c, p) {
  const P = S.players[p], T = TEAM[p];
  const px = c.x + c.w / 2, py = c.y + 8;
  ctx.save(); ctx.translate(px, py); ctx.rotate(P.angle);
  const rec = -c.recoil * 8;
  rr(ctx, rec - 8, -7, 40, 14, 6); ctx.fillStyle = '#3d3d46'; ctx.fill(); ctx.strokeStyle = '#141418'; ctx.lineWidth = 2.5; ctx.stroke();
  ctx.fillStyle = 'rgba(255,255,255,0.28)'; ctx.fillRect(rec - 4, -5, 32, 3);
  ctx.fillStyle = T.color; ctx.fillRect(rec + 18, -8, 5, 16); ctx.strokeRect(rec + 18, -8, 5, 16);
  rr(ctx, rec + 30, -8.5, 6, 17, 2); ctx.fillStyle = '#26262c'; ctx.fill(); ctx.stroke();
  ctx.restore();
  ctx.beginPath();
  ctx.moveTo(c.x + 3, c.y + c.h - 5); ctx.lineTo(c.x + c.w - 3, c.y + c.h - 5); ctx.lineTo(px + 9, py + 1); ctx.lineTo(px - 9, py + 1); ctx.closePath();
  ctx.fillStyle = '#7a4a22'; ctx.fill(); ctx.strokeStyle = '#2b1709'; ctx.lineWidth = 2.5; ctx.stroke();
  for (const wx of [c.x + 9, c.x + c.w - 9]) {
    const wy = c.y + c.h - 8;
    ctx.beginPath(); ctx.arc(wx, wy, 8, 0, 6.283); ctx.fillStyle = '#5a3416'; ctx.fill(); ctx.stroke();
    ctx.lineWidth = 1.5; ctx.beginPath();
    for (let i = 0; i < 3; i++) { const a = i * Math.PI / 3 + wx; ctx.moveTo(wx + Math.cos(a) * 7, wy + Math.sin(a) * 7); ctx.lineTo(wx - Math.cos(a) * 7, wy - Math.sin(a) * 7); }
    ctx.stroke(); ctx.lineWidth = 2.5;
    ctx.fillStyle = '#d9a441'; ctx.beginPath(); ctx.arc(wx, wy, 2.5, 0, 6.283); ctx.fill();
  }
}

function drawSoldier(s) {
  const T = TEAM[s.owner], fx = s.x + s.w / 2, by = s.y + s.h, d = s.dir;
  const walking = s.walk > 0 && s.vy === 0;
  const ph = walking ? Math.sin(s.anim * 14) * 3.5 : 0;
  ctx.strokeStyle = '#1d140b'; ctx.lineWidth = 3; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(fx - 2, by - 7); ctx.lineTo(fx - 2 + ph, by - 1); ctx.moveTo(fx + 2, by - 7); ctx.lineTo(fx + 2 - ph, by - 1); ctx.stroke();
  // spear
  const sw = s.atk > 0 ? Math.sin(s.atk * 12) * 0.8 : 0;
  ctx.save(); ctx.translate(fx + d * 5, by - 12); ctx.rotate(d * (0.35 + sw));
  ctx.strokeStyle = '#6b4a22'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(0, 6); ctx.lineTo(0, -16); ctx.stroke();
  ctx.fillStyle = '#d8dde5'; ctx.beginPath(); ctx.moveTo(-3, -15); ctx.lineTo(0, -22); ctx.lineTo(3, -15); ctx.closePath(); ctx.fill();
  ctx.restore();
  // body
  rr(ctx, fx - 5.5, by - 16, 11, 10, 3); ctx.fillStyle = T.color; ctx.fill(); ctx.strokeStyle = '#1d140b'; ctx.lineWidth = 2; ctx.stroke();
  // head
  ctx.beginPath(); ctx.arc(fx, by - 20.5, 5.5, 0, 6.283); ctx.fillStyle = '#ffcfa6'; ctx.fill(); ctx.stroke();
  // helmet
  ctx.beginPath(); ctx.arc(fx, by - 21.5, 6, Math.PI, 0); ctx.closePath(); ctx.fillStyle = T.dark; ctx.fill(); ctx.stroke();
  // eyes
  ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(fx + d * 2.5, by - 19.5, 2.2, 0, 6.283); ctx.fill();
  ctx.fillStyle = '#000'; ctx.beginPath(); ctx.arc(fx + d * 3.2, by - 19.5, 1.1, 0, 6.283); ctx.fill();
  ctx.lineCap = 'butt';
  if (s.hp < 30) { ctx.fillStyle = '#2b1b0e'; ctx.fillRect(fx - 8, by - 34, 16, 4); ctx.fillStyle = '#6be04a'; ctx.fillRect(fx - 7, by - 33, 14 * s.hp / 30, 2); }
}

function drawProj(p) {
  if (p.y < -6) {
    // off the top of the screen: show a marker
    ctx.fillStyle = TEAM[p.owner].color; ctx.strokeStyle = '#1d140b'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(p.x, 4); ctx.lineTo(p.x - 8, 18); ctx.lineTo(p.x + 8, 18); ctx.closePath(); ctx.fill(); ctx.stroke();
    return;
  }
  const a = Math.atan2(p.vy, p.vx);
  ctx.strokeStyle = '#111'; ctx.lineWidth = 2;
  switch (p.type) {
    case 'ball': case 'bomblet': {
      const r = p.type === 'ball' ? 6 : 4;
      ctx.fillStyle = '#26262c'; ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, 6.283); ctx.fill(); ctx.stroke();
      ctx.fillStyle = 'rgba(255,255,255,0.5)'; ctx.beginPath(); ctx.arc(p.x - r / 3, p.y - r / 3, r / 3, 0, 6.283); ctx.fill();
      break;
    }
    case 'cluster':
      ctx.fillStyle = '#d8322a'; ctx.beginPath(); ctx.arc(p.x, p.y, 7, 0, 6.283); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#ffd84a'; for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.arc(p.x + Math.cos(i * 1.57 + S.t * 8) * 3.5, p.y + Math.sin(i * 1.57 + S.t * 8) * 3.5, 1.6, 0, 6.283); ctx.fill(); }
      break;
    case 'bounce':
      ctx.fillStyle = '#3f8f2b'; ctx.beginPath(); ctx.arc(p.x, p.y, 7, 0, 6.283); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#aaa'; ctx.fillRect(p.x - 2, p.y - 11, 4, 4);
      outlineText(String(Math.ceil(p.fuse)), p.x, p.y - 16, 16, '#fff');
      break;
    case 'mega':
      ctx.fillStyle = '#7d756c'; ctx.beginPath(); ctx.arc(p.x, p.y, 13, 0, 6.283); ctx.fill(); ctx.lineWidth = 3; ctx.stroke();
      ctx.fillStyle = '#5d564f'; ctx.beginPath(); ctx.arc(p.x - 4, p.y + 3, 3, 0, 6.283); ctx.arc(p.x + 5, p.y - 4, 2.5, 0, 6.283); ctx.fill();
      break;
    case 'meteor': {
      const g = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, 22);
      g.addColorStop(0, 'rgba(255,220,120,0.9)'); g.addColorStop(1, 'rgba(255,90,20,0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(p.x, p.y, 22, 0, 6.283); ctx.fill();
      ctx.fillStyle = '#6b3a24'; ctx.beginPath(); ctx.arc(p.x, p.y, 9, 0, 6.283); ctx.fill(); ctx.stroke();
      break;
    }
    case 'rocket': case 'drill': {
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.drilling ? Math.atan2(p.dy, p.dx) : a);
      if (p.type === 'rocket') {
        rr(ctx, -12, -4.5, 20, 9, 3); ctx.fillStyle = '#e9e9ee'; ctx.fill(); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(8, -4.5); ctx.lineTo(15, 0); ctx.lineTo(8, 4.5); ctx.closePath(); ctx.fillStyle = '#e2412f'; ctx.fill(); ctx.stroke();
        ctx.fillStyle = '#e2412f'; ctx.beginPath(); ctx.moveTo(-12, -4); ctx.lineTo(-16, -9); ctx.lineTo(-8, -4); ctx.moveTo(-12, 4); ctx.lineTo(-16, 9); ctx.lineTo(-8, 4); ctx.fill();
      } else {
        rr(ctx, -12, -5, 14, 10, 2); ctx.fillStyle = '#d6a420'; ctx.fill(); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(2, -5); ctx.lineTo(16, 0); ctx.lineTo(2, 5); ctx.closePath(); ctx.fillStyle = '#c9d0d8'; ctx.fill(); ctx.stroke();
        ctx.strokeStyle = '#666'; ctx.lineWidth = 1; const o = (S.t * 60) % 4;
        ctx.beginPath(); for (let i = 0; i < 3; i++) { ctx.moveTo(4 + i * 4 + o, -4 + i); ctx.lineTo(6 + i * 4 + o, 4 - i); } ctx.stroke();
      }
      ctx.restore();
      break;
    }
  }
}

function drawParts() {
  for (const p of S.parts) {
    const f = clamp(p.life / p.max, 0, 1);
    switch (p.type) {
      case 'smoke':
        ctx.fillStyle = `rgba(${p.color},${0.55 * f})`; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.283); ctx.fill(); break;
      case 'fire':
        ctx.fillStyle = f > 0.6 ? '#fff3a0' : f > 0.3 ? '#ffb22a' : '#e8461f';
        ctx.beginPath(); ctx.arc(p.x, p.y, p.size * (0.5 + f * 0.6), 0, 6.283); ctx.fill(); break;
      case 'debris':
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot); ctx.globalAlpha = Math.min(1, f * 2);
        ctx.fillStyle = p.color; ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size);
        ctx.strokeStyle = 'rgba(0,0,0,0.5)'; ctx.lineWidth = 1; ctx.strokeRect(-p.size / 2, -p.size / 2, p.size, p.size);
        ctx.restore(); break;
      case 'coin':
        ctx.save(); ctx.translate(p.x, p.y); ctx.scale(Math.abs(Math.cos(p.rot)) + 0.15, 1); ctx.globalAlpha = Math.min(1, f * 2);
        ctx.fillStyle = '#ffd23f'; ctx.strokeStyle = '#8a5a00'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(0, 0, 4.5, 0, 6.283); ctx.fill(); ctx.stroke(); ctx.restore(); break;
      case 'drop':
        ctx.fillStyle = `rgba(190,230,255,${f})`; ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, 6.283); ctx.fill(); break;
      case 'spark':
        ctx.strokeStyle = `rgba(255,230,120,${f})`; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 0.03, p.y - p.vy * 0.03); ctx.stroke(); break;
      case 'star':
        ctx.globalAlpha = f; drawStar(p.x, p.y, p.size, p.color); ctx.globalAlpha = 1; break;
      case 'flash': {
        const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r);
        g.addColorStop(0, `rgba(255,255,230,${f})`); g.addColorStop(0.5, `rgba(255,210,90,${f * 0.7})`); g.addColorStop(1, 'rgba(255,140,40,0)');
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.283); ctx.fill(); break;
      }
      case 'ring':
        ctx.strokeStyle = `rgba(255,255,255,${f * 0.8})`; ctx.lineWidth = 4 * f + 1;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.r * (1.6 - f * 0.8), 0, 6.283); ctx.stroke(); break;
    }
  }
  // text on top
  for (const p of S.parts) {
    if (p.type !== 'text') continue;
    const f = clamp(p.life / p.max, 0, 1), age = 1 - f;
    const sc = age < 0.12 ? 0.4 + age / 0.12 * 0.8 : 1.2 - Math.min(0.2, (age - 0.12));
    ctx.save(); ctx.globalAlpha = Math.min(1, f * 3); ctx.translate(p.x, p.y); ctx.scale(sc, sc);
    outlineText(p.text, 0, 0, p.size, p.color); ctx.restore();
  }
}

function drawAim() {
  if (S.state !== 'aim') return;
  const p = S.turn, c = S.cannons[p], T = TEAM[p], w = WMAP[S.weapon];
  const px = c.x + c.w / 2, py = c.y + 8;
  // bouncing arrow over the active cannon
  const by = c.y - 30 + Math.sin(S.t * 6) * 5;
  ctx.beginPath(); ctx.moveTo(px - 10, by - 12); ctx.lineTo(px + 10, by - 12); ctx.lineTo(px, by); ctx.closePath();
  ctx.fillStyle = T.color; ctx.fill(); ctx.strokeStyle = '#1d140b'; ctx.lineWidth = 2.5; ctx.stroke();
  if (w.kind === 'shoot') {
    const a = S.players[p].angle, dx = Math.cos(a), dy = Math.sin(a);
    const hx = px + dx * 110, hy = py + dy * 110;
    ctx.strokeStyle = T.color; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.arc(hx, hy, 10, 0, 6.283); ctx.moveTo(hx - 15, hy); ctx.lineTo(hx - 5, hy); ctx.moveTo(hx + 5, hy); ctx.lineTo(hx + 15, hy);
    ctx.moveTo(hx, hy - 15); ctx.lineTo(hx, hy - 5); ctx.moveTo(hx, hy + 5); ctx.lineTo(hx, hy + 15); ctx.stroke();
    // power wedge
    if (S.charging) {
      const n = Math.floor(S.power * 18);
      for (let i = 0; i <= n; i++) {
        const t = i / 18, d = 38 + i * 6.5;
        ctx.fillStyle = `hsl(${120 - t * 120},90%,50%)`;
        ctx.beginPath(); ctx.arc(px + dx * d, py + dy * d, 2.5 + t * 6, 0, 6.283); ctx.fill();
      }
      outlineText(Math.round(S.power * 100) + '%', px, c.y - 50, 18, '#fff');
    }
  } else if (S.weapon === 'wall') {
    const g = wallGhost(S.mouse.x);
    ctx.globalAlpha = 0.55;
    ctx.fillStyle = g.ok ? '#bfe8b0' : '#ff8a7a';
    ctx.fillRect(g.x, g.y, g.w, g.h);
    ctx.strokeStyle = g.ok ? '#2f7a1f' : '#a01e10'; ctx.lineWidth = 3; ctx.setLineDash([6, 5]); ctx.strokeRect(g.x, g.y, g.w, g.h); ctx.setLineDash([]);
    ctx.globalAlpha = 1;
  } else if (S.weapon === 'meteor') {
    const x = S.mouse.x;
    ctx.strokeStyle = 'rgba(255,90,40,0.8)'; ctx.lineWidth = 3; ctx.setLineDash([10, 8]);
    ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, WATER); ctx.stroke(); ctx.setLineDash([]);
    ctx.strokeStyle = '#ff5a28'; ctx.beginPath(); ctx.arc(x, surfaceY(x | 0, 30), 30, 0, 6.283); ctx.stroke();
  }
}

function drawHUD() {
  for (let p = 0; p < 2; p++) drawPanel(p);
  // wind
  const cx = W / 2, y = 14;
  rr(ctx, cx - 160, y, 320, 58, 14); ctx.fillStyle = 'rgba(255,248,230,0.94)'; ctx.fill(); ctx.strokeStyle = '#2b1b0e'; ctx.lineWidth = 4; ctx.stroke();
  outlineText('WIND', cx, y + 22, 18, '#9fdcff');
  rr(ctx, cx - 130, y + 32, 260, 16, 8); ctx.fillStyle = '#2b1b0e'; ctx.fill();
  const wl = S.wind * 124;
  if (Math.abs(wl) > 1) {
    const g = ctx.createLinearGradient(cx, 0, cx + wl, 0);
    g.addColorStop(0, '#9fe7ff'); g.addColorStop(1, '#2fa4ff');
    ctx.fillStyle = g; ctx.fillRect(Math.min(cx, cx + wl), y + 35, Math.abs(wl), 10);
    const s = Math.sign(wl), off = (S.t * 40 * Math.abs(S.wind)) % 14;
    ctx.fillStyle = 'rgba(255,255,255,0.8)';
    for (let k = off; k < Math.abs(wl) - 4; k += 14) {
      const ax = cx + s * k;
      ctx.beginPath(); ctx.moveTo(ax, y + 36); ctx.lineTo(ax + s * 5, y + 40); ctx.lineTo(ax, y + 44); ctx.closePath(); ctx.fill();
    }
  } else outlineText('calm', cx, y + 46, 13, '#fff');
  ctx.fillStyle = '#fff'; ctx.fillRect(cx - 1, y + 30, 2, 20);
  // timer
  if (S.state === 'aim' || S.state === 'busy') {
    const tt = Math.max(0, Math.ceil(S.timer));
    ctx.beginPath(); ctx.arc(cx, 106, 28, 0, 6.283); ctx.fillStyle = TEAM[S.turn].color; ctx.fill(); ctx.strokeStyle = '#2b1b0e'; ctx.lineWidth = 4; ctx.stroke();
    outlineText(S.state === 'aim' ? String(tt) : '...', cx, 115, 26, tt <= 10 && S.state === 'aim' ? '#ffe14a' : '#fff');
  }
}
function drawPanel(p) {
  const P = S.players[p], T = TEAM[p], t = S.treasures[p];
  const w = 360, h = 92, x = p === 0 ? 16 : W - 16 - w, y = 12;
  const active = S.turn === p && (S.state === 'aim' || S.state === 'busy');
  if (active) { rr(ctx, x - 5, y - 5, w + 10, h + 10, 20); ctx.fillStyle = T.color; ctx.globalAlpha = 0.55 + 0.3 * Math.sin(S.t * 5); ctx.fill(); ctx.globalAlpha = 1; }
  rr(ctx, x, y, w, h, 16); ctx.fillStyle = 'rgba(255,248,230,0.95)'; ctx.fill(); ctx.strokeStyle = '#2b1b0e'; ctx.lineWidth = 4; ctx.stroke();
  outlineText(`${T.name} KINGDOM`, x + 16, y + 30, 24, T.color, 'left');
  // treasure bar
  ctx.font = '22px sans-serif'; ctx.textAlign = 'left'; ctx.fillText('👑', x + 14, y + 72);
  rr(ctx, x + 46, y + 52, 190, 24, 10); ctx.fillStyle = '#3a2a1a'; ctx.fill();
  const hp = Math.max(0, t.hp);
  if (hp > 0) {
    rr(ctx, x + 49, y + 55, 184 * hp / 100, 18, 8);
    const g = ctx.createLinearGradient(0, y + 55, 0, y + 73); g.addColorStop(0, '#fff09a'); g.addColorStop(1, hp > 30 ? '#f0a81e' : '#e0401e');
    ctx.fillStyle = g; ctx.fill();
  }
  outlineText(`${Math.ceil(hp)} / 100`, x + 141, y + 70, 15, '#fff');
  // gold and soldiers
  ctx.font = '20px sans-serif'; ctx.fillText('💰', x + 250, y + 34);
  outlineText(String(P.gold), x + 280, y + 34, 22, '#ffd84a', 'left');
  ctx.font = '20px sans-serif'; ctx.fillText('🪖', x + 250, y + 72);
  outlineText('x' + S.soldiers.filter(s => s.owner === p).length, x + 280, y + 72, 22, '#fff', 'left');
}

function drawOverlayText() {
  if (S.banner) {
    const b = S.banner, age = b.max - b.life, f = clamp(b.life / 0.4, 0, 1);
    const sc = age < 0.2 ? 0.5 + age / 0.2 * 0.5 : 1;
    ctx.save(); ctx.globalAlpha = f; ctx.translate(W / 2, 250); ctx.scale(sc, sc);
    outlineText(b.text, 0, 0, 68, b.color || '#fff');
    if (b.sub) outlineText(b.sub, 0, 52, 32, '#fff');
    ctx.restore();
  }
  if (S.msg) {
    ctx.globalAlpha = clamp(S.msg.life / 0.4, 0, 1);
    outlineText(S.msg.text, W / 2, 770, 24, S.msg.color);
    ctx.globalAlpha = 1;
  }
  if (S.state === 'aim') {
    const w = WMAP[S.weapon];
    let hint;
    if (w.kind === 'shoot') hint = 'Move the mouse to aim. Hold the mouse (or SPACE) to charge. Let go to fire.';
    else if (w.id === 'wall') hint = 'Click on your side of the map to build a wall.';
    else if (w.id === 'meteor') hint = 'Click where the meteors should fall.';
    else hint = `Click on the map (or press SPACE) to use ${w.name}.`;
    outlineText(`${w.icon} ${w.name}: ${w.desc}`, W / 2, 712, 20, '#fff');
    outlineText(hint, W / 2, 740, 17, '#ffe9a0');
  }
}

function draw() {
  ctx.drawImage(bgCv, 0, 0);
  ctx.save();
  if (S.shake > 0) ctx.translate(rnd(-S.shake, S.shake), rnd(-S.shake, S.shake));
  drawClouds();
  drawWater(false);
  ctx.drawImage(terrainCv, 0, 0);
  drawBlocks();
  for (const t of S.treasures) drawTreasure(t);
  for (const c of S.chests) drawChest(c);
  S.cannons.forEach((c, i) => drawCannon(c, i));
  for (const s of S.soldiers) drawSoldier(s);
  for (const p of S.projs) drawProj(p);
  drawParts();
  drawAim();
  drawWater(true);
  ctx.restore();
  if (S.state !== 'title') { drawHUD(); drawOverlayText(); }
}

// ---------------------------------------------------------------- weapon bar (HTML)
function renderBar() {
  const bar = document.getElementById('bar');
  bar.innerHTML = '';
  if (!S || S.state === 'title' || S.state === 'over') return;
  const p = S.turn, P = S.players[p];
  bar.classList.toggle('busy', S.state !== 'aim');
  bar.style.setProperty('--team', TEAM[p].color);
  WEAPONS.forEach((w, i) => {
    const inv = P.inv[w.id] || 0, locked = w.secret && inv <= 0;
    const b = document.createElement('button');
    b.className = 'wbtn' + (S.weapon === w.id ? ' sel' : '') + (canUse(p, w) ? '' : ' off') + (locked ? ' locked' : '');
    let tag = '';
    if (inv > 0) tag = `<span class="tag free">x${inv}</span>`;
    else if (!w.secret) tag = w.cost ? `<span class="tag">💰${w.cost}</span>` : '<span class="tag free">FREE</span>';
    b.innerHTML = `<div class="key">${KEYS[i]}</div><div class="ic">${locked ? '🔒' : w.icon}</div><div class="nm">${locked ? 'Secret' : w.name}</div>${tag}`;
    b.title = locked ? 'Secret weapon. Find it in a bonus crate!' : w.desc;
    b.onclick = () => selectWeapon(w.id);
    bar.appendChild(b);
  });
}

// ---------------------------------------------------------------- input
function toWorld(e) {
  const r = cv.getBoundingClientRect();
  return { x: (e.clientX - r.left) * W / r.width, y: (e.clientY - r.top) * H / r.height };
}
function aimAt(m) {
  if (S.state !== 'aim') return;
  const c = S.cannons[S.turn];
  S.players[S.turn].angle = Math.atan2(m.y - (c.y + 8), m.x - (c.x + c.w / 2));
}
cv.addEventListener('mousemove', e => {
  if (!S) return;
  S.mouse = toWorld(e);
  if (WMAP[S.weapon].kind === 'shoot') aimAt(S.mouse);
});
cv.addEventListener('mousedown', e => {
  if (!S || S.state !== 'aim' || e.button !== 0) return;
  initAudio();
  S.mouse = toWorld(e);
  if (WMAP[S.weapon].kind === 'shoot') aimAt(S.mouse);
  useWeapon(S.mouse.x, S.mouse.y);
});
window.addEventListener('mouseup', () => { if (S && S.charging && S.state === 'aim') fire(); });
window.addEventListener('keydown', e => {
  if (!S) return;
  if (e.code === 'Space') e.preventDefault();
  if (e.key === 'm' || e.key === 'M') { toggleMute(); return; }
  if (S.state !== 'aim') return;
  const P = S.players[S.turn];
  if (e.code === 'Space' && !e.repeat) { initAudio(); useWeapon(S.mouse.x, S.mouse.y); return; }
  if (e.key === 'ArrowLeft') P.angle -= 0.025;
  if (e.key === 'ArrowRight') P.angle += 0.025;
  if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
    const up = e.key === 'ArrowUp' ? 1 : -1, facingRight = Math.cos(P.angle) >= 0;
    P.angle += (facingRight ? -0.025 : 0.025) * up;
    e.preventDefault();
  }
  const i = KEYS.indexOf(e.key.toUpperCase());
  if (i >= 0) selectWeapon(WEAPONS[i].id);
});
window.addEventListener('keyup', e => { if (e.code === 'Space' && S && S.charging && S.state === 'aim') fire(); });

function toggleMute() {
  muted = !muted;
  document.getElementById('mute').textContent = muted ? '🔇' : '🔊';
}
document.getElementById('mute').onclick = () => { toggleMute(); };
document.getElementById('startBtn').onclick = () => {
  initAudio();
  document.getElementById('title').classList.add('hidden');
  beginBattle();
};
document.getElementById('againBtn').onclick = () => {
  document.getElementById('over').classList.add('hidden');
  beginBattle();
};

function fit() {
  const s = Math.min(window.innerWidth / W, window.innerHeight / H);
  document.getElementById('wrap').style.transform = `scale(${s})`;
}
window.addEventListener('resize', fit);
fit();

// ---------------------------------------------------------------- loop
newGame();
let last = performance.now();
function frame(now) {
  const dt = Math.min(1 / 30, (now - last) / 1000);
  last = now;
  update(dt);
  draw();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
window.__game = () => S; // for debugging in the browser console
