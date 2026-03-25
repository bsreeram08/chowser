// ---------------------------------------------------------------------------
// Platform detection utilities
// Provides OS detection and platform-specific path resolution
// ---------------------------------------------------------------------------

import { homedir } from "node:os";
import { join } from "node:path";

const PLATFORM = process.platform;

// ---------------------------------------------------------------------------
// OS Detection
// ---------------------------------------------------------------------------

/** Returns true if running on Windows */
export function isWindows(): boolean {
  return PLATFORM === "win32";
}

/** Returns true if running on Linux */
export function isLinux(): boolean {
  return PLATFORM === "linux";
}

/** Returns true if running on macOS */
export function isMacOS(): boolean {
  return PLATFORM === "darwin";
}

// ---------------------------------------------------------------------------
// Platform-specific path resolution
// ---------------------------------------------------------------------------

/**
 * Return the platform-appropriate user-data directory for app configuration.
 *
 * • macOS   → ~/Library/Application Support/in.sreerams.chowser-electrobun
 * • Windows → %APPDATA%\in.sreerams.chowser-electrobun
 * • Linux   → $XDG_CONFIG_HOME/in.sreerams.chowser-electrobun
 *             (falls back to ~/.config/in.sreerams.chowser-electrobun)
 */
export function getPlatformConfigPath(): string {
  const appFolder = "in.sreerams.chowser-electrobun";
  switch (PLATFORM) {
    case "win32":
      return join(process.env["APPDATA"] ?? homedir(), appFolder);
    case "linux":
      return join(
        process.env["XDG_CONFIG_HOME"] ?? join(homedir(), ".config"),
        appFolder
      );
    default: // darwin
      return join(homedir(), "Library", "Application Support", appFolder);
  }
}

/**
 * Return the platform-appropriate path for startup/launch-at-login registration.
 *
 * • macOS   → ~/Library/LaunchAgents
 * • Windows → registry path (HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run)
 * • Linux   → ~/.config/autostart
 */
export function getPlatformStartupPath(): string {
  const appFolder = "in.sreerams.chowser-electrobun";
  switch (PLATFORM) {
    case "win32":
      // On Windows, launch-at-login uses the registry, not a file path.
      // This returns the registry key path for reference.
      return "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run";
    case "linux":
      return join(homedir(), ".config", "autostart");
    default: // darwin
      return join(homedir(), "Library", "LaunchAgents");
  }
}

/**
 * Return the Windows registry path for default browser discovery.
 * Only valid on Windows; returns null on other platforms.
 *
 * Used to query HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice
 * to determine the current default HTTP handler.
 */
export function getDefaultBrowserRegistryPath(): string | null {
  if (!isWindows()) return null;
  return "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\Shell\\Associations\\UrlAssociations\\http\\UserChoice";
}
