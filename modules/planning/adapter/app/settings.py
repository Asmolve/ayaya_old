import os
from functools import lru_cache

from pydantic import BaseModel


class Settings(BaseModel):
    adapter_secret: str
    module_yml: str
    planning_app_internal_status_url: str = "http://planning_app:3000/internal/ayaya/status"
    internal_status_secret: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings(
        adapter_secret=os.environ.get("PLANNING_ADAPTER_SECRET", ""),
        module_yml=os.environ.get("PLANNING_MODULE_YML", "../module.yml"),
        planning_app_internal_status_url=os.environ.get(
            "PLANNING_APP_INTERNAL_STATUS_URL",
            "http://planning_app:3000/internal/ayaya/status",
        ),
        internal_status_secret=os.environ.get("PLANNING_INTERNAL_STATUS_SECRET", ""),
    )
