// ---------------------------------------------------------------------------
// Config persistence — load and save application state as JSON
// ---------------------------------------------------------------------------

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  type PersistedState,
  createDefaultState,
  APP_VERSION,
} from "./models.ts";

const CONFIG_DIR = join(
  homedir(),
  "Library",
  "Application Support",
  "in.sreerams.chowser-electrobun"
);
const CONFIG_FILE = join(CONFIG_DIR, "state.json");

let _state: PersistedState | null = null;
let _saveTimer: ReturnType<typeof setTimeout> | null = null;

/** Load state from disk (or return defaults on first run). */
export function loadState(): PersistedState {
  if (_state) return _state;

  try {
    if (existsSync(CONFIG_FILE)) {
      const raw = readFileSync(CONFIG_FILE, "utf-8");
      const parsed = JSON.parse(raw) as Partial<PersistedState>;
      _state = { ...createDefaultState(), ...parsed };
      return _state;
    }
  } catch (err) {
    console.error("[config] Failed to load state:", err);
  }

  _state = createDefaultState();
  return _state;
}

/** Get the current in-memory state (throws if not yet loaded). */
export function getState(): PersistedState {
  if (!_state) return loadState();
  return _state;
}

/** Replace the entire in-memory state and schedule a debounced save. */
export function setState(state: PersistedState): void {
  _state = { ...state, version: APP_VERSION };
  scheduleSave();
}

/** Patch a subset of the state and schedule a debounced save. */
export function patchState(patch: Partial<PersistedState>): void {
  _state = { ...(getState()), ...patch, version: APP_VERSION };
  scheduleSave();
}

/** Flush any pending write immediately. */
export function flushState(): void {
  if (_state) persistNow(_state);
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function scheduleSave(): void {
  if (_saveTimer !== null) clearTimeout(_saveTimer);
  _saveTimer = setTimeout(() => {
    _saveTimer = null;
    if (_state) persistNow(_state);
  }, 300);
}

function persistNow(state: PersistedState): void {
  try {
    if (!existsSync(CONFIG_DIR)) {
      mkdirSync(CONFIG_DIR, { recursive: true });
    }
    writeFileSync(CONFIG_FILE, JSON.stringify(state, null, 2), "utf-8");
  } catch (err) {
    console.error("[config] Failed to save state:", err);
  }
}
