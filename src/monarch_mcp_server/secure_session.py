"""
Secure session management for Monarch Money MCP Server.

On Windows: uses keyring (Windows Credential Manager) for token storage.
On Linux/Cloud (Render): uses MONARCH_TOKEN environment variable only.
"""

import logging
import os
from typing import Optional
from monarchmoney import MonarchMoney

logger = logging.getLogger(__name__)

# Keyring service identifiers
KEYRING_SERVICE = "com.mcp.monarch-mcp-server"
KEYRING_USERNAME = "monarch-token"

# Try to import keyring — it may not be available on Linux/cloud environments
try:
    import keyring
    _HAS_KEYRING = True
except Exception:
    _HAS_KEYRING = False
    logger.info("keyring not available — using MONARCH_TOKEN env var only (cloud mode)")


class SecureMonarchSession:
    """Manages Monarch Money sessions securely."""

    def save_token(self, token: str) -> None:
        """Save the authentication token to the system keyring."""
        if not _HAS_KEYRING:
            logger.warning("keyring not available — cannot save token locally")
            return

        try:
            keyring.set_password(KEYRING_SERVICE, KEYRING_USERNAME, token)
            logger.info("Token saved securely to keyring")
            self._cleanup_old_session_files()
        except Exception as e:
            logger.error(f"Failed to save token to keyring: {e}")
            raise

    def load_token(self) -> Optional[str]:
        """Load the authentication token.

        Priority order:
        1. MONARCH_TOKEN environment variable (cloud/Render.com deployment)
        2. Windows Credential Manager via keyring (local Windows deployment)
        """
        # 1. Check environment variable first (cloud deployment)
        env_token = os.getenv("MONARCH_TOKEN")
        if env_token and env_token.strip():
            logger.info("Token loaded from MONARCH_TOKEN environment variable")
            return env_token.strip()

        # 2. Fall back to keyring (local Windows deployment)
        if _HAS_KEYRING:
            try:
                token = keyring.get_password(KEYRING_SERVICE, KEYRING_USERNAME)
                if token:
                    logger.info("Token loaded from keyring")
                    return token
            except Exception as e:
                logger.error(f"Failed to load token from keyring: {e}")

        logger.info("No token found in MONARCH_TOKEN env var or keyring")
        return None

    def delete_token(self) -> None:
        """Delete the authentication token from the system keyring."""
        if not _HAS_KEYRING:
            return

        try:
            keyring.delete_password(KEYRING_SERVICE, KEYRING_USERNAME)
            logger.info("Token deleted from keyring")
            self._cleanup_old_session_files()
        except Exception:
            logger.info("No token found in keyring to delete")

    def get_authenticated_client(self) -> Optional[MonarchMoney]:
        """Get an authenticated MonarchMoney client."""
        token = self.load_token()
        if not token:
            return None

        try:
            client = MonarchMoney(token=token)
            logger.info("MonarchMoney client created with stored token")
            return client
        except Exception as e:
            logger.error(f"Failed to create MonarchMoney client: {e}")
            return None

    def save_authenticated_session(self, mm: MonarchMoney) -> None:
        """Save the session from an authenticated MonarchMoney instance."""
        if mm.token:
            self.save_token(mm.token)
        else:
            logger.warning("MonarchMoney instance has no token to save")

    def _cleanup_old_session_files(self) -> None:
        """Clean up old insecure session files."""
        cleanup_paths = [
            ".mm/mm_session.pickle",
            "monarch_session.json",
            ".mm",
        ]

        for path in cleanup_paths:
            try:
                if os.path.exists(path):
                    if os.path.isfile(path):
                        os.remove(path)
                        logger.info(f"Cleaned up old session file: {path}")
                    elif os.path.isdir(path) and not os.listdir(path):
                        os.rmdir(path)
            except Exception as e:
                logger.warning(f"Could not clean up {path}: {e}")


# Global session manager instance
secure_session = SecureMonarchSession()
