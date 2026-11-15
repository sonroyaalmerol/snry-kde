const SCRIPT_ID = "snry-workspaces";
const WORKSPACES_PER_SCREEN = 5;

const cfgScreen1 = String(readConfig("screen1Name", "") || "").trim();
const cfgScreen2 = String(readConfig("screen2Name", "") || "").trim();
const moveCursor = readConfig("moveCursor", true) !== false;

const NUMBER_KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];
const SHIFTED_KEYS = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"];

function log(msg) {
  print(SCRIPT_ID + ": " + msg);
}

function screenName(s) {
  return s && s.name ? s.name : "<none>";
}

function findScreenByName(name) {
  if (!name) {
    return null;
  }
  const list = workspace.screens;
  for (let i = 0; i < list.length; i++) {
    if (list[i].name === name) {
      return list[i];
    }
  }
  return null;
}

function screensLeftToRight() {
  return workspace.screens.slice().sort(function (a, b) {
    const ga = a.geometry;
    const gb = b.geometry;
    if (ga.x !== gb.x) {
      return ga.x - gb.x;
    }
    if (ga.y !== gb.y) {
      return ga.y - gb.y;
    }
    return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
  });
}

function firstScreenExcept(exclude) {
  const sorted = screensLeftToRight();
  for (let i = 0; i < sorted.length; i++) {
    if (sorted[i] !== exclude) {
      return sorted[i];
    }
  }
  return null;
}

function resolveScreens() {
  const named2 = findScreenByName(cfgScreen2);
  const s1 = findScreenByName(cfgScreen1) || firstScreenExcept(named2);
  const s2 = (named2 !== s1 ? named2 : null) || firstScreenExcept(s1);
  return { s1: s1 || s2, s2: s2 || s1 };
}

function screenOrderIndex(screen) {
  const order = workspace.screenOrder || workspace.screens;
  for (let i = 0; i < order.length; i++) {
    if (order[i] === screen) {
      return i;
    }
  }
  return -1;
}

function desktopAt(oneBased) {
  const list = workspace.desktops;
  if (oneBased < 1 || oneBased > list.length) {
    log("no desktop " + oneBased + " (have " + list.length + ")");
    return null;
  }
  return list[oneBased - 1];
}

function ensureDesktopCount() {
  const have = workspace.desktops.length;
  for (let i = have; i < WORKSPACES_PER_SCREEN; i++) {
    try {
      workspace.createDesktop(i, "Desktop " + (i + 1));
    } catch (e) {
      log("createDesktop failed: " + e);
      return;
    }
  }
  if (have < WORKSPACES_PER_SCREEN) {
    log("created desktops " + (have + 1) + ".." + WORKSPACES_PER_SCREEN);
  }
}

function invokeKwinShortcut(name) {
  callDBus(
    "org.kde.kglobalaccel",
    "/component/kwin",
    "org.kde.kglobalaccel.Component",
    "invokeShortcut",
    name,
  );
}

function isFocusable(w) {
  if (!w || w.deleted || w.minimized || w.skipTaskbar) {
    return false;
  }
  if (w.specialWindow || !(w.normalWindow || w.dialog)) {
    return false;
  }
  return true;
}

function isOnDesktop(w, desktop) {
  if (w.onAllDesktops) {
    return true;
  }
  const ds = w.desktops;
  for (let i = 0; i < ds.length; i++) {
    if (ds[i] === desktop) {
      return true;
    }
  }
  return false;
}

function topWindowOn(screen, desktop) {
  const stack = workspace.stackingOrder;
  for (let i = stack.length - 1; i >= 0; i--) {
    const w = stack[i];
    if (isFocusable(w) && w.output === screen && isOnDesktop(w, desktop)) {
      return w;
    }
  }
  return null;
}

function pointInRect(p, r) {
  return (
    p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height
  );
}

function setDesktopForScreen(desktop, screen) {
  if (workspace.currentDesktopForScreen(screen) === desktop) {
    return true;
  }
  try {
    workspace.setCurrentDesktopForScreen(desktop, screen);
    return true;
  } catch (e) {
    log("setCurrentDesktopForScreen failed: " + e);
    return false;
  }
}

function focusScreen(screen, desktop, preferred) {
  const target =
    preferred && !preferred.deleted ? preferred : topWindowOn(screen, desktop);
  if (target) {
    if (workspace.activeWindow !== target) {
      workspace.activeWindow = target;
    }
  } else if (workspace.activeScreen !== screen) {
    const idx = screenOrderIndex(screen);
    if (idx >= 0) {
      invokeKwinShortcut("Switch to Screen " + idx);
    }
  }
  if (!moveCursor) {
    return;
  }
  const cursor = workspace.cursorPos;
  if (target) {
    if (!pointInRect(cursor, target.frameGeometry)) {
      invokeKwinShortcut("MoveMouseToFocus");
    }
  } else if (!pointInRect(cursor, screen.geometry)) {
    invokeKwinShortcut("MoveMouseToCenter");
  }
}

function switchToWorkspace(screen, desktopNumber) {
  const desktop = desktopAt(desktopNumber);
  if (!screen || !desktop) {
    return;
  }
  if (!setDesktopForScreen(desktop, screen)) {
    return;
  }
  focusScreen(screen, desktop, null);
  log(screen.name + " -> desktop " + desktopNumber);
}

function moveActiveWindow(screen, desktopNumber) {
  const desktop = desktopAt(desktopNumber);
  if (!screen || !desktop) {
    return;
  }
  const w = workspace.activeWindow;
  if (!isFocusable(w)) {
    switchToWorkspace(screen, desktopNumber);
    return;
  }
  try {
    if (w.output !== screen) {
      workspace.sendClientToScreen(w, screen);
    }
    w.desktops = [desktop];
  } catch (e) {
    log("moving window failed: " + e);
    return;
  }
  setDesktopForScreen(desktop, screen);
  focusScreen(screen, desktop, w);
  log(
    "moved '" +
      (w.caption || "window") +
      "' to " +
      screen.name +
      " desktop " +
      desktopNumber,
  );
}

function registerScreenHandlers() {
  workspace.screensChanged.connect(function () {
    const r = resolveScreens();
    log("screens changed. s1=" + screenName(r.s1) + " s2=" + screenName(r.s2));
  });
}

function setup() {
  ensureDesktopCount();
  for (let i = 0; i < 10; i++) {
    const onMonitor1 = i < WORKSPACES_PER_SCREEN;
    const dn = (i % WORKSPACES_PER_SCREEN) + 1;
    const suffix = onMonitor1 ? " (Monitor 1)" : " (Monitor 2)";
    registerShortcut(
      SCRIPT_ID + "_ws" + (i + 1),
      "Snry Workspaces: Switch to Workspace " + dn + suffix,
      "Meta+" + NUMBER_KEYS[i],
      function () {
        const r = resolveScreens();
        switchToWorkspace(onMonitor1 ? r.s1 : r.s2, dn);
      },
    );
    registerShortcut(
      SCRIPT_ID + "_movews" + (i + 1),
      "Snry Workspaces: Move Window to Workspace " + dn + suffix,
      "Meta+" + SHIFTED_KEYS[i],
      function () {
        const r = resolveScreens();
        moveActiveWindow(onMonitor1 ? r.s1 : r.s2, dn);
      },
    );
  }
  registerScreenHandlers();
  const r = resolveScreens();
  log(
    "loaded. s1=" +
      screenName(r.s1) +
      " s2=" +
      screenName(r.s2) +
      " moveCursor=" +
      moveCursor,
  );
}

setup();
