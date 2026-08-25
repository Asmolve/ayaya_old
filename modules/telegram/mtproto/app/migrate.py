from .settings import Settings
from .storage import SessionStorage


def main() -> None:
    settings = Settings.from_environment()
    SessionStorage(settings.database_url, settings.session_encryption_key).migrate()


if __name__ == "__main__":
    main()

