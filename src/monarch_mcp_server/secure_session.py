"""
Secure session management for Monarch Money MCP Server.

Supports MONARCH_TOKEN env var for cloud deployment (Render, etc.)
and falls back to system keyring for local development.
"""

import logging
import os
from typing import Optional
from monarchmoney import MonarchMoney

try:
    import keyring

    _KEYRING_AVAILABLE = True
except Exception:
    keyring = None  # type: ignore[assignment]
    _KEYRING_AVAILABLE = False

logger = logging.getLogger(__name__)

KEYRING_SERVICE = "com.mcp.monarch-mcp-server"
KEYRING_USERNAME = "monarch-token"


class SecureMonarchSession:
    """Manages Monarch Money sessions securely.

    Priority order for token resolution:
      1. MONARCH_TOKEN environment variable (cloud / Render)
      2. System keyring (local desktop)
    """

    def save_token(self, token: str) -> None:
        """Save the authentication token to the system keyring."""
        if not _KEYRING_AVAILABLE:
            logger.warning("Keyring not available -- token not persisted")
            return

        try:
            keyring.set_password(KEYRING_SERVICE, KEYRING_USERNAME, token)
            logger.info("Token saved securely to keyring")
            self._cleanup_old_session_files()
        except Exception as e:
            logger.warning(f"Could not save token to keyring: {e}")

    def load_token(self) -> Optional[str]:
        """Load the authentication token (env var first, then keyring)."""
        env_token = os.getenv("MONARCH_TOKEN")
        if env_token:
            logger.info("Token loaded from MONARCH_TOKEN env var")
            return env_token

        if not _KEYRING_AVAILABLE:
            logger.info("Keyring not available and MONARCH_TOKEN not set")
            return None

        try:
            token = keyring.get_password(KEYRING_SERVICE, KEYRING_USERNAME)
            if token:
                logger.info("Token loaded from keyring")
                return token
            logger.info("No token found in keyring")
            return None
        except Exception as e:
            logger.warning(f"Keyring access failed: {e}")
            return None

    def delete_token(self) -> None:
        """Delete the authentication token from the system keyring."""
        if not _KEYRING_AVAILABLE:
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
                        logger.info(f"Cleaned up empty session directory: {path}")
            except Exception as e:
                logger.warning(f"Could not clean up {path}: {e}")


# Global session manager instance
secure_session = SecureMonarchSession()
