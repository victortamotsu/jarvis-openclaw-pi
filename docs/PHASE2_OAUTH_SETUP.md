# PHASE 2 — Google OAuth 2.0 Setup Guide (T014)

## Overview

Task T014 requires setting up Google OAuth 2.0 credentials for:
- **Gmail API** (gmail.readonly, gmail.compose scopes)
- **Google Tasks API** (tasks scope)
- **Google Drive API** (drive.file scope for file access)
- **YouTube Data API** (future use)

---

## Step 1: Create GCP Project

1. Go to https://console.cloud.google.com/
2. Click **Create Project**
3. Name: `Jarvis-AI`
4. Click **Create** (wait 1-2 minutes)

---

## Step 2: Enable Required APIs

With the project selected, enable these APIs:

### 2.1 Gmail API
- Go to https://console.cloud.google.com/apis/library/gmail.googleapis.com
- Click **Enable**
- Verify status: https://console.cloud.google.com/apis/api/gmail.googleapis.com/overview

### 2.2 Google Tasks API
- Go to https://console.cloud.google.com/apis/library/tasks.googleapis.com
- Click **Enable**

### 2.3 Google Drive API
- Go to https://console.cloud.google.com/apis/library/drive.googleapis.com
- Click **Enable**

### 2.4 YouTube Data API (Optional, for future use)
- Go to https://console.cloud.google.com/apis/library/youtube.googleapis.com
- Click **Enable**

**Wait 1-2 minutes for APIs to initialize.**

---

## Step 3: Create OAuth 2.0 Credentials

1. Go to https://console.cloud.google.com/apis/credentials
2. Click **+ Create Credentials** → **OAuth client ID**
3. If prompted: Click **Configure Consent Screen** first

### 3.1 Configure OAuth Consent Screen
- **User type**: Select "External"
- Click **Create**
- **App name**: "Jarvis Personal Assistant"
- **User support email**: your_email@gmail.com
- **Developer contact**: your_email@gmail.com
- Click **Save and Continue**

### 3.2 Add Scopes
- Click **Add or Remove Scopes**
- Add these scopes:
  - `https://www.googleapis.com/auth/gmail.readonly`
  - `https://www.googleapis.com/auth/gmail.compose` (optional, see notes)
  - `https://www.googleapis.com/auth/tasks`
  - `https://www.googleapis.com/auth/drive.file`
- Click **Update** → **Save and Continue**

### 3.3 Add Test User (if using unverified app)
- If your app shows "unverified", you need to add yourself as a test user:
  - Go to https://console.cloud.google.com/apis/credentials/consent
  - Scroll to "Test users"
  - Click **Add Users**
  - Enter: your_email@gmail.com
  - Click **Add**

---

## Step 4: Create Desktop Application Credentials

1. Return to https://console.cloud.google.com/apis/credentials
2. Click **+ Create Credentials** → **OAuth client ID**
3. **Application type**: Select "Desktop application"
4. **Name**: "Jarvis-CLI"
5. Click **Create**

You'll see a popup with:
- **Client ID**: Copy this
- **Client Secret**: Copy this

Download the JSON file by clicking the download icon.

---

## Step 5: Get Refresh Token

### Using Python (Recommended for Raspberry Pi)

**Option A: On your local machine (faster)**

1. Clone the repo locally:
   ```bash
   git clone https://github.com/victortamotsu/jarvis-openclaw-pi.git
   cd jarvis-openclaw-pi
   ```

2. Install Python dependencies:
   ```bash
   pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client
   ```

