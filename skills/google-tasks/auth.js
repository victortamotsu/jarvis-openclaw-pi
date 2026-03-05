/**
 * Google OAuth Authentication Module
 * 
 * Handles OAuth 2.0 token refresh and management for Google Tasks API.
 * Supports refresh token-based flow.
 */

import dotenv from 'dotenv';
import { google } from 'googleapis.js';

dotenv.config();

// ─────────────────────────────────────────────────────────────────────
// OAuth Credentials from Environment
// ─────────────────────────────────────────────────────────────────────

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const REFRESH_TOKEN = process.env.GOOGLE_REFRESH_TOKEN;

if (!CLIENT_ID || !CLIENT_SECRET || !REFRESH_TOKEN) {
  throw new Error(
    'Missing OAuth credentials. Set GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN in .env'
  );
}

// ─────────────────────────────────────────────────────────────────────
// OAuth2 Client Setup
// ─────────────────────────────────────────────────────────────────────

const oauth2Client = new google.auth.OAuth2(
  CLIENT_ID,
  CLIENT_SECRET
);

// Set refresh token for automatic token refresh
oauth2Client.setCredentials({
  refresh_token: REFRESH_TOKEN
});

// ─────────────────────────────────────────────────────────────────────
// Authentication & Token Management
// ─────────────────────────────────────────────────────────────────────

/**
 * Get valid OAuth authentication object
 * Automatically refreshes access token if expired
 * 
 * @returns {Promise<Object>} OAuth2 client with valid credentials
 */
export async function getAuth() {
  try {
    // Refresh token before each API call to ensure it's not expired
    // Google Tasks API requires valid access token
    const { credentials } = await oauth2Client.refreshAccessToken();
    oauth2Client.setCredentials(credentials);

    console.error('[Auth] Token refreshed successfully');
    return oauth2Client;
  } catch (err) {
    throw new Error(`Failed to refresh OAuth token: ${err.message}`);
  }
}

/**
 * Get current access token
 * (Useful for direct API calls or debugging)
 * 
 * @returns {Promise<String>} Current access token
 */
export async function getAccessToken() {
  const auth = await getAuth();
  const creds = auth.credentials;
  
  if (!creds.access_token) {
    throw new Error('No access token available after refresh');
  }
  
  return creds.access_token;
}

// ─────────────────────────────────────────────────────────────────────
// Export for use in index.js
// ─────────────────────────────────────────────────────────────────────

export { oauth2Client };
