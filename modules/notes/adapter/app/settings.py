import os
from functools import lru_cache

from pydantic import BaseModel


class Settings(BaseModel):
    adapter_secret: str
    module_yml: str
    notes_app_internal_status_url: str = "http://notes_app:3000/internal/ayaya/status"
    internal_status_secret: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings(
        adapter_secret=os.environ.get("NOTES_ADAPTER_SECRET", ""),
        module_yml=os.environ.get("NOTES_MODULE_YML", "../module.yml"),
        notes_app_internal_status_url=os.environ.get(
            "NOTES_APP_INTERNAL_STATUS_URL",
            "http://notes_app:3000/internal/ayaya/status",
        ),
        internal_status_secret=os.environ.get("NOTES_INTERNAL_STATUS_SECRET", ""),
    )