3. Create `scripts/get_oauth_token.py` (if it doesn't exist):
   ```python
   #!/usr/bin/env python3
   import sys
   from google_auth_oauthlib.flow import InstalledAppFlow
   
   def main():
       SCOPES = [
           'https://www.googleapis.com/auth/gmail.readonly',
           'https://www.googleapis.com/auth/tasks',
           'https://www.googleapis.com/auth/drive.file'
       ]
       
       CLIENT_ID = sys.argv[1]
       CLIENT_SECRET = sys.argv[2]
       
       flow = InstalledAppFlow.from_client_secrets_dict(
           {
               "installed": {
                   "client_id": CLIENT_ID,
                   "client_secret": CLIENT_SECRET,
                   "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                   "token_uri": "https://oauth2.googleapis.com/token",
               }
           },
           SCOPES
       )
       
       creds = flow.run_local_server(port=0, open_browser=True)
       print(f"\nRefresh Token: {creds.refresh_token}")
       print(f"Token Expiry: {creds.expiry}")
   
   if __name__ == '__main__':
       main()
   ```

4. Run the script:
   ```bash
   python3 scripts/get_oauth_token.py YOUR_CLIENT_ID YOUR_CLIENT_SECRET
   ```

5. A browser window opens. **Grant permissions** to all scopes.

6. Copy the **Refresh Token** displayed in the terminal.

**Option B: On Raspberry Pi (CLI only)**

If you can't run a browser on the Pi:

1. Use "Device flow" or use a browser-based tool:
   - https://oauth2.tools.google.com/oauth2bypostman
   - Or generate token on your laptop, then transfer

---

## Step 6: Store Credentials in .env

1. Edit `.env` in the repo root:
   ```bash
   nano .env
   ```

2. Fill in OAuth credentials (found earlier):
   ```env
   GOOGLE_CLIENT_ID=YOUR_CLIENT_ID.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=YOUR_CLIENT_SECRET
   GOOGLE_REFRESH_TOKEN=YOUR_REFRESH_TOKEN
   ```

3. **⚠️ Important**: This file is git-crypt encrypted. Don't commit with client secret in plaintext.

4. Save: `Ctrl+X` → `Y` → `Enter`

---

## Step 7: Verify Integration (Optional but Recommended)

### 7.1 Test Token Refresh

```bash
curl -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$GOOGLE_CLIENT_ID" \
  -d "client_secret=$GOOGLE_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_REFRESH_TOKEN" \
  -d "grant_type=refresh_token"
```

If successful, you'll get:
```json
{
  "access_token": "ya29.a0ABC...",
  "expires_in": 3599,
  "scope": "https://www.googleapis.com/auth/tasks https://www.googleapis.com/auth/gmail.readonly ...",
  "token_type": "Bearer"
}
```

### 7.2 Test Gmail API

```bash
# Extract access_token from response above
ACCESS_TOKEN="ya29.a0ABC..."

curl "https://www.googleapis.com/gmail/v1/users/me/messages?maxResults=1" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

You should get a list of 1 recent email.

### 7.3 Test Google Tasks API

```bash
curl "https://tasks.googleapis.com/tasks/v1/users/@me/lists" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

You should get your Google Tasks lists.

---

## Troubleshooting

### "Invalid OAuth credentials"

**Cause**: Client ID/Secret incorrect or expired  
**Fix**:
1. Go back to https://console.cloud.google.com/apis/credentials
2. Delete old credential
3. Re-create new OAuth 2.0 credentials (Desktop application)
4. Copy new Client ID and Secret to `.env`

### "Redirect URI mismatch"

**Cause**: OAuth consent screen URIs don't match local server  
**Fix**: Use `http://localhost:PORT` in consent screen (port should be 8080 or similar)

### "Gmail API not enabled"

**Cause**: API not activated in project  
**Fix**: Go to https://console.cloud.google.com/apis/library/gmail.googleapis.com and click **Enable**

### "Token expired"

**Cause**: Refresh token older than 6 months of inactivity  
**Fix**: Re-run `scripts/get_oauth_token.py` to get new refresh token

---

## Token Expiry & Auto-Refresh

Refresh tokens **don't expire** unless:
- 6+ months of inactivity without use
- User revokes access at https://myaccount.google.com/permissions

The code in `skills/google-tasks/index.js` and `pipeline/firefly_importer.py` automatically refreshes tokens before API calls using:

```bash
curl -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$GOOGLE_CLIENT_ID" \
  -d "client_secret=$GOOGLE_CLIENT_SECRET" \
  -d "refresh_token=$GOOGLE_REFRESH_TOKEN" \
  -d "grant_type=refresh_token"
```

This happens automatically — no manual intervention needed.

---

## Security Notes

- ⚠️ **Never commit `.env` with credentials unencrypted**
- Use `git-crypt` to encrypt `.env` in repository
- Store `GOOGLE_CLIENT_SECRET` only in `.env` (never in code)
- Refresh tokens grant access; protect them like passwords
- Use separate OAuth apps for production vs. staging

---

## Next Steps (After T014 Complete)

Once OAuth credentials are verified:

1. Run validation: `bash scripts/validate-oauth.sh` (optional helper)
2. Move to Phase 3: Start User Story 1 implementation (T017+)

---

**Last Updated**: 2026-03-04  
**Reference**: docs/runbook.md → Google OAuth Setup
