import os
import hmac
from functools import lru_cache

from pydantic import BaseModel


class Settings(BaseModel):
    adapter_secret: str
    module_yml: str
    telegram_app_internal_status_url: str = "http://telegram_app:3000/internal/ayaya/status"
    internal_status_secret: str = ""

    def secrets_are_valid(self) -> bool:
        adapter_secret = self.adapter_secret.strip()
        internal_status_secret = self.internal_status_secret.strip()
        return bool(adapter_secret) and bool(internal_status_secret) and not hmac.compare_digest(
            adapter_secret, internal_status_secret
        )


@lru_cache
def get_settings() -> Settings:
    return Settings(
        adapter_secret=os.environ.get("TELEGRAM_ADAPTER_SECRET", ""),
        module_yml=os.environ.get("TELEGRAM_MODULE_YML", "/module/module.yml"),
        telegram_app_internal_status_url=os.environ.get(
            "TELEGRAM_APP_INTERNAL_STATUS_URL",
            "http://telegram_app:3000/internal/ayaya/status",
        ),
        internal_status_secret=os.environ.get("TELEGRAM_INTERNAL_STATUS_SECRET", ""),
    )
